-- Pregunta 3: ¿qué operadora saca más por pozo en su primer año, y cuánto
-- mejoró cada una?
-- La operadora de un pozo es la que lo informaba cuando empezó a producir.

-- 3a. Ranking de operadoras con pozos desde 2021 (mínimo 15 pozos).
SELECT operadora,
       count(*)                                                            AS pozos,
       count(DISTINCT area)                                                AS areas,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3)) AS petroleo_12m_m3,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY rama_m)
             FILTER (WHERE diseno_confiable))                              AS rama_m,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / rama_m * 1000)
             FILTER (WHERE diseno_confiable))                              AS petroleo_por_km_m3
FROM vm.pozo_analisis
WHERE anio_arranque >= 2021
GROUP BY operadora
HAVING count(*) >= 15
ORDER BY petroleo_12m_m3 DESC;

-- 3b. Evolución de cada operadora año a año (mínimo 10 pozos en el año):
--     diferencia contra su año anterior y puesto entre las operadoras de ese año.
WITH por_anio AS (
    SELECT operadora,
           anio_arranque,
           count(*)                                                            AS pozos,
           round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3)) AS petroleo_12m_m3
    FROM vm.pozo_analisis
    WHERE anio_arranque >= 2018
    GROUP BY operadora, anio_arranque
    HAVING count(*) >= 10
)
SELECT operadora,
       anio_arranque,
       pozos,
       petroleo_12m_m3,
       petroleo_12m_m3 - lag(petroleo_12m_m3) OVER (PARTITION BY operadora ORDER BY anio_arranque) AS cambio_vs_anio_previo,
       rank() OVER (PARTITION BY anio_arranque ORDER BY petroleo_12m_m3 DESC)                      AS puesto_en_el_anio
FROM por_anio
ORDER BY operadora, anio_arranque;

-- 3c. ¿Se puede separar a la operadora del lugar? Cuántas áreas tienen pozos
--     de más de una operadora.
SELECT count(*)                                AS areas,
       count(*) FILTER (WHERE operadoras > 1)  AS areas_con_mas_de_una_operadora
FROM (
    SELECT area, count(DISTINCT operadora) AS operadoras
    FROM vm.pozo_analisis
    WHERE anio_arranque >= 2021
    GROUP BY area
) t;

-- 3d. La misma operadora en distintos lugares: YPF, área por área (mínimo 15 pozos).
SELECT area,
       count(*)                                                            AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3)) AS petroleo_12m_m3,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY rama_m)
             FILTER (WHERE diseno_confiable))                              AS rama_m
FROM vm.pozo_analisis
WHERE operadora = 'YPF'
  AND anio_arranque >= 2021
GROUP BY area
HAVING count(*) >= 15
ORDER BY petroleo_12m_m3 DESC;
