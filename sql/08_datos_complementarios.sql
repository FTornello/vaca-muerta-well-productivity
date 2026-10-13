-- Tres datasets más de la Secretaría de Energía, para las preguntas 10 a 12:
-- precios del gas, volúmenes transportados por ducto e inversiones declaradas.
-- Se corre después de 03_capa_limpia.sql:
--   psql -d vaca_muerta -f sql/08_datos_complementarios.sql

-- Capa raw -------------------------------------------------------------------
DROP TABLE IF EXISTS raw.precios_gas;
CREATE TABLE raw.precios_gas (
    id_pub text, anio text, mes text, cuenca text, contrato text,
    precio_distribuidora text, precio_gnc text, precio_usina text,
    precio_industria text, precio_otros text, precio_ppp text, precio_expo text,
    indice_tiempo text, fecha text
);
\copy raw.precios_gas FROM 'data/raw/precios_gas_natural.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

DROP TABLE IF EXISTS raw.transporte_ductos;
CREATE TABLE raw.transporte_ductos (
    empresa text, anio text, mes text, idducto text, denominacion_ducto text,
    tipo_ducto text, tipo_jurisdiccion text, idnodo_origen text, nodo_origen text,
    idnodo_destino text, nodo_destino text, tipo_destino text, area text,
    cargador text, tipo_producto text, producto text, tipo_mercado text,
    volumen text, longitud_ducto text, longitud_tramo text, tipo_operacion text,
    pais text, idtramo_transporte text, tramo_transporte text, obs text,
    idempresa text, fecha_data text
);
\copy raw.transporte_ductos FROM 'data/raw/transporte_ductos_planilla20.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- Los encabezados de la fuente tienen espacios, acentos y signos; acá van renombrados.
DROP TABLE IF EXISTS raw.inversiones;
CREATE TABLE raw.inversiones (
    anio text, empresa text, idempresa text, area text, idconcesion text,
    yacimiento text, cuenca text, ubicacion text, provincia text, periodo text,
    estado_ddjj text, mes text, concepto text,
    cantidad_exploracion text, usd_mm_exploracion text,
    cantidad_explotacion text, usd_mm_explotacion text,
    cantidad_complementaria text, usd_mm_complementaria text,
    horas_hombre text, fecha_inicio text, fecha_fin text, tipo_explotacion text
);
\copy raw.inversiones FROM 'data/raw/inversiones_upstream_mensual.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')


