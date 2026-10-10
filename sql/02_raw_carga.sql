-- Carga de los CSV en la capa raw. Correr con psql desde la raíz del proyecto:
--   psql -d vaca_muerta -f sql/02_raw_carga.sql

TRUNCATE raw.produccion;
\copy raw.produccion FROM 'data/raw/produccion_no_convencional.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

TRUNCATE raw.fractura;
\copy raw.fractura FROM 'data/raw/fractura_adjunto_iv.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

TRUNCATE raw.padron_pozos;
\copy raw.padron_pozos FROM 'data/raw/padron_pozos_capitulo_iv.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
