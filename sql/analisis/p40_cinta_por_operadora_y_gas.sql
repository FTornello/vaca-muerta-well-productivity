-- Pregunta 40: ¿a quién le pesa más la cinta de correr? ¿Y al gas?
-- La pregunta 24 midió, para todo Vaca Muerta, cuánto pierde en un año el
-- conjunto de pozos que ya existía. Acá lo abro por operadora y lo repito
-- para los pozos de gas.

-- 40a. Por operadora, año 2025: lo que producían en diciembre de 2024 sus
--      pozos, lo que daban esos mismos pozos un año después, y qué parte del
--      aporte de sus pozos nuevos se fue en reponer la caída. Miles de barriles
--      por día. La operadora es la que informó la producción ese mes; el
--      conjunto de pozos de cada una se fija en diciembre de 2024, así que un
--      área que cambió de manos en 2025 sigue contando para quien la tenía.
WITH prod AS (
    SELECT pm.pozo_id, pm.mes, pm.petroleo_m3 * 6.2898 / 31 / 1000 AS kbd,
           o.nombre AS operadora, po.primer_mes_produccion AS inicio
    FROM vm.produccion_mensual pm
    JOIN vm.pozo po USING (pozo_id)
    JOIN vm.empresa e USING (empresa_codigo)
    JOIN vm.operadora o USING (operadora_id)
    WHERE pm.mes IN (DATE '2024-12-01', DATE '2025-12-01')
),
duenio AS (
    SELECT pozo_id, operadora FROM prod WHERE mes = DATE '2024-12-01' AND kbd > 0
),
base AS (
    SELECT d.operadora,
           count(DISTINCT d.pozo_id)                              AS pozos,
           sum(p.kbd) FILTER (WHERE p.mes = DATE '2024-12-01')    AS inicio,
           sum(p.kbd) FILTER (WHERE p.mes = DATE '2025-12-01')    AS fin
    FROM duenio d
    JOIN prod p USING (pozo_id)
    GROUP BY 1
),
nuevos AS (
    SELECT operadora, count(*) AS pozos, sum(kbd) AS aporte
    FROM prod
    WHERE mes = DATE '2025-12-01' AND inicio BETWEEN DATE '2025-01-01' AND DATE '2025-12-01'
    GROUP BY 1
)
SELECT b.operadora,
       b.pozos                                        AS pozos_de_la_base,
       round(b.inicio)                                AS producian_dic_2024,
       round(100 * (1 - b.fin / b.inicio))            AS caida_de_la_base_pct,
       n.pozos                                        AS pozos_nuevos_2025,
       round(n.aporte)                                AS aportaron,
       round(100 * (b.inicio - b.fin) / n.aporte)     AS pct_que_solo_repuso,
       round(b.fin + n.aporte - b.inicio)             AS crecimiento_neto
FROM base b
JOIN nuevos n USING (operadora)
WHERE b.inicio >= 10
ORDER BY b.inicio DESC;

-- 40b. Lo mismo para el gas. Como a los pozos de gas los cierran en primavera
--      (pregunta 9), comparo julio contra julio, que es cuando producen a
--      pleno. Solo pozos gasíferos. Millones de m3 por día.
WITH gasiferos AS (
    SELECT pozo_id FROM vm.pozo_analisis_gas
),
base AS (
    SELECT y.anio, pm.pozo_id
    FROM generate_series(2020, 2026) AS y(anio)
    JOIN vm.produccion_mensual pm ON pm.mes = make_date(y.anio - 1, 7, 1) AND pm.gas_miles_m3 > 0
    JOIN gasiferos g USING (pozo_id)
)
SELECT b.anio                                                                                     AS julio_de,
       count(DISTINCT b.pozo_id)                                                                  AS pozos_de_la_base,
       round(sum(pm.gas_miles_m3) FILTER (WHERE pm.mes = make_date(b.anio - 1, 7, 1)) / 31 / 1000, 1) AS producian_un_anio_antes,
       round(sum(pm.gas_miles_m3) FILTER (WHERE pm.mes = make_date(b.anio, 7, 1)) / 31 / 1000, 1)     AS producen_ahora,
       round(100 * (1 - sum(pm.gas_miles_m3) FILTER (WHERE pm.mes = make_date(b.anio, 7, 1))
                      / sum(pm.gas_miles_m3) FILTER (WHERE pm.mes = make_date(b.anio - 1, 7, 1))))     AS caida_pct
FROM base b
JOIN vm.produccion_mensual pm
  ON pm.pozo_id = b.pozo_id AND pm.mes IN (make_date(b.anio - 1, 7, 1), make_date(b.anio, 7, 1))
GROUP BY 1
ORDER BY 1;
