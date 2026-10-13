-- Producción y refinación de todo el país (Secretaría de Energía, vía la API de
-- series de datos.gob.ar). Sirve para medir qué parte del total es Vaca Muerta.
-- Se une con el resto solo por el mes.
--   psql -d vaca_muerta -f sql/14_contexto_pais.sql

DROP TABLE IF EXISTS raw.pais_energia;
CREATE TABLE raw.pais_energia (
    indice_tiempo             text,
    produccion_petroleo_crudo text,
    petroleo_crudo_procesado  text,
    produccion_gas_natural    text
);
\copy raw.pais_energia FROM 'data/raw/pais_petroleo_gas_refinacion.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- pais_energia: una fila por mes. Petróleo en miles de m3, gas en millones de m3.
-- Las tres series no terminan el mismo mes: la de gas llega más lejos, y por
-- eso las columnas de petróleo pueden venir vacías en los últimos meses.
DROP TABLE IF EXISTS vm.pais_energia;
CREATE TABLE vm.pais_energia (
    mes                      date PRIMARY KEY,
    petroleo_producido_km3   numeric CHECK (petroleo_producido_km3 > 0),
    petroleo_procesado_km3   numeric CHECK (petroleo_procesado_km3 > 0),
    gas_producido_mm_m3      numeric CHECK (gas_producido_mm_m3 > 0)
);
INSERT INTO vm.pais_energia
SELECT indice_tiempo::date,
       nullif(produccion_petroleo_crudo, '')::numeric,
       nullif(petroleo_crudo_procesado, '')::numeric,
       nullif(produccion_gas_natural, '')::numeric
FROM raw.pais_energia
WHERE coalesce(produccion_petroleo_crudo, '') <> '' OR coalesce(produccion_gas_natural, '') <> '';
