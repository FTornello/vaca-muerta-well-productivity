-- Pregunta 7: ¿el nivel de la roca donde navega la rama y la cercanía a otros
-- pozos explican el rendimiento?
-- Población: vm.pozo_subsuelo desde 2019. La cobertura de trayectorias es de
-- más del 90 % hasta 2023 y cae a 44 % en 2024 y 25 % en 2025.

-- 7a. Mismo lugar, distinto nivel: U1 (Vaca Muerta Inferior) contra U2 (Medio)
--     dentro de cada área que tiene al menos 10 pozos en cada nivel.
SELECT area,
       count(*) FILTER (WHERE unidad = 1)                                                             AS pozos_u1,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_por_km_m3) FILTER (WHERE unidad = 1)) AS por_km_u1,
       count(*) FILTER (WHERE unidad = 2)                                                             AS pozos_u2,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_por_km_m3) FILTER (WHERE unidad = 2)) AS por_km_u2
FROM vm.pozo_subsuelo
WHERE anio_arranque >= 2019
GROUP BY area
HAVING count(*) FILTER (WHERE unidad = 1) >= 10
   AND count(*) FILTER (WHERE unidad = 2) >= 10
ORDER BY pozos_u1 DESC;

-- 7b. Cercanía a un pozo "padre": distancia a la rama más cercana del mismo
--     nivel que ya llevaba al menos 12 meses produciendo. Áreas históricas.
SELECT 'U' || unidad                                                    AS nivel,
       CASE WHEN distancia_previo_mismo_nivel_m IS NULL THEN '4. sin padre a menos de 1.500 m'
            WHEN distancia_previo_mismo_nivel_m < 300   THEN '1. menos de 300 m'
            WHEN distancia_previo_mismo_nivel_m < 500   THEN '2. de 300 a 500 m'
            ELSE                                             '3. de 500 a 1.500 m' END AS distancia_al_padre,
       count(*)                                                         AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_por_km_m3)) AS petroleo_por_km_m3
FROM vm.pozo_subsuelo
WHERE anio_arranque >= 2019
  AND area_historica
GROUP BY 1, 2
ORDER BY 1, 2;

-- 7c. Espaciamiento: distancia a la rama vecina más cercana del mismo nivel,
--     sin importar cuándo se perforó. Áreas históricas.
SELECT CASE WHEN distancia_vecino_mismo_nivel_m IS NULL THEN '5. sin vecino'
            WHEN distancia_vecino_mismo_nivel_m < 200   THEN '1. menos de 200 m'
            WHEN distancia_vecino_mismo_nivel_m < 300   THEN '2. de 200 a 300 m'
            WHEN distancia_vecino_mismo_nivel_m < 400   THEN '3. de 300 a 400 m'
            ELSE                                             '4. 400 m o más' END AS espaciamiento,
       count(*)                                                               AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_por_km_m3)) AS petroleo_por_km_m3
FROM vm.pozo_subsuelo
WHERE anio_arranque >= 2019
  AND area_historica
GROUP BY 1
ORDER BY 1;

-- 7d. Cómo cambió todo esto año a año en las áreas históricas.
SELECT anio_arranque,
       count(*)                                                                                   AS pozos,
       round(100.0 * count(*) FILTER (WHERE unidad = 1) / count(*))                               AS pct_en_u1,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY distancia_vecino_mismo_nivel_m))         AS espaciamiento_m,
       round(100.0 * count(*) FILTER (WHERE distancia_previo_mismo_nivel_m < 500) / count(*))     AS pct_con_padre_a_menos_de_500m,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_por_km_m3) FILTER (WHERE unidad = 1)) AS por_km_u1,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_por_km_m3) FILTER (WHERE unidad = 2)) AS por_km_u2
FROM vm.pozo_subsuelo
WHERE anio_arranque >= 2019
  AND area_historica
GROUP BY anio_arranque
ORDER BY anio_arranque;

-- 7e. Cuánto suma el nivel a lo que ya explicaba el lugar (pozos desde 2021).
WITH d AS (
    SELECT petroleo_12m_m3                                             AS pet,
           avg(petroleo_12m_m3) OVER ()                                AS prom_general,
           avg(petroleo_12m_m3) OVER (PARTITION BY area)               AS prom_area,
           avg(petroleo_12m_m3) OVER (PARTITION BY area, unidad)       AS prom_area_y_nivel
    FROM vm.pozo_subsuelo
    WHERE anio_arranque >= 2021
)
SELECT count(*)                                                                                          AS pozos,
       round(100 * (1 - sum((pet - prom_area) ^ 2)         / sum((pet - prom_general) ^ 2))::numeric, 1) AS pct_lugar,
       round(100 * (1 - sum((pet - prom_area_y_nivel) ^ 2) / sum((pet - prom_general) ^ 2))::numeric, 1) AS pct_lugar_y_nivel
FROM d;

-- 7f. Y cuánto suma la arena una vez descontados el lugar y el nivel.
WITH d AS (
    SELECT petroleo_12m_m3 - avg(petroleo_12m_m3) OVER (PARTITION BY area, unidad) AS pet,
           arena_tn        - avg(arena_tn)        OVER (PARTITION BY area, unidad) AS arena
    FROM vm.pozo_subsuelo
    WHERE anio_arranque >= 2021
)
SELECT round(100 * (corr(pet, arena) ^ 2)::numeric, 1) AS pct_arena_dentro_de_lugar_y_nivel
FROM d;
