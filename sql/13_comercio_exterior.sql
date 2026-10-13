-- Comercio exterior de energía del país (INDEC, vía la API de series de datos.gob.ar).
-- No es un dato de Vaca Muerta: es el contexto contra el que se compara. Se une
-- con el resto solo por el mes.
--   psql -d vaca_muerta -f sql/13_comercio_exterior.sql

DROP TABLE IF EXISTS raw.comercio_energia;
CREATE TABLE raw.comercio_energia (
    indice_tiempo                               text,
    ica_exportacion_combustible_energia         text,
    ica_importaciones_combustibles_lubricantes  text,
    ica_saldo_comercial                         text
);
\copy raw.comercio_energia FROM 'data/raw/comercio_energia_indec.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- comercio_energia: una fila por mes, en millones de dólares.
--   exportacion_energia:  rubro "combustibles y energía" de las exportaciones.
--   importacion_energia:  uso "combustibles y lubricantes" de las importaciones.
--   saldo_total:          exportaciones menos importaciones de TODO el país.
DROP TABLE IF EXISTS vm.comercio_energia;
CREATE TABLE vm.comercio_energia (
    mes                  date PRIMARY KEY,
    exportacion_energia  numeric NOT NULL CHECK (exportacion_energia >= 0),
    importacion_energia  numeric NOT NULL CHECK (importacion_energia >= 0),
    saldo_total          numeric NOT NULL
);
INSERT INTO vm.comercio_energia
SELECT indice_tiempo::date,
       ica_exportacion_combustible_energia::numeric,
       ica_importaciones_combustibles_lubricantes::numeric,
       ica_saldo_comercial::numeric
FROM raw.comercio_energia
WHERE ica_exportacion_combustible_energia <> '';
