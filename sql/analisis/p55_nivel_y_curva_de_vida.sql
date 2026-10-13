-- Pregunta 55: los pozos del nivel profundo arrancan mejor. ¿También caen distinto?
-- La pregunta 7 mostró que, en el mismo lugar, los pozos que navegan en U1 (el
-- nivel más profundo) rinden más en su primer año que los de U2. Faltaba saber
-- si esa ventaja se mantiene, se agranda o se pierde con el tiempo. Cruzo el
-- nivel de cada pozo (vm.pozo_subsuelo) con su producción mes a mes
-- (vm.produccion_edad).
--
-- Pozos de las áreas históricas que arrancaron entre 2018 y 2021 y ya tienen
-- cuatro años de producción. Miro dos cosas: cuánto dan por kilómetro, y la
-- FORMA de la curva, que es el acumulado a cada edad dividido por lo del primer
-- año (como en la pregunta 22).

-- 55a. Por nivel.
WITH pozos AS (
    SELECT s.nivel, e.pozo_id, max(s.rama_m) AS rama_m, max(e.mes_de_vida) AS edad,
           sum(e.petroleo_m3) FILTER (WHERE e.mes_de_vida <= 12) AS a_12,
           sum(e.petroleo_m3) FILTER (WHERE e.mes_de_vida <= 24) AS a_24,
           sum(e.petroleo_m3) FILTER (WHERE e.mes_de_vida <= 36) AS a_36,
           sum(e.petroleo_m3) FILTER (WHERE e.mes_de_vida <= 48) AS a_48
    FROM vm.pozo_subsuelo s
    JOIN vm.produccion_edad e USING (pozo_id)
    WHERE s.area_historica AND s.anio_arranque BETWEEN 2018 AND 2021 AND s.nivel IS NOT NULL
    GROUP BY 1, 2
)
SELECT nivel,
       count(*)                                   AS pozos,
       round(avg(a_12 / rama_m * 1000))           AS m3_por_km_primer_anio,
       round(avg(a_48 / rama_m * 1000))           AS m3_por_km_a_4_anios,
       round((sum(a_24) / sum(a_12))::numeric, 2) AS veces_el_primer_anio_a_los_2,
       round((sum(a_36) / sum(a_12))::numeric, 2) AS a_los_3,
       round((sum(a_48) / sum(a_12))::numeric, 2) AS a_los_4
FROM pozos
WHERE edad >= 48 AND rama_m > 0
GROUP BY 1
HAVING count(*) >= 15
ORDER BY 3 DESC;

-- 55b. Dentro de cada área, para comparar la misma roca vista desde arriba.
WITH pozos AS (
    SELECT s.area, s.nivel, e.pozo_id, max(s.rama_m) AS rama_m, max(e.mes_de_vida) AS edad,
           sum(e.petroleo_m3) FILTER (WHERE e.mes_de_vida <= 12) AS a_12,
           sum(e.petroleo_m3) FILTER (WHERE e.mes_de_vida <= 48) AS a_48
    FROM vm.pozo_subsuelo s
    JOIN vm.produccion_edad e USING (pozo_id)
    WHERE s.area_historica AND s.anio_arranque BETWEEN 2018 AND 2021 AND s.nivel IS NOT NULL
    GROUP BY 1, 2, 3
)
SELECT area, nivel,
       count(*)                                   AS pozos,
       round(avg(a_12 / rama_m * 1000))           AS m3_por_km_primer_anio,
       round(avg(a_48 / rama_m * 1000))           AS m3_por_km_a_4_anios,
       round((sum(a_48) / sum(a_12))::numeric, 2) AS veces_el_primer_anio_a_los_4
FROM pozos
WHERE edad >= 48 AND rama_m > 0
GROUP BY 1, 2
HAVING count(*) >= 10
ORDER BY 1, 4 DESC;
