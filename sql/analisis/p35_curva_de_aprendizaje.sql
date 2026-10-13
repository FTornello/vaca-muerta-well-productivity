-- Pregunta 35: ¿las operadoras que llegaron tarde tuvieron que aprender de cero?
-- Ordeno los pozos de cada operadora por fecha de arranque y comparo sus
-- primeros 10 con los que vinieron después. Mido petróleo del primer año por
-- kilómetro de rama, para no premiar al que perforó más largo.
-- Solo operadoras con 30 pozos o más con diseño confiable.

-- 35a. Los primeros 10 pozos de cada operadora contra los siguientes.
WITH ordenados AS (
    SELECT operadora, anio_arranque,
           petroleo_12m_m3 / nullif(rama_m, 0) * 1000                                   AS m3_por_km,
           row_number() OVER (PARTITION BY operadora ORDER BY anio_arranque, pozo_id)  AS orden,
           count(*)     OVER (PARTITION BY operadora)                                  AS total
    FROM vm.pozo_analisis
    WHERE diseno_confiable AND petroleo_12m_m3 IS NOT NULL
)
SELECT operadora,
       min(anio_arranque)                                                                            AS primer_anio,
       max(total)                                                                                    AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY m3_por_km) FILTER (WHERE orden <= 10)::numeric)          AS primeros_10,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY m3_por_km) FILTER (WHERE orden BETWEEN 11 AND 30)::numeric) AS del_11_al_30,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY m3_por_km) FILTER (WHERE orden > 30)::numeric)           AS del_31_en_adelante
FROM ordenados
GROUP BY 1
HAVING max(total) >= 30
ORDER BY 2, 1;

-- 35b. Lo mismo mirado al revés: qué rendía el pozo típico de TODA la industria
--      el año en que cada operadora arrancó. Si los primeros pozos de una
--      recién llegada se parecen a ese número, es que arrancó en la frontera.
WITH tipico AS (
    SELECT anio_arranque,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3 / nullif(rama_m, 0) * 1000) AS m3_por_km
    FROM vm.pozo_analisis
    WHERE diseno_confiable AND petroleo_12m_m3 IS NOT NULL
    GROUP BY 1
),
primeros AS (
    SELECT operadora, min(anio_arranque) AS primer_anio,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY m3_por_km) AS m3_por_km
    FROM (
        SELECT operadora, anio_arranque, petroleo_12m_m3 / nullif(rama_m, 0) * 1000 AS m3_por_km,
               row_number() OVER (PARTITION BY operadora ORDER BY anio_arranque, pozo_id) AS orden,
               count(*)     OVER (PARTITION BY operadora)                                 AS total
        FROM vm.pozo_analisis
        WHERE diseno_confiable AND petroleo_12m_m3 IS NOT NULL
    ) o
    WHERE orden <= 10 AND total >= 30
    GROUP BY 1
)
SELECT p.operadora, p.primer_anio,
       round(p.m3_por_km::numeric)                    AS sus_primeros_10,
       round(t.m3_por_km::numeric)                    AS la_industria_ese_anio,
       round(100 * (p.m3_por_km / t.m3_por_km - 1))   AS diferencia_pct
FROM primeros p
JOIN tipico t ON t.anio_arranque = p.primer_anio
ORDER BY 2, 1;
