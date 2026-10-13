-- Tres fuentes más de la Secretaría de Energía:
--   pronósticos de producción que declaran las empresas cada año,
--   anomalías térmicas (venteo y quema de gas) detectadas por satélite, y
--   metros perforados por provincia.
--   psql -d vaca_muerta -f sql/15_pronosticos_venteo_perforacion.sql

DROP TABLE IF EXISTS raw.pronostico_petroleo;
CREATE TABLE raw.pronostico_petroleo (
    anio text, mes text, idempresa text, empresa text, idareapermisoconcesion text,
    areapermisoconcesion text, idprovincia text, provincia text, anio_pronostico text,
    tipoinforme text, idconcepto text, concepto text, cantidad_primaria text,
    cantidad_secundaria text, observaciones text, fecha_data text
);
\copy raw.pronostico_petroleo FROM 'data/raw/pronostico_petroleo.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

DROP TABLE IF EXISTS raw.venteo_detectado;
CREATE TABLE raw.venteo_detectado (
    fecha text, satelite_new text, sensor text, mes text, anio text, hora_utc text,
    latitud text, longitud text, provincia text, geojson text
);
\copy raw.venteo_detectado FROM 'data/raw/venteos_detectados.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

DROP TABLE IF EXISTS raw.metros_perforados;
CREATE TABLE raw.metros_perforados (
    anio text, mes text, indice_tiempo text, concepto_metros text, provincia text, metros_perforados text
);
\copy raw.metros_perforados FROM 'data/raw/metros_perforados_por_provincia.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')


-- pronostico_petroleo: lo que cada empresa declaró, en el informe de cada año,
-- que iba a producir un área ese año y los cuatro siguientes. Solo Neuquén.
--   anio_informe:    año en que se presentó el pronóstico (se presenta en marzo).
--   anio_pronostico: año para el que se pronostica. Si es igual a anio_informe,
--                    es la suma de los doce meses que la empresa detalla.
-- La fuente trae filas repetidas en cero y separa recuperación primaria y
-- secundaria: acá se suman. El área se enlaza por nombre; un área puede tener
-- petróleo convencional además del de Vaca Muerta, y el pronóstico no lo separa.
DROP TABLE IF EXISTS vm.pronostico_petroleo;
CREATE TABLE vm.pronostico_petroleo (
    anio_informe    integer NOT NULL,
    area_nombre     text    NOT NULL,
    area_id         text    REFERENCES vm.area,
    anio_pronostico integer NOT NULL,
    petroleo_m3     numeric NOT NULL CHECK (petroleo_m3 >= 0),
    PRIMARY KEY (anio_informe, area_nombre, anio_pronostico),
    CHECK (anio_pronostico BETWEEN anio_informe AND anio_informe + 4)
);
INSERT INTO vm.pronostico_petroleo
SELECT p.anio::integer,
       regexp_replace(trim(p.areapermisoconcesion), '\s+', ' ', 'g'),
       max(a.area_id),
       p.anio_pronostico::integer,
       sum(coalesce(nullif(p.cantidad_primaria, '')::numeric, 0)
         + coalesce(nullif(p.cantidad_secundaria, '')::numeric, 0))
FROM raw.pronostico_petroleo p
LEFT JOIN vm.area a ON a.nombre = regexp_replace(trim(p.areapermisoconcesion), '\s+', ' ', 'g')
WHERE p.provincia LIKE 'Neuqu%'
  AND trim(coalesce(p.areapermisoconcesion, '')) <> ''
  AND p.anio_pronostico::integer BETWEEN p.anio::integer AND p.anio::integer + 4
GROUP BY 1, 2, 4;
CREATE INDEX ON vm.pronostico_petroleo (area_id);


-- venteo_detectado: una fila por anomalía térmica vista por un satélite. Cada
-- una es un punto caliente en un día: una antorcha encendida se detecta muchas
-- veces. Es un conteo de detecciones, no un volumen de gas.
--   mes: sale de las columnas anio y mes de la fuente. En 488 filas la columna
--        fecha dice 2022 y el período dice 2021; me quedo con el período.
--   km_al_pozo: distancia al pozo de Vaca Muerta más cercano, para separar lo
--        que pasa en la zona de lo que pasa en el resto de la provincia.
DROP TABLE IF EXISTS vm.venteo_detectado;
CREATE TABLE vm.venteo_detectado (
    venteo_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mes         date    NOT NULL,
    provincia   text    NOT NULL,
    satelite    text    NOT NULL,
    latitud     numeric NOT NULL,
    longitud    numeric NOT NULL,
    km_al_pozo  numeric
);
INSERT INTO vm.venteo_detectado (mes, provincia, satelite, latitud, longitud)
SELECT make_date(anio::integer, mes::integer, 1), coalesce(provincia, 'SIN DATO'), coalesce(satelite_new, 'SIN DATO'), latitud::numeric, longitud::numeric
FROM raw.venteo_detectado
WHERE latitud <> '' AND longitud <> '';

-- Distancia al pozo más cercano. A esta latitud un grado de latitud son unos
-- 111 km y uno de longitud unos 87 km; alcanza para separar "al lado" de "lejos".
UPDATE vm.venteo_detectado v
SET km_al_pozo = d.km
FROM (
    SELECT v2.venteo_id,
           round(min(sqrt(power((v2.latitud - p.latitud) * 111.0, 2)
                        + power((v2.longitud - p.longitud) * 87.0, 2)))::numeric, 2) AS km
    FROM vm.venteo_detectado v2
    JOIN vm.pozo p ON p.latitud IS NOT NULL
                  AND p.latitud  BETWEEN v2.latitud  - 0.1 AND v2.latitud  + 0.1
                  AND p.longitud BETWEEN v2.longitud - 0.12 AND v2.longitud + 0.12
    WHERE v2.provincia = 'NEUQUEN'
    GROUP BY 1
) d
WHERE d.venteo_id = v.venteo_id;


-- metros_perforados: metros perforados por mes, provincia y tipo de pozo.
DROP TABLE IF EXISTS vm.metros_perforados;
CREATE TABLE vm.metros_perforados (
    mes       date    NOT NULL,
    provincia text    NOT NULL,
    concepto  text    NOT NULL,   -- Exploración, Avanzada, Explotación o Servicio
    metros    numeric NOT NULL CHECK (metros >= 0),
    PRIMARY KEY (mes, provincia, concepto)
);
INSERT INTO vm.metros_perforados
SELECT make_date(anio::integer, mes::integer, 1), provincia, concepto_metros, sum(metros_perforados::numeric)
FROM raw.metros_perforados
GROUP BY 1, 2, 3;
