-- Regalías, empleo registrado y precios de combustibles: lo que le llega a la
-- gente. Preguntas 16, 17 y 23.
-- Se corre después de 03_capa_limpia.sql:
--   psql -d vaca_muerta -f sql/09_regalias_y_empleo.sql

-- Capa raw -------------------------------------------------------------------
-- El informe de regalías es un Excel; scripts/preparar_regalias.py lo deja en CSV.
DROP TABLE IF EXISTS raw.regalias_petroleo;
CREATE TABLE raw.regalias_petroleo (
    anio text, mes text, provincia text, regalias_usd text, precio_usd_m3 text, produccion_m3 text
);
\copy raw.regalias_petroleo FROM 'data/regalias_petroleo.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

DROP TABLE IF EXISTS raw.regalias_gas;
CREATE TABLE raw.regalias_gas (
    anio text, mes text, provincia text, regalias_ars text, precio_ars_mil_m3 text, produccion_miles_m3 text
);
\copy raw.regalias_gas FROM 'data/regalias_gas.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- Tipo de cambio oficial (Banco Nación, vendedor), promedio mensual. Sale de la
-- API de series de tiempo de datos.gob.ar.
DROP TABLE IF EXISTS raw.tipo_de_cambio;
CREATE TABLE raw.tipo_de_cambio (indice_tiempo text, tipo_cambio_bna_vendedor text);
\copy raw.tipo_de_cambio FROM 'data/raw/tipo_de_cambio_bna.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- Empleo y salarios: de los archivos nacionales (95 MB cada uno) se bajan solo
-- las filas de la provincia de Neuquén.
DROP TABLE IF EXISTS raw.empleo_neuquen;
CREATE TABLE raw.empleo_neuquen (
    fecha text, codigo_departamento_indec text, id_provincia_indec text, clae2 text, puestos text
);
\copy raw.empleo_neuquen FROM 'data/raw/empleo_neuquen_por_depto_clae2.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

DROP TABLE IF EXISTS raw.salario_neuquen;
CREATE TABLE raw.salario_neuquen (
    fecha text, codigo_departamento_indec text, id_provincia_indec text, clae2 text, w_median text
);
\copy raw.salario_neuquen FROM 'data/raw/salario_mediano_neuquen_por_depto_clae2.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

DROP TABLE IF EXISTS raw.diccionario_departamentos;
CREATE TABLE raw.diccionario_departamentos (
    codigo_departamento_indec text, nombre_departamento_indec text, id_provincia_indec text, nombre_provincia_indec text
);
\copy raw.diccionario_departamentos FROM 'data/raw/diccionario_departamentos.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

DROP TABLE IF EXISTS raw.diccionario_clae;
CREATE TABLE raw.diccionario_clae (
    clae6 text, clae6_desc text, clae3 text, clae3_desc text, clae2 text, clae2_desc text, letra text, letra_desc text
);
\copy raw.diccionario_clae FROM 'data/raw/diccionario_clae.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')


-- Precios en estaciones de servicio, ya resumidos por mes, provincia y producto
-- (lo arma scripts/descargar_precios_surtidor.py con la API del portal).
DROP TABLE IF EXISTS raw.precios_surtidor;
CREATE TABLE raw.precios_surtidor (
    anio text, mes text, provincia text, producto text, estaciones text,
    precio_surtidor text, precio_sin_impuestos text
);
\copy raw.precios_surtidor FROM 'data/raw/precios_surtidor_mensual.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')


-- regalia_petroleo: una fila por mes y provincia. Lo que cada provincia cobra
-- por el petróleo crudo, el precio al que se liquidó y el volumen sobre el que
-- se calculó. La base de cálculo no es idéntica a la producción por pozo: el
-- condensado de los pozos de gas se liquida aparte.
DROP TABLE IF EXISTS vm.regalia_petroleo;
CREATE TABLE vm.regalia_petroleo (
    mes            date NOT NULL,
    provincia      text NOT NULL,
    regalias_usd   numeric NOT NULL,
    precio_usd_m3  numeric,
    produccion_m3  numeric NOT NULL,
    PRIMARY KEY (mes, provincia)
);
INSERT INTO vm.regalia_petroleo
SELECT make_date(anio::integer, mes::integer, 1),
       provincia,
       regalias_usd::numeric,
       nullif(precio_usd_m3::numeric, 0),
       produccion_m3::numeric
FROM raw.regalias_petroleo;


