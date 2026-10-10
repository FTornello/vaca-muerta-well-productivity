-- Pregunta 2: ¿los pozos con rama más larga, más etapas y más arena producen
-- más, o llega un punto donde ya no rinde?
-- Población: pozos de vm.pozo_analisis con diseño confiable.

-- 2a. Cómo cambió el diseño del pozo típico año a año, y qué pasó con lo que
--     rinde cada kilómetro de rama.
SELECT anio_arranque,
       count(*)                                                                            AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY rama_m))                          AS rama_m,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY etapas))                          AS etapas,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY arena_tn))                        AS arena_tn,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3))                 AS petroleo_12m_m3,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / rama_m * 1000)) AS petroleo_por_km_m3
FROM vm.pozo_analisis
WHERE diseno_confiable
  AND anio_arranque >= 2015
GROUP BY anio_arranque
ORDER BY anio_arranque;

-- 2b. Pozos desde 2021 agrupados por largo de rama, en tramos de 500 metros.
SELECT floor(rama_m / 500) * 500                                                           AS rama_desde_m,
       count(*)                                                                            AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3))                 AS petroleo_12m_m3,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / rama_m * 1000)) AS petroleo_por_km_m3
FROM vm.pozo_analisis
WHERE diseno_confiable
  AND anio_arranque >= 2021
GROUP BY 1
HAVING count(*) >= 10
ORDER BY 1;

-- 2c. Pozos desde 2021 agrupados por intensidad de arena (toneladas por metro
--     de rama), en tramos de media tonelada.
SELECT floor(arena_tn / rama_m / 0.5) * 0.5                                                AS arena_desde_tn_por_m,
       count(*)                                                                            AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / rama_m * 1000)) AS petroleo_por_km_m3
FROM vm.pozo_analisis
WHERE diseno_confiable
  AND anio_arranque >= 2021
GROUP BY 1
HAVING count(*) >= 10
ORDER BY 1;

-- 2d. La misma relación dentro de cada área, para descontar el efecto del
--     lugar. La correlación va de -1 a 1; cerca de 0 significa que no hay relación.
SELECT area,
       count(*)                                                            AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY rama_m))          AS rama_m,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3)) AS petroleo_12m_m3,
       round(corr(petroleo_12m_m3, rama_m)::numeric, 2)                    AS correlacion_con_rama,
       round(corr(petroleo_12m_m3, arena_tn)::numeric, 2)                  AS correlacion_con_arena
FROM vm.pozo_analisis
WHERE diseno_confiable
  AND anio_arranque >= 2021
GROUP BY area
HAVING count(*) >= 40
ORDER BY pozos DESC;
