-- Pregunta 4: ¿cuánto de toda la producción sale de unas pocas áreas y unos
-- pocos pozos?
-- Población: todos los pozos de Vaca Muerta (no solo los horizontales petrolíferos).

-- 4a. Áreas ordenadas por petróleo acumulado desde 2006, con el porcentaje de
--     cada una y el porcentaje acumulado.
WITH por_area AS (
    SELECT a.nombre                  AS area,
           count(DISTINCT m.pozo_id) AS pozos,
           sum(m.petroleo_m3)        AS petroleo_m3
    FROM vm.produccion_mensual m
    JOIN vm.pozo p USING (pozo_id)
    JOIN vm.area a USING (area_id)
    GROUP BY a.nombre
)
SELECT row_number() OVER (ORDER BY petroleo_m3 DESC)                                            AS puesto,
       area,
       pozos,
       round(petroleo_m3 / 1e6, 2)                                                              AS petroleo_millones_m3,
       round(100 * petroleo_m3 / sum(petroleo_m3) OVER (), 1)                                   AS porcentaje,
       round(100 * sum(petroleo_m3) OVER (ORDER BY petroleo_m3 DESC) / sum(petroleo_m3) OVER (), 1) AS porcentaje_acumulado
FROM por_area
ORDER BY petroleo_m3 DESC
LIMIT 12;

-- 4b. Lo mismo para los últimos 12 meses con datos.
WITH por_area AS (
    SELECT a.nombre           AS area,
           sum(m.petroleo_m3) AS petroleo_m3
    FROM vm.produccion_mensual m
    JOIN vm.pozo p USING (pozo_id)
    JOIN vm.area a USING (area_id)
    WHERE m.mes > (SELECT max(mes) FROM vm.produccion_mensual) - INTERVAL '12 months'
    GROUP BY a.nombre
)
SELECT row_number() OVER (ORDER BY petroleo_m3 DESC)                                            AS puesto,
       area,
       round(petroleo_m3 / 1e6, 2)                                                              AS petroleo_millones_m3,
       round(100 * petroleo_m3 / sum(petroleo_m3) OVER (), 1)                                   AS porcentaje,
       round(100 * sum(petroleo_m3) OVER (ORDER BY petroleo_m3 DESC) / sum(petroleo_m3) OVER (), 1) AS porcentaje_acumulado
FROM por_area
ORDER BY petroleo_m3 DESC
LIMIT 12;

-- 4c. Pozos repartidos en diez grupos iguales según su petróleo acumulado
--     (grupo 1 = el 10 % que más produjo).
WITH por_pozo AS (
    SELECT pozo_id, sum(petroleo_m3) AS petroleo_m3
    FROM vm.produccion_mensual
    GROUP BY pozo_id
    HAVING sum(petroleo_m3) > 0
),
en_grupos AS (
    SELECT ntile(10) OVER (ORDER BY petroleo_m3 DESC) AS grupo,
           petroleo_m3
    FROM por_pozo
)
SELECT grupo,
       count(*)                                                                         AS pozos,
       round(100 * sum(petroleo_m3) / sum(sum(petroleo_m3)) OVER (), 1)                 AS porcentaje,
       round(100 * sum(sum(petroleo_m3)) OVER (ORDER BY grupo) / sum(sum(petroleo_m3)) OVER (), 1) AS porcentaje_acumulado
FROM en_grupos
GROUP BY grupo
ORDER BY grupo;
