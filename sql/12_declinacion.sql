-- Carga el resultado de scripts/ajustar_declinacion.py: para cada mes de vida de
-- un pozo petrolero (1 a 300), cuánto lleva acumulado en relación con lo que
-- produce en su primer año. Tres escenarios según el piso de declinación que se
-- supone para los años todavía no observados.
--   psql -d vaca_muerta -f sql/12_declinacion.sql

DROP TABLE IF EXISTS vm.declinacion;
CREATE TABLE vm.declinacion (
    mes_de_vida    integer PRIMARY KEY CHECK (mes_de_vida BETWEEN 1 AND 300),
    origen         text NOT NULL CHECK (origen IN ('observado', 'ajustado')),
    caudal_bajo    numeric NOT NULL,
    acumulado_bajo numeric NOT NULL,   -- piso de declinación de 12 % anual
    caudal_base    numeric NOT NULL,
    acumulado_base numeric NOT NULL,   -- piso de 8 % anual
    caudal_alto    numeric NOT NULL,
    acumulado_alto numeric NOT NULL    -- piso de 6 % anual
);
\copy vm.declinacion FROM 'data/declinacion.csv' WITH (FORMAT csv, HEADER true)