-- grupo_alias: une los nombres de empresa de cada fuente con un grupo
-- empresario. Cada fuente escribe las empresas a su manera (con o sin acentos,
-- distintas razones sociales del mismo grupo), así que se comparan los nombres
-- normalizados: en mayúsculas, sin acentos y sin espacios repetidos.
--   - Las razones sociales que ya están en vm.empresa heredan su operadora.
--   - Las que solo aparecen en otras fuentes se agregan a mano. Varias son
--     socios que no operan áreas (por eso no figuran en producción) pero sí
--     invierten o exportan su parte: quedan con operadora_id nulo.
CREATE OR REPLACE FUNCTION vm.normalizar_nombre(nombre text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT regexp_replace(trim(translate(upper(nombre), 'ÁÉÍÓÚÜÑ', 'AEIOUUN')), '\s+', ' ', 'g')
$$;

DROP TABLE IF EXISTS vm.grupo_alias CASCADE;
CREATE TABLE vm.grupo_alias (
    nombre_normalizado text PRIMARY KEY,
    grupo              text NOT NULL,
    operadora_id       integer REFERENCES vm.operadora
);

INSERT INTO vm.grupo_alias
SELECT DISTINCT ON (vm.normalizar_nombre(e.razon_social))
       vm.normalizar_nombre(e.razon_social), o.nombre, o.operadora_id
FROM vm.empresa e
JOIN vm.operadora o USING (operadora_id)
ORDER BY vm.normalizar_nombre(e.razon_social);

INSERT INTO vm.grupo_alias (nombre_normalizado, grupo, operadora_id)
SELECT vm.normalizar_nombre(m.nombre), m.grupo, o.operadora_id
FROM (VALUES
    ('VISTA ENERGY LACH S.A.',                                          'Vista'),
    ('PLUSPETROL ENERGY S.A.',                                          'Pluspetrol'),
    ('EXXONMOBIL EXPLORATION AND PRODUCTION OFFSHORE ARGENTINA S.R.L.', 'ExxonMobil'),
    ('EQUINOR ARGENTINA S.A.U.',                                        'Equinor'),
    ('EQUINOR ARGENTINA AS SUCURSAL ARGENTINA',                         'Equinor'),
    ('EQUINOR B.V. (SUCURSAL ARGENTINA)',                               'Equinor'),
    ('PETRONAS E&P ARGENTINA S.A.',                                     'Petronas'),
    ('COMPAÑIA DE HIDROCARBURO NO CONVENCIONAL S.R.L.',                 'CHNC'),
    ('COMPAÑIA DE DESARROLLO NO CONVENCIONAL S.R.L.',                   'CDNC'),
    ('PETROLEOS SUDAMERICANOS S.A.',                                    'Petróleos Sudamericanos'),
    ('PRESIDENT PETROLEUM S.A.',                                        'President Petroleum'),
    ('TRAFIGURA ARGENTINA S.A.',                                        'Trafigura')
) AS m (nombre, grupo)
LEFT JOIN vm.operadora o ON o.nombre = m.grupo
ON CONFLICT (nombre_normalizado) DO NOTHING;


-- precio_gas: precio promedio del gas de la cuenca Neuquina por mes, en
-- dólares por millón de BTU. Se toma el total de contratos (firmes más
-- interrumpibles). precio_promedio es el promedio ponderado de todos los
-- destinos internos; precio_exportacion es el del gas exportado.
DROP TABLE IF EXISTS vm.precio_gas;
CREATE TABLE vm.precio_gas (
    mes                   date PRIMARY KEY,
    precio_promedio       numeric,
    precio_distribuidoras numeric,   -- lo que pagan las distribuidoras que abastecen hogares y comercios
    precio_usinas         numeric,
    precio_industria      numeric,
    precio_gnc            numeric,
    precio_exportacion    numeric
);
INSERT INTO vm.precio_gas
SELECT make_date(anio::integer, mes::integer, 1),
       nullif(precio_ppp::numeric, 0),
       nullif(precio_distribuidora::numeric, 0),
       nullif(precio_usina::numeric, 0),
       nullif(precio_industria::numeric, 0),
       nullif(precio_gnc::numeric, 0),
       nullif(precio_expo::numeric, 0)
FROM raw.precios_gas
WHERE cuenca = 'Neuquina'
  AND contrato = 'TOTAL';


-- oleoducto_troncal: volumen mensual del oleoducto Allen - Puerto Rosales de
-- Oldelval, la salida principal del petróleo de la cuenca Neuquina hacia el
-- Atlántico. Tiene dos caños: el original y el Duplicar (desde marzo de 2025).
-- Volumen en m3 de petróleo.
DROP TABLE IF EXISTS vm.oleoducto_troncal;
CREATE TABLE vm.oleoducto_troncal (
    mes               date PRIMARY KEY,
    cano_original_m3  numeric NOT NULL,
    duplicar_m3       numeric NOT NULL
);
INSERT INTO vm.oleoducto_troncal
SELECT make_date(anio::integer, mes::integer, 1),
       coalesce(sum(volumen::numeric) FILTER (WHERE denominacion_ducto = 'Allen - Puerto Rosales'), 0),
       coalesce(sum(volumen::numeric) FILTER (WHERE denominacion_ducto = 'Allen - Puerto Rosales (Duplicar)'), 0)
FROM raw.transporte_ductos
WHERE empresa LIKE 'OLEODUCTOS DEL VALLE%'
  AND denominacion_ducto LIKE 'Allen - Puerto Rosales%'
GROUP BY 1;


-- inversion: millones de dólares declarados por las empresas (Res. 2057) en
-- áreas no convencionales de la cuenca Neuquina, por mes, área y concepto.
-- El área se enlaza con vm.area por nombre; queda nula si no hay pozos de
-- Vaca Muerta en esa área. Son declaraciones juradas: la fuente no las audita.
DROP TABLE IF EXISTS vm.inversion;
CREATE TABLE vm.inversion (
    mes          date NOT NULL,
    area_nombre  text NOT NULL,
    area_id      text REFERENCES vm.area,
    empresa      text NOT NULL,
    concepto     text NOT NULL,
    grupo        text,             -- grupo empresario, según vm.grupo_alias
    es_perforacion boolean NOT NULL,
    usd_millones numeric NOT NULL
);
WITH meses (nombre, numero) AS (
    VALUES ('Enero', 1), ('Febrero', 2), ('Marzo', 3), ('Abril', 4), ('Mayo', 5), ('Junio', 6),
           ('Julio', 7), ('Agosto', 8), ('Septiembre', 9), ('Octubre', 10), ('Noviembre', 11), ('Diciembre', 12)
)
INSERT INTO vm.inversion
SELECT make_date(i.anio::integer, m.numero, 1),
       regexp_replace(trim(i.area), '\s+', ' ', 'g'),
       a.area_id,
       i.empresa,
       i.concepto,
       g.grupo,
       i.concepto LIKE 'Perforación Pozos%',
       sum(coalesce(i.usd_mm_exploracion::numeric, 0)
         + coalesce(i.usd_mm_explotacion::numeric, 0)
         + coalesce(i.usd_mm_complementaria::numeric, 0))
FROM raw.inversiones i
JOIN meses m ON m.nombre = i.mes
LEFT JOIN vm.area a ON a.nombre = regexp_replace(trim(i.area), '\s+', ' ', 'g')
LEFT JOIN vm.grupo_alias g ON g.nombre_normalizado = vm.normalizar_nombre(i.empresa)
WHERE i.cuenca = 'NEUQUINA'
  AND i.tipo_explotacion = 'No Convencional'
GROUP BY 1, 2, 3, 4, 5, 6, 7
HAVING sum(coalesce(i.usd_mm_exploracion::numeric, 0)
         + coalesce(i.usd_mm_explotacion::numeric, 0)
         + coalesce(i.usd_mm_complementaria::numeric, 0)) <> 0;

CREATE INDEX ON vm.inversion (area_id);
ANALYZE;


-- Exportaciones por barco y reservas, para las preguntas 14 y 15 ----------------

DROP TABLE IF EXISTS raw.terminales_maritimas;
CREATE TABLE raw.terminales_maritimas (
    empresa text, cuit text, anio text, mes text, idnodo text, nodo_origen text,
    tipo_mercado text, tipo_operacion text, pais text, cargador text, producto text,
    volumen text, obs text, idnodo_destino text, nodo_destino text, fecha_data text
);
\copy raw.terminales_maritimas FROM 'data/raw/terminales_maritimas_planilla21.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- Las reservas vienen en un Excel por año; scripts/preparar_reservas.py las
-- unifica en este CSV.
DROP TABLE IF EXISTS raw.reservas;
CREATE TABLE raw.reservas (
    anio text, operador text, cuenca text, provincia text, concesion text, yacimiento text,
    petroleo_comprobadas text, gas_comprobadas text, petroleo_probables text, gas_probables text,
    petroleo_posibles text, gas_posibles text, petroleo_recursos text, gas_recursos text
);
\copy raw.reservas FROM 'data/reservas_no_convencional.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')


