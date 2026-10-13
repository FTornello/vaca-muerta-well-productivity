-- Pregunta 39: ¿hay pozos cuya curva no tiene sentido, y cambian los resultados?
-- En la pregunta 38 el mejor pozo de la lista resultó ser un dato raro. Acá lo
-- miro de cerca y me pregunto cuántos más hay así y si mueven las conclusiones.
--
-- La idea: un pozo de shale llega a su máximo en los primeros meses y después
-- baja (pregunta 1). Un pozo cuyo mejor mes es el décimo o más tarde es raro.
-- No siempre es un error: puede haber estado cerrado o restringido al
-- principio. Pero es una señal para mirar.

-- 39a. El caso que disparó la pregunta: dos pozos gemelos de Vista, que
--      arrancaron el mismo mes en la misma locación. m3 de petróleo por mes.
SELECT to_char(pm.mes, 'YYYY-MM')                                               AS mes,
       round(max(pm.petroleo_m3) FILTER (WHERE po.sigla = 'VIS.Nq.BPO-2801(h)')) AS bpo_2801,
       round(max(pm.petroleo_m3) FILTER (WHERE po.sigla = 'VIS.Nq.BPO-2802(h)')) AS bpo_2802
FROM vm.produccion_mensual pm
JOIN vm.pozo po USING (pozo_id)
WHERE po.sigla IN ('VIS.Nq.BPO-2801(h)', 'VIS.Nq.BPO-2802(h)')
  AND pm.mes BETWEEN DATE '2024-02-01' AND DATE '2025-08-01'
GROUP BY 1
ORDER BY 1;

-- 39b. En qué mes de vida tiene su máximo cada pozo (pozos con 18 meses o más).
WITH pico AS (
    SELECT DISTINCT ON (e.pozo_id) e.pozo_id, e.mes_de_vida AS mes_pico
    FROM vm.produccion_edad e
    JOIN vm.pozo_analisis a USING (pozo_id)
    WHERE e.mes_de_vida <= 24
      AND (SELECT count(*) FROM vm.produccion_edad e2 WHERE e2.pozo_id = e.pozo_id AND e2.mes_de_vida <= 24) >= 18
    ORDER BY e.pozo_id, e.petroleo_m3 DESC, e.mes_de_vida
)
SELECT CASE WHEN mes_pico <= 3 THEN '1. meses 1 a 3'
            WHEN mes_pico <= 6 THEN '2. meses 4 a 6'
            WHEN mes_pico <= 9 THEN '3. meses 7 a 9'
            ELSE '4. mes 10 o después' END              AS maximo_en,
       count(*)                                         AS pozos,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM pico
GROUP BY 1
ORDER BY 1;

-- 39c. La prueba que importa: los números principales del proyecto, con todos
--      los pozos y sacando los de máximo tardío. Si las conclusiones dependen
--      de esos pozos, las dos columnas tienen que diferir.
WITH pico AS (
    SELECT DISTINCT ON (e.pozo_id) e.pozo_id, e.mes_de_vida AS mes_pico
    FROM vm.produccion_edad e
    WHERE e.mes_de_vida <= 24
    ORDER BY e.pozo_id, e.petroleo_m3 DESC, e.mes_de_vida
)
SELECT a.anio_arranque,
       count(*)                                                                           AS pozos,
       count(*) FILTER (WHERE p.mes_pico >= 10)                                           AS con_maximo_tardio,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY a.petroleo_12m_m3))              AS mediana_con_todos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY a.petroleo_12m_m3)
             FILTER (WHERE p.mes_pico < 10))                                              AS mediana_sin_los_raros,
       round(avg(a.petroleo_12m_m3))                                                      AS promedio_con_todos,
       round(avg(a.petroleo_12m_m3) FILTER (WHERE p.mes_pico < 10))                       AS promedio_sin_los_raros
FROM vm.pozo_analisis a
JOIN pico p USING (pozo_id)
WHERE a.petroleo_12m_m3 IS NOT NULL AND a.diseno_confiable AND a.anio_arranque BETWEEN 2016 AND 2025
GROUP BY 1
ORDER BY 1;
