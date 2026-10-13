-- Pregunta 13: ¿qué hace que un pozo de GAS rinda más?
-- Repite para los pozos gasíferos el análisis de las preguntas 1 a 7.
-- Rendimiento = caudal: miles de m3 por día activo durante el primer año.

-- 13a. El pozo típico por año de arranque: cuánto produce y cómo se diseña.
SELECT anio_arranque,
       count(*)                                                                               AS pozos,
       round((percentile_cont(0.5) WITHIN GROUP (ORDER BY gas_12m_miles_m3) / 1000)::numeric, 1) AS gas_12m_millones_m3,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY dias_activos_12m))                   AS dias_activos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY caudal_miles_m3_dia))                AS caudal,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY rama_m)   FILTER (WHERE diseno_confiable)) AS rama_m,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY arena_tn) FILTER (WHERE diseno_confiable)) AS arena_tn,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY caudal_miles_m3_dia / rama_m * 1000)
             FILTER (WHERE diseno_confiable))                                                 AS caudal_por_km
FROM vm.pozo_analisis_gas
WHERE anio_arranque >= 2017
GROUP BY anio_arranque
ORDER BY anio_arranque;

-- 13b. Por área, pozos desde 2021 (mínimo 10). Cada área tiene una sola operadora.
SELECT area,
       min(operadora)                                                                AS operadora,
       count(*)                                                                      AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY caudal_miles_m3_dia))       AS caudal,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY rama_m) FILTER (WHERE diseno_confiable)) AS rama_m,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY caudal_miles_m3_dia / rama_m * 1000)
             FILTER (WHERE diseno_confiable))                                        AS caudal_por_km
FROM vm.pozo_analisis_gas
WHERE anio_arranque >= 2021
GROUP BY area
HAVING count(*) >= 10
ORDER BY caudal DESC;

-- 13c. Mismo lugar, distinto nivel: U1 contra U2 dentro de cada área.
SELECT g.area,
       count(*) FILTER (WHERE t.unidad = 1)                                                    AS pozos_u1,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY g.caudal_miles_m3_dia / g.rama_m * 1000)
             FILTER (WHERE t.unidad = 1))                                                      AS caudal_por_km_u1,
       count(*) FILTER (WHERE t.unidad = 2)                                                    AS pozos_u2,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY g.caudal_miles_m3_dia / g.rama_m * 1000)
             FILTER (WHERE t.unidad = 2))                                                      AS caudal_por_km_u2
FROM vm.pozo_analisis_gas g
JOIN vm.trayectoria t USING (pozo_id)
WHERE g.anio_arranque >= 2019
  AND g.diseno_confiable
GROUP BY g.area
HAVING count(*) FILTER (WHERE t.unidad = 1) >= 8
   AND count(*) FILTER (WHERE t.unidad = 2) >= 8
ORDER BY pozos_u1 DESC;

-- 13d. Cercanía a un pozo padre del mismo nivel.
SELECT CASE WHEN v.distancia_previo_mismo_nivel_m IS NULL THEN '3. sin padre a menos de 1.500 m'
            WHEN v.distancia_previo_mismo_nivel_m < 500   THEN '1. menos de 500 m'
            ELSE                                               '2. de 500 a 1.500 m' END AS distancia_al_padre,
       count(*)                                                                          AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY g.caudal_miles_m3_dia / g.rama_m * 1000)) AS caudal_por_km
FROM vm.pozo_analisis_gas g
JOIN vm.pozo_vecindad v USING (pozo_id)
WHERE g.anio_arranque >= 2019
  AND g.diseno_confiable
GROUP BY 1
ORDER BY 1;

-- 13e. Qué pesa más (pozos desde 2021 con diseño confiable): el lugar, y la
--      arena una vez descontado el lugar.
WITH d AS (
    SELECT caudal_miles_m3_dia                                              AS caudal,
           avg(caudal_miles_m3_dia) OVER ()                                 AS prom_general,
           avg(caudal_miles_m3_dia) OVER (PARTITION BY area)                AS prom_area,
           arena_tn - avg(arena_tn) OVER (PARTITION BY area)                AS arena_vs_area
    FROM vm.pozo_analisis_gas
    WHERE diseno_confiable
      AND anio_arranque >= 2021
)
SELECT count(*)                                                                                   AS pozos,
       round(100 * (1 - sum((caudal - prom_area) ^ 2) / sum((caudal - prom_general) ^ 2))::numeric, 1) AS pct_lugar,
       round(100 * (corr(caudal - prom_area, arena_vs_area) ^ 2)::numeric, 1)                     AS pct_arena_dentro_del_area
FROM d;
