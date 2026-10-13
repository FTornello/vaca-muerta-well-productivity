-- Cuatro fuentes más de la Secretaría de Energía:
--   crudo que procesa cada refinería según de dónde viene,
--   pronósticos de producción de gas que declaran las empresas,
--   puntos de venteo que las empresas declaran tener, y
--   pozos terminados por provincia y resultado.
--   psql -d vaca_muerta -f sql/16_refinacion_gas_y_declarados.sql

DROP TABLE IF EXISTS raw.productos_procesados;
CREATE TABLE raw.productos_procesados (
    anio text, mes text, empresa text, refineria text, concepto text,
    cantidadm3 text, cantidadtoneladas text, observaciones text, rectificado text, indice_tiempo text
);
\copy raw.productos_procesados FROM 'data/raw/productos_procesados.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

DROP TABLE IF EXISTS raw.pronostico_gas;
CREATE TABLE raw.pronostico_gas (
    anio text, mes text, idempresa text, empresa text, idareapermisoconcesion text, idprovincia text,
    provincia text, anio_pronostico text, tipoinforme text, idtipo text, tipo text,
    idconcepto text, concepto text, cantidad text, observaciones text, fecha_data text
);
\copy raw.pronostico_gas FROM 'data/raw/pronostico_gas.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

DROP TABLE IF EXISTS raw.venteo_punto_declarado;
CREATE TABLE raw.venteo_punto_declarado (
    pv text, tipo text, empresa_informante text, procedencia text, procdet text, geojson text,
    alta_planos_base text, modificacion_planos_base text
);
\copy raw.venteo_punto_declarado FROM 'data/raw/venteo_puntos_declarados.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

DROP TABLE IF EXISTS raw.pozos_terminados;
CREATE TABLE raw.pozos_terminados (
    anio text, mes text, indice_tiempo text, concepto_pozo text, provincia text, cantidad_pozos text
);
\copy raw.pozos_terminados FROM 'data/raw/pozos_terminados_por_provincia.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')


-- crudo_procesado: m3 de petróleo que cada refinería procesó cada mes, según
-- el origen del crudo. La fuente mezcla en la misma columna crudos, cortes
-- intermedios y aditivos: me quedo solo con los crudos.
--   origen: 'Neuquén', 'Resto de la cuenca Neuquina' (Río Negro, La Pampa y
--           Mendoza), 'Golfo San Jorge', 'Otras cuencas' o 'Importado'.
--           La separación entre Neuquén y el resto de la cuenca es la que
--           declara cada refinería y no es pareja (hay refinerías que cargan
--           todo como Río Negro): para comparar conviene sumar las dos.
DROP TABLE IF EXISTS vm.crudo_procesado;
CREATE TABLE vm.crudo_procesado (
    mes        date    NOT NULL,
    empresa    text    NOT NULL,
    refineria  text    NOT NULL,
    origen     text    NOT NULL,
    crudo      text    NOT NULL,   -- el nombre del crudo como viene en la fuente
    m3         numeric NOT NULL CHECK (m3 >= 0),
    PRIMARY KEY (mes, empresa, refineria, crudo)
);
INSERT INTO vm.crudo_procesado
SELECT make_date(anio::integer, mes::integer, 1), empresa, refineria,
       CASE WHEN concepto = 'Crudo importado'                THEN 'Importado'
            WHEN concepto LIKE 'Cuenca Neuquina - Neuquen%'  THEN 'Neuquén'
            WHEN concepto LIKE 'Cuenca Neuquina%'            THEN 'Resto de la cuenca Neuquina'
            WHEN concepto LIKE 'Cuenca Golfo San Jorge%'     THEN 'Golfo San Jorge'
            ELSE 'Otras cuencas' END,
       concepto,
       sum(cantidadm3::numeric)
FROM raw.productos_procesados
WHERE (concepto LIKE 'Cuenca %' OR concepto = 'Crudo importado')
GROUP BY 1, 2, 3, 4, 5
HAVING sum(cantidadm3::numeric) > 0;


