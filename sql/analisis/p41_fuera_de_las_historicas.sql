-- Pregunta 41: ¿Vaca Muerta se está saliendo de sus cuatro áreas, y rinde igual afuera?
-- Las cuatro áreas históricas (Loma Campana, La Amarga Chica, Bandurria Sur y
-- Bajada del Palo Oeste) dieron el 62 % del petróleo (pregunta 4). Acá miro
-- dónde se perforan los pozos nuevos y si los de afuera rinden lo mismo.

-- 41a. Dónde arrancan los pozos petrolíferos nuevos de cada año.
SELECT extract(year FROM p.primer_mes_produccion)::integer                       AS anio,
       count(*)                                                                  AS pozos_nuevos,
       count(DISTINCT p.area_id)                                                 AS areas_con_pozos_nuevos,
       round(100.0 * count(*) FILTER (WHERE a.nombre IN ('LOMA CAMPANA', 'LA AMARGA CHICA',
             'BANDURRIA SUR', 'BAJADA DEL PALO OESTE')) / count(*))              AS pct_en_las_historicas,
       round((stddev(p.latitud) * 111)::numeric)                                 AS dispersion_norte_sur_km
FROM vm.pozo p
JOIN vm.area a USING (area_id)
WHERE p.primer_mes_produccion >= DATE '2014-01-01'
  AND p.tipo_pozo = 'Petrolífero' AND p.latitud IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- 41b. Lo que rinden adentro y afuera, por año de arranque: petróleo del
--      primer año por pozo y por kilómetro de rama (medianas).
WITH pozos AS (
    SELECT *, area IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR', 'BAJADA DEL PALO OESTE') AS historica
    FROM vm.pozo_analisis
    WHERE petroleo_12m_m3 IS NOT NULL AND diseno_confiable
)
SELECT anio_arranque,
       count(*) FILTER (WHERE historica)                                          AS pozos_historicas,
       count(*) FILTER (WHERE NOT historica)                                      AS pozos_resto,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / nullif(rama_m, 0) * 1000)
             FILTER (WHERE historica))                                            AS m3_por_km_historicas,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / nullif(rama_m, 0) * 1000)
             FILTER (WHERE NOT historica))                                        AS m3_por_km_resto,
       round(100 * (percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / nullif(rama_m, 0) * 1000)
                        FILTER (WHERE NOT historica)
                  / percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / nullif(rama_m, 0) * 1000)
                        FILTER (WHERE historica) - 1))                            AS diferencia_pct
FROM pozos
WHERE anio_arranque >= 2017
GROUP BY 1
ORDER BY 1;

-- 41c. Las áreas de afuera con más pozos desde 2023, y cómo rinden.
SELECT area, operadora,
       count(*)                                                                               AS pozos_desde_2023,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3))                    AS petroleo_primer_anio,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / nullif(rama_m, 0) * 1000)) AS m3_por_km
FROM vm.pozo_analisis
WHERE petroleo_12m_m3 IS NOT NULL AND diseno_confiable AND anio_arranque >= 2023
  AND area NOT IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR', 'BAJADA DEL PALO OESTE')
GROUP BY 1, 2
HAVING count(*) >= 10
ORDER BY 3 DESC;