-- exportacion: petróleo de la cuenca Neuquina que sale del país, por mes, vía,
-- país de destino y empresa que lo carga. Volumen en m3. Dos vías:
--   'barco':     desde la terminal de Puerto Rosales (la fuente le cambió el
--                nombre en 2023; se unifica).
--   'oleoducto': a Chile por el Oleoducto Trasandino, reabierto en 2023.
DROP TABLE IF EXISTS vm.exportacion_maritima;
DROP TABLE IF EXISTS vm.exportacion;
CREATE TABLE vm.exportacion (
    mes        date NOT NULL,
    via        text NOT NULL,
    pais       text NOT NULL,
    cargador   text NOT NULL,
    volumen_m3 numeric NOT NULL,
    grupo      text              -- grupo empresario, según vm.grupo_alias
);
INSERT INTO vm.exportacion (mes, via, pais, cargador, volumen_m3)
SELECT make_date(anio::integer, mes::integer, 1),
       'barco',
       initcap(coalesce(nullif(trim(pais), ''), 'NO IDENTIFICADO')),
       upper(trim(cargador)),
       sum(volumen::numeric)
FROM raw.terminales_maritimas
WHERE tipo_mercado = 'Externo'
  AND upper(nodo_origen) LIKE '%PUERTO ROSALES%'
GROUP BY 1, 3, 4
HAVING sum(volumen::numeric) > 0;

INSERT INTO vm.exportacion (mes, via, pais, cargador, volumen_m3)
SELECT make_date(anio::integer, mes::integer, 1),
       'oleoducto',
       'Chile',
       upper(trim(cargador)),
       sum(volumen::numeric)
FROM raw.transporte_ductos
WHERE empresa LIKE 'Oleoducto Trasandino%'
  AND tipo_mercado = 'Externo'
GROUP BY 1, 4
HAVING sum(volumen::numeric) > 0;


UPDATE vm.exportacion e
SET grupo = g.grupo
FROM vm.grupo_alias g
WHERE g.nombre_normalizado = vm.normalizar_nombre(e.cargador);


-- reserva: reservas no convencionales por área al 31 de diciembre de cada año
-- (2017 a 2025), sumando los yacimientos de cada concesión. Petróleo en miles
-- de m3 y gas en millones de m3, como en la fuente.
--   comprobadas: se pueden producir con una certeza razonable, con la tecnología
--                y los precios actuales.
--   probables y posibles: cada vez menos seguras.
--   recursos:    volúmenes identificados que todavía no son comerciales.
DROP TABLE IF EXISTS vm.reserva;
CREATE TABLE vm.reserva (
    anio                    integer NOT NULL,
    area_nombre             text NOT NULL,
    area_id                 text REFERENCES vm.area,
    petroleo_comprobadas    numeric NOT NULL,
    petroleo_probables      numeric NOT NULL,
    petroleo_recursos       numeric NOT NULL,
    gas_comprobadas         numeric NOT NULL,
    gas_probables           numeric NOT NULL,
    gas_recursos            numeric NOT NULL,
    PRIMARY KEY (anio, area_nombre)
);
INSERT INTO vm.reserva
SELECT r.anio::integer,
       r.concesion,
       a.area_id,
       sum(r.petroleo_comprobadas::numeric),
       sum(r.petroleo_probables::numeric),
       sum(r.petroleo_recursos::numeric),
       sum(r.gas_comprobadas::numeric),
       sum(r.gas_probables::numeric),
       sum(r.gas_recursos::numeric)
FROM raw.reservas r
LEFT JOIN vm.area a ON a.nombre = r.concesion
GROUP BY r.anio::integer, r.concesion, a.area_id;

ANALYZE;