-- tipo_de_cambio: pesos por dólar, promedio de cada mes (desde diciembre de 2014).
DROP TABLE IF EXISTS vm.regalia_gas;
DROP TABLE IF EXISTS vm.tipo_de_cambio;
CREATE TABLE vm.tipo_de_cambio (
    mes             date PRIMARY KEY,
    pesos_por_dolar numeric NOT NULL CHECK (pesos_por_dolar > 0)
);
INSERT INTO vm.tipo_de_cambio
SELECT indice_tiempo::date, tipo_cambio_bna_vendedor::numeric
FROM raw.tipo_de_cambio;


-- regalia_gas: una fila por mes y provincia. La fuente publica las regalías de
-- gas en pesos; regalias_usd las convierte con el tipo de cambio promedio del
-- mes. La liquidación real usa el tipo de cambio de un día puntual, así que el
-- valor en dólares es una aproximación.
CREATE TABLE vm.regalia_gas (
    mes                 date NOT NULL REFERENCES vm.tipo_de_cambio,
    provincia           text NOT NULL,
    regalias_ars        numeric NOT NULL,
    regalias_usd        numeric NOT NULL,
    produccion_miles_m3 numeric NOT NULL,
    PRIMARY KEY (mes, provincia)
);
INSERT INTO vm.regalia_gas
SELECT t.mes,
       r.provincia,
       r.regalias_ars::numeric,
       r.regalias_ars::numeric / t.pesos_por_dolar,
       r.produccion_miles_m3::numeric
FROM raw.regalias_gas r
JOIN vm.tipo_de_cambio t ON t.mes = make_date(r.anio::integer, r.mes::integer, 1);


-- empleo_neuquen: puestos de trabajo privados registrados en la provincia de
-- Neuquén y salario bruto mediano, por mes, departamento y sector (enero de
-- 2014 a noviembre de 2023; la serie se dejó de publicar).
-- La fuente oculta las celdas con pocos empleadores (secreto estadístico): esas
-- filas se excluyen. El puesto figura en el departamento que declara el
-- empleador, que no siempre es donde se trabaja.
DROP TABLE IF EXISTS vm.empleo_neuquen;
CREATE TABLE vm.empleo_neuquen (
    mes               date NOT NULL,
    departamento      text NOT NULL,
    sector            text NOT NULL,
    es_petroleo_y_gas boolean NOT NULL,   -- extracción más servicios de apoyo
    puestos           integer NOT NULL,
    salario_mediano   numeric,            -- pesos corrientes
    PRIMARY KEY (mes, departamento, sector)
);
WITH sectores AS (
    SELECT DISTINCT clae2, trim(clae2_desc) AS sector FROM raw.diccionario_clae
)
INSERT INTO vm.empleo_neuquen
SELECT e.fecha::date,
       d.nombre_departamento_indec,
       s.sector,
       e.clae2 IN ('6', '9'),
       e.puestos::integer,
       CASE WHEN w.w_median::numeric > 0 THEN w.w_median::numeric END
FROM raw.empleo_neuquen e
JOIN raw.diccionario_departamentos d USING (codigo_departamento_indec)
JOIN sectores s USING (clae2)
LEFT JOIN raw.salario_neuquen w USING (fecha, codigo_departamento_indec, clae2)
WHERE e.puestos::integer > 0;


-- precio_surtidor: una fila por mes, provincia y producto. Mediana de lo que
-- informan las estaciones que venden al público, en pesos por litro.
--   precio_surtidor:       lo que paga quien carga.
--   precio_sin_impuestos:  lo mismo antes de impuestos.
-- Los nombres largos de producto de la fuente se acortan.
DROP TABLE IF EXISTS vm.precio_surtidor;
CREATE TABLE vm.precio_surtidor (
    mes                  date NOT NULL,
    provincia            text NOT NULL,
    producto             text NOT NULL CHECK (producto IN ('nafta súper', 'nafta premium', 'gasoil grado 2', 'gasoil grado 3')),
    estaciones           integer NOT NULL,
    precio_surtidor      numeric NOT NULL CHECK (precio_surtidor > 0),
    precio_sin_impuestos numeric NOT NULL CHECK (precio_sin_impuestos > 0),
    PRIMARY KEY (mes, provincia, producto)
);
INSERT INTO vm.precio_surtidor
SELECT make_date(anio::integer, mes::integer, 1),
       initcap(provincia),
       CASE WHEN producto LIKE 'Nafta (s%per)%'   THEN 'nafta súper'
            WHEN producto LIKE 'Nafta (premium)%' THEN 'nafta premium'
            WHEN producto = 'Gas Oil Grado 2'     THEN 'gasoil grado 2'
            WHEN producto = 'Gas Oil Grado 3'     THEN 'gasoil grado 3' END,
       estaciones::integer,
       precio_surtidor::numeric,
       precio_sin_impuestos::numeric
FROM raw.precios_surtidor
WHERE producto <> 'Gas Oil Grado 2B';

ANALYZE;
