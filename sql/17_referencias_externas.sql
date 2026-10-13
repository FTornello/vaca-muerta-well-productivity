-- Tres referencias de afuera, de la EIA (agencia de energía de Estados Unidos):
-- el precio internacional del petróleo, el precio del gas en ese país y la producción de las cuencas de shale
-- de ese país. Las prepara scripts/preparar_eia.py.
--   psql -d vaca_muerta -f sql/17_referencias_externas.sql

DROP TABLE IF EXISTS raw.brent;
CREATE TABLE raw.brent (mes text, usd_bbl text);
\copy raw.brent FROM 'data/raw/brent_mensual.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

DROP TABLE IF EXISTS raw.eeuu_tight_oil;
CREATE TABLE raw.eeuu_tight_oil (mes text, cuenca text, millones_bbl_dia text);
\copy raw.eeuu_tight_oil FROM 'data/raw/eeuu_tight_oil.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- brent: precio del crudo Brent, el de referencia para Argentina. Promedio del
-- mes, en dólares por barril.
DROP TABLE IF EXISTS vm.brent;
CREATE TABLE vm.brent (
    mes     date PRIMARY KEY,
    usd_bbl numeric NOT NULL CHECK (usd_bbl > 0)
);
INSERT INTO vm.brent SELECT mes::date, usd_bbl::numeric FROM raw.brent;

-- eeuu_tight_oil: petróleo de shale de Estados Unidos, por cuenca y por mes,
-- en miles de barriles por día. Las tres formaciones del Permian (Wolfcamp,
-- Spraberry y Bonespring) vienen separadas en la fuente.
DROP TABLE IF EXISTS vm.eeuu_tight_oil;
CREATE TABLE vm.eeuu_tight_oil (
    mes           date    NOT NULL,
    cuenca        text    NOT NULL,
    miles_bbl_dia numeric NOT NULL CHECK (miles_bbl_dia >= 0),
    PRIMARY KEY (mes, cuenca)
);
INSERT INTO vm.eeuu_tight_oil
SELECT mes::date, trim(cuenca), millones_bbl_dia::numeric * 1000 FROM raw.eeuu_tight_oil;

-- henry_hub: precio del gas natural en Estados Unidos (Henry Hub, Luisiana).
-- Promedio del mes, en dólares por millón de BTU, la misma unidad que
-- vm.precio_gas.
DROP TABLE IF EXISTS raw.henry_hub;
CREATE TABLE raw.henry_hub (mes text, usd_mmbtu text);
\copy raw.henry_hub FROM 'data/raw/henry_hub_mensual.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

DROP TABLE IF EXISTS vm.henry_hub;
CREATE TABLE vm.henry_hub (
    mes       date PRIMARY KEY,
    usd_mmbtu numeric NOT NULL CHECK (usd_mmbtu > 0)
);
INSERT INTO vm.henry_hub SELECT mes::date, usd_mmbtu::numeric FROM raw.henry_hub;
