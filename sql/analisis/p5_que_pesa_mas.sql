-- Síntesis: ¿qué pesa más, el diseño, la operadora o el lugar?
-- Mide qué parte de las diferencias de producción entre pozos acompaña a cada
-- factor. 0 % = el factor no distingue nada; 100 % = lo explica todo.
-- Población: pozos desde 2021 con diseño confiable.

-- 5a. Factores de grupo (lugar, operadora, año). Compara cuánto se alejan los
--     pozos del promedio general contra cuánto se alejan del promedio de su grupo.
WITH d AS (
    SELECT petroleo_12m_m3                                     AS pet,
           avg(petroleo_12m_m3) OVER ()                        AS prom_general,
           avg(petroleo_12m_m3) OVER (PARTITION BY area)       AS prom_area,
           avg(petroleo_12m_m3) OVER (PARTITION BY operadora)  AS prom_operadora,
           avg(petroleo_12m_m3) OVER (PARTITION BY anio_arranque) AS prom_anio
    FROM vm.pozo_analisis
    WHERE diseno_confiable
      AND anio_arranque >= 2021
)
SELECT count(*)                                                                               AS pozos,
       round(100 * (1 - sum((pet - prom_area) ^ 2)      / sum((pet - prom_general) ^ 2))::numeric, 1) AS pct_lugar,
       round(100 * (1 - sum((pet - prom_operadora) ^ 2) / sum((pet - prom_general) ^ 2))::numeric, 1) AS pct_operadora,
       round(100 * (1 - sum((pet - prom_anio) ^ 2)      / sum((pet - prom_general) ^ 2))::numeric, 1) AS pct_anio
FROM d;

-- 5b. Factores de diseño por sí solos (correlación al cuadrado).
SELECT round(100 * (corr(petroleo_12m_m3, rama_m) ^ 2)::numeric, 1)   AS pct_rama,
       round(100 * (corr(petroleo_12m_m3, etapas) ^ 2)::numeric, 1)   AS pct_etapas,
       round(100 * (corr(petroleo_12m_m3, arena_tn) ^ 2)::numeric, 1) AS pct_arena
FROM vm.pozo_analisis
WHERE diseno_confiable
  AND anio_arranque >= 2021;

-- 5c. Diseño una vez descontado el lugar: a cada pozo se le resta el promedio
--     de su área, y se mide la relación entre lo que queda.
WITH d AS (
    SELECT petroleo_12m_m3 - avg(petroleo_12m_m3) OVER (PARTITION BY area) AS pet,
           rama_m          - avg(rama_m)          OVER (PARTITION BY area) AS rama,
           arena_tn        - avg(arena_tn)        OVER (PARTITION BY area) AS arena
    FROM vm.pozo_analisis
    WHERE diseno_confiable
      AND anio_arranque >= 2021
)
SELECT round(100 * (corr(pet, rama) ^ 2)::numeric, 1)   AS pct_rama_dentro_del_area,
       round(100 * (corr(pet, arena) ^ 2)::numeric, 1)  AS pct_arena_dentro_del_area,
       round(regr_slope(pet, rama)::numeric, 1)         AS m3_por_metro_extra_de_rama,
       round(regr_slope(pet, arena)::numeric, 2)        AS m3_por_tonelada_extra_de_arena
FROM d;
