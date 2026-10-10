-- Capa explicativa: ¿por qué cae el petróleo por kilómetro de rama desde 2021?
-- Cada consulta pone a prueba una explicación que da el sector.
-- Población: pozos de vm.pozo_analisis con diseño confiable.
-- "Áreas históricas" = las cuatro que concentran la producción: Loma Campana,
-- La Amarga Chica, Bandurria Sur y Bajada del Palo Oeste.

-- 6a. Explicación "se perfora en zonas menos buenas": qué parte de los pozos
--     nuevos va a las áreas históricas, y cuánto rinde cada grupo por año.
SELECT anio_arranque,
       area IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR', 'BAJADA DEL PALO OESTE') AS area_historica,
       count(*)                                                                               AS pozos,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_arranque))              AS pct_de_los_pozos_del_anio,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / rama_m * 1000))    AS petroleo_por_km_m3
FROM vm.pozo_analisis
WHERE diseno_confiable
  AND anio_arranque >= 2021
GROUP BY anio_arranque, area_historica
ORDER BY area_historica DESC, anio_arranque;

-- 6b. La misma comparación área por área: 2021-2022 contra 2024-2025.
SELECT area,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY rama_m)
             FILTER (WHERE anio_arranque IN (2021, 2022)))                       AS rama_m_antes,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY rama_m)
             FILTER (WHERE anio_arranque IN (2024, 2025)))                       AS rama_m_despues,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / rama_m * 1000)
             FILTER (WHERE anio_arranque IN (2021, 2022)))                       AS por_km_antes,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / rama_m * 1000)
             FILTER (WHERE anio_arranque IN (2024, 2025)))                       AS por_km_despues
FROM vm.pozo_analisis
WHERE diseno_confiable
GROUP BY area
HAVING count(*) FILTER (WHERE anio_arranque IN (2021, 2022)) >= 10
   AND count(*) FILTER (WHERE anio_arranque IN (2024, 2025)) >= 10
ORDER BY por_km_antes DESC;

-- 6c. Explicación "los pozos nuevos compiten con los vecinos": para cada pozo
--     cuenta cuántos pozos al menos un año más viejos hay a menos de 1,5 km de
--     su boca, y compara el rendimiento según esa cantidad.
--     Límite: usa la ubicación de la boca del pozo, no el recorrido de la rama.
WITH vecinos AS (
    SELECT a.pozo_id,
           a.petroleo_12m_m3 / a.rama_m * 1000 AS petroleo_por_km_m3,
           (SELECT count(*)
            FROM vm.pozo q
            WHERE q.pozo_id <> p.pozo_id
              AND q.primer_mes_produccion < p.primer_mes_produccion - INTERVAL '12 months'
              AND sqrt(power((q.latitud - p.latitud) * 110.57, 2)
                     + power((q.longitud - p.longitud) * 111.32 * cos(radians(p.latitud)), 2)) <= 1.5
           ) AS pozos_previos_cerca
    FROM vm.pozo_analisis a
    JOIN vm.pozo p USING (pozo_id)
    WHERE a.diseno_confiable
      AND a.anio_arranque >= 2021
)
SELECT CASE WHEN pozos_previos_cerca = 0   THEN '0'
            WHEN pozos_previos_cerca <= 5  THEN '1 a 5'
            WHEN pozos_previos_cerca <= 15 THEN '6 a 15'
            ELSE '16 o más' END                                             AS pozos_previos_cerca,
       count(*)                                                             AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_por_km_m3)) AS petroleo_por_km_m3
FROM vecinos
GROUP BY 1
ORDER BY min(pozos_previos_cerca);

-- 6d. Explicación "12 meses es poco para un pozo largo": lo mismo a 24 meses,
--     más el mes de mayor producción y cuánto rinde el segundo año respecto
--     del primero. Solo pozos que ya cumplieron 24 meses.
WITH dos_anios AS (
    SELECT a.pozo_id,
           a.anio_arranque,
           a.rama_m,
           sum(e.petroleo_m3) FILTER (WHERE e.mes_de_vida <= 12)             AS primer_anio,
           sum(e.petroleo_m3) FILTER (WHERE e.mes_de_vida BETWEEN 13 AND 24) AS segundo_anio,
           max(e.petroleo_m3) FILTER (WHERE e.mes_de_vida <= 12)             AS mejor_mes
    FROM vm.pozo_analisis a
    JOIN vm.pozo p USING (pozo_id)
    JOIN vm.produccion_edad e USING (pozo_id)
    WHERE a.diseno_confiable
      AND a.anio_arranque >= 2019
      AND p.primer_mes_produccion <= (SELECT max(mes) FROM vm.produccion_mensual) - INTERVAL '23 months'
      AND e.mes_de_vida <= 24
    GROUP BY a.pozo_id, a.anio_arranque, a.rama_m
)
SELECT anio_arranque,
       count(*)                                                                                      AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY rama_m))                                    AS rama_m,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY mejor_mes))                                 AS mejor_mes_m3,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY primer_anio / rama_m * 1000))               AS por_km_12_meses,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY (primer_anio + segundo_anio) / rama_m * 1000)) AS por_km_24_meses,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY segundo_anio / nullif(primer_anio, 0))::numeric, 2) AS segundo_anio_sobre_primero
FROM dos_anios
GROUP BY anio_arranque
ORDER BY anio_arranque;