-- pronostico_gas: como vm.pronostico_petroleo, para el gas, en miles de m3.
-- La fuente de gas no trae el nombre del área, solo el código; el nombre sale
-- de la planilla de petróleo, que usa los mismos códigos.
--   tipo: 'Totales Anuales' para los años siguientes; para el año en curso la
--         empresa detalla 'Disponible al Mercado', 'Consumo Propio',
--         'Gas Aventado' (el que piensa ventear) y 'Exportado'.
DROP TABLE IF EXISTS vm.pronostico_gas;
CREATE TABLE vm.pronostico_gas (
    anio_informe    integer NOT NULL,
    area_codigo     text    NOT NULL,
    area_nombre     text,
    area_id         text    REFERENCES vm.area,
    anio_pronostico integer NOT NULL,
    tipo            text    NOT NULL,
    gas_miles_m3    numeric NOT NULL CHECK (gas_miles_m3 >= 0),   -- la fuente trae unas pocas filas negativas: se descartan
    PRIMARY KEY (anio_informe, area_codigo, anio_pronostico, tipo)
);
WITH nombres AS (
    SELECT idareapermisoconcesion AS codigo,
           max(regexp_replace(trim(areapermisoconcesion), '\s+', ' ', 'g')) AS nombre
    FROM raw.pronostico_petroleo
    WHERE trim(coalesce(areapermisoconcesion, '')) <> ''
    GROUP BY 1
)
INSERT INTO vm.pronostico_gas
SELECT g.anio::integer, g.idareapermisoconcesion, max(n.nombre), max(a.area_id),
       g.anio_pronostico::integer, g.tipo,
       sum(coalesce(nullif(g.cantidad, '')::numeric, 0))
FROM raw.pronostico_gas g
LEFT JOIN nombres n ON n.codigo = g.idareapermisoconcesion
LEFT JOIN vm.area a ON a.nombre = n.nombre
WHERE g.provincia LIKE 'Neuqu%'
  AND g.anio_pronostico::integer BETWEEN g.anio::integer AND g.anio::integer + 4
  AND coalesce(nullif(g.cantidad, '')::numeric, 0) >= 0
GROUP BY 1, 2, 5, 6;
CREATE INDEX ON vm.pronostico_gas (area_id);


-- venteo_punto_declarado: las chimeneas y fosas de quema que las empresas
-- informaron a la Secretaría, con su ubicación.
DROP TABLE IF EXISTS vm.venteo_punto_declarado;
CREATE TABLE vm.venteo_punto_declarado (
    punto       text PRIMARY KEY,
    tipo        text NOT NULL,      -- CHIMENEA DE QUEMA o FOSA DE QUEMA
    procedencia text,               -- YACIMIENTO o PLANTA COMPRESORA
    latitud     numeric NOT NULL,
    longitud    numeric NOT NULL
);
INSERT INTO vm.venteo_punto_declarado
SELECT DISTINCT ON (pv) pv, tipo, procedencia,
       ((geojson::jsonb -> 'coordinates') ->> 1)::numeric,
       ((geojson::jsonb -> 'coordinates') ->> 0)::numeric
FROM raw.venteo_punto_declarado
WHERE geojson IS NOT NULL AND geojson <> ''
ORDER BY pv, alta_planos_base DESC;

-- A cada detección satelital de Neuquén le agrego la distancia al punto
-- declarado más cercano, para ver cuántas caen donde las empresas dijeron que
-- queman gas y cuántas no.
ALTER TABLE vm.venteo_detectado ADD COLUMN IF NOT EXISTS km_al_punto_declarado numeric;
UPDATE vm.venteo_detectado v
SET km_al_punto_declarado = d.km
FROM (
    SELECT v2.venteo_id,
           round(min(sqrt(power((v2.latitud - p.latitud) * 111.0, 2)
                        + power((v2.longitud - p.longitud) * 87.0, 2)))::numeric, 2) AS km
    FROM vm.venteo_detectado v2
    JOIN vm.venteo_punto_declarado p
      ON p.latitud  BETWEEN v2.latitud  - 0.1  AND v2.latitud  + 0.1
     AND p.longitud BETWEEN v2.longitud - 0.12 AND v2.longitud + 0.12
    WHERE v2.provincia = 'NEUQUEN'
    GROUP BY 1
) d
WHERE d.venteo_id = v.venteo_id;


-- pozos_terminados: pozos terminados por mes, provincia y resultado.
DROP TABLE IF EXISTS vm.pozos_terminados;
CREATE TABLE vm.pozos_terminados (
    mes       date    NOT NULL,
    provincia text    NOT NULL,
    resultado text    NOT NULL,   -- Productivos de Petróleo, Productivos de Gas, Improductivos o Servicio
    pozos     numeric NOT NULL CHECK (pozos >= 0),
    PRIMARY KEY (mes, provincia, resultado)
);
INSERT INTO vm.pozos_terminados
SELECT make_date(anio::integer, mes::integer, 1), provincia, concepto_pozo, sum(cantidad_pozos::numeric)
FROM raw.pozos_terminados
GROUP BY 1, 2, 3;
