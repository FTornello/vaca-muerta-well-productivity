-- Controles de la capa limpia: cada fila compara la fuente (raw) con el modelo
-- (vm). La columna ok tiene que dar true en todas.
--   psql -d vaca_muerta -f sql/04_controles.sql

WITH fuente AS (
    SELECT * FROM raw.produccion WHERE lower(formacion) = 'vaca muerta'
),
controles (control, esperado, obtenido) AS (
    SELECT 'pozos',
           (SELECT count(DISTINCT idpozo) FROM fuente)::numeric,
           (SELECT count(*) FROM vm.pozo)::numeric
    UNION ALL
    SELECT 'filas de producción',
           (SELECT count(*) FROM fuente),
           (SELECT count(*) FROM vm.produccion_mensual)
    UNION ALL
    SELECT 'petróleo total (m3)',
           (SELECT round(sum(prod_pet::numeric) FILTER (WHERE prod_pet::numeric >= 0)) FROM fuente),
           (SELECT round(sum(petroleo_m3)) FROM vm.produccion_mensual)
    UNION ALL
    SELECT 'gas total (miles de m3)',
           (SELECT round(sum(prod_gas::numeric) FILTER (WHERE prod_gas::numeric >= 0)) FROM fuente),
           (SELECT round(sum(gas_miles_m3)) FROM vm.produccion_mensual)
    UNION ALL
    SELECT 'empresas',
           (SELECT count(DISTINCT idempresa) FROM fuente),
           (SELECT count(*) FROM vm.empresa)
    UNION ALL
    SELECT 'áreas',
           (SELECT count(DISTINCT idareapermisoconcesion) FROM fuente),
           (SELECT count(*) FROM vm.area)
    UNION ALL
    SELECT 'pozos con primera fractura',
           (SELECT count(DISTINCT f.idpozo)
            FROM raw.fractura f
            WHERE lower(f.formacion_productiva) = 'vaca muerta'
              AND f.idpozo IN (SELECT idpozo FROM fuente)),
           (SELECT count(*) FROM vm.fractura WHERE nro_fractura = 1)
    UNION ALL
    SELECT 'pozos sin empresa inicial en vm.empresa',
           0,
           (SELECT count(*) FROM vm.pozo p
            WHERE NOT EXISTS (SELECT 1 FROM vm.empresa e WHERE e.empresa_codigo = p.empresa_inicial))
)
SELECT control, esperado, obtenido, esperado = obtenido AS ok
FROM controles;
