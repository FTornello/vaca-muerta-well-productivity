-- Pregunta 47: ¿cuándo deja un pozo de fluir solo?
-- Un pozo nuevo saca el petróleo con la presión de la roca: es la "surgencia
-- natural". Cuando la presión baja hay que ayudarlo con una bomba o inyectando
-- gas (bombeo mecánico, gas lift, plunger lift). Eso cuesta plata y energía.
-- La fuente dice, mes a mes, con qué sistema produce cada pozo
-- (vm.produccion_mensual.tipo_extraccion). Solo pozos petrolíferos.

-- 47a. Con qué sistema producen los pozos según su edad.
SELECT CASE WHEN e.mes_de_vida <= 6  THEN '1. hasta 6 meses'
            WHEN e.mes_de_vida <= 12 THEN '2. de 7 a 12 meses'
            WHEN e.mes_de_vida <= 24 THEN '3. de 1 a 2 años'
            WHEN e.mes_de_vida <= 48 THEN '4. de 2 a 4 años'
            WHEN e.mes_de_vida <= 84 THEN '5. de 4 a 7 años'
            ELSE '6. más de 7 años' END                                                          AS edad,
       count(*)                                                                                  AS meses_pozo,
       round(100.0 * count(*) FILTER (WHERE pm.tipo_extraccion = 'Surgencia Natural') / count(*)) AS pct_fluye_solo,
       round(100.0 * count(*) FILTER (WHERE pm.tipo_extraccion = 'Bombeo Mecánico') / count(*))   AS pct_bombeo_mecanico,
       round(100.0 * count(*) FILTER (WHERE pm.tipo_extraccion = 'Gas Lift') / count(*))          AS pct_gas_lift,
       round(100.0 * count(*) FILTER (WHERE pm.tipo_extraccion = 'Plunger Lift') / count(*))      AS pct_plunger_lift
FROM vm.produccion_edad e
JOIN vm.pozo_analisis a USING (pozo_id)
JOIN vm.produccion_mensual pm ON pm.pozo_id = e.pozo_id AND pm.mes = e.mes
WHERE e.petroleo_m3 > 0
GROUP BY 1
ORDER BY 1;

-- 47b. A qué edad le ponen el primer sistema de extracción, por año de
--      arranque. Mediana entre los pozos que ya lo tienen: en los años
--      recientes faltan los que todavía fluyen solos, así que el número está
--      tirado hacia abajo. Por eso corto en 2022.
WITH primero AS (
    SELECT e.pozo_id, min(e.mes_de_vida) AS mes
    FROM vm.produccion_edad e
    JOIN vm.produccion_mensual pm ON pm.pozo_id = e.pozo_id AND pm.mes = e.mes
    WHERE e.petroleo_m3 > 0
      AND pm.tipo_extraccion NOT IN ('Surgencia Natural', 'Sin Sistema de Extracción', '')
    GROUP BY 1
)
SELECT a.anio_arranque,
       count(*)                                                                AS pozos,
       round(100.0 * count(p.mes) / count(*))                                  AS pct_que_ya_tiene_sistema,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY p.mes)::numeric)      AS mediana_meses_hasta_el_primero
FROM vm.pozo_analisis a
LEFT JOIN primero p USING (pozo_id)
WHERE a.anio_arranque BETWEEN 2016 AND 2022
GROUP BY 1
ORDER BY 1;

-- 47c. La misma edad, distintas generaciones: qué parte de los pozos seguía
--      fluyendo sola entre los 25 y los 36 meses. Acá no hay sesgo, porque
--      todos los pozos comparados ya pasaron por esa edad.
SELECT a.anio_arranque,
       count(DISTINCT e.pozo_id)                                                                  AS pozos,
       round(100.0 * count(*) FILTER (WHERE pm.tipo_extraccion = 'Surgencia Natural') / count(*)) AS pct_fluye_solo_al_tercer_anio
FROM vm.produccion_edad e
JOIN vm.pozo_analisis a USING (pozo_id)
JOIN vm.produccion_mensual pm ON pm.pozo_id = e.pozo_id AND pm.mes = e.mes
WHERE e.mes_de_vida BETWEEN 25 AND 36 AND e.petroleo_m3 > 0
  AND a.anio_arranque BETWEEN 2016 AND 2023
GROUP BY 1
ORDER BY 1;
