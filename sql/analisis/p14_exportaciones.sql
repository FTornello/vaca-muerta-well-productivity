-- Pregunta 14: ¿cuánto del petróleo de Vaca Muerta se exporta, y a dónde va?
-- Fuente: vm.exportacion (barcos desde Puerto Rosales y oleoducto a Chile).
-- Miles de barriles por día; 1 m3 = 6,2898 barriles.
-- Lo exportado es petróleo de toda la cuenca Neuquina, que hoy es casi todo
-- Vaca Muerta; el porcentaje sobre la producción es una aproximación.

-- 14a. Por año: exportación por cada vía y su peso sobre la producción.
WITH expo AS (
    SELECT mes,
           sum(volumen_m3) FILTER (WHERE via = 'barco')     AS barco_m3,
           sum(volumen_m3) FILTER (WHERE via = 'oleoducto') AS oleoducto_m3
    FROM vm.exportacion
    GROUP BY mes
),
prod AS (
    SELECT mes, sum(petroleo_m3) AS petroleo_m3
    FROM vm.produccion_mensual
    GROUP BY mes
)
SELECT extract(year FROM p.mes)::integer                                             AS anio,
       count(*)                                                                      AS meses,
       round(sum(coalesce(e.barco_m3, 0))     * 6.2898 / sum(extract(day FROM p.mes + INTERVAL '1 month - 1 day')) / 1000) AS por_barco,
       round(sum(coalesce(e.oleoducto_m3, 0)) * 6.2898 / sum(extract(day FROM p.mes + INTERVAL '1 month - 1 day')) / 1000) AS por_oleoducto_a_chile,
       round(sum(p.petroleo_m3)               * 6.2898 / sum(extract(day FROM p.mes + INTERVAL '1 month - 1 day')) / 1000) AS produccion_vaca_muerta,
       round(100 * sum(coalesce(e.barco_m3, 0) + coalesce(e.oleoducto_m3, 0)) / sum(p.petroleo_m3)) AS pct_exportado
FROM prod p
LEFT JOIN expo e USING (mes)
WHERE p.mes BETWEEN DATE '2020-01-01' AND (SELECT max(mes) FROM vm.exportacion)
GROUP BY 1
ORDER BY 1;

-- 14b. Destinos: participación de cada país en lo exportado, por año.
WITH por_pais AS (
    SELECT extract(year FROM mes)::integer AS anio, pais, sum(volumen_m3) AS volumen_m3
    FROM vm.exportacion
    WHERE mes >= DATE '2022-01-01'
    GROUP BY 1, 2
)
SELECT pais,
       round(100 * sum(volumen_m3) FILTER (WHERE anio = 2022) / sum(sum(volumen_m3) FILTER (WHERE anio = 2022)) OVER ()) AS pct_2022,
       round(100 * sum(volumen_m3) FILTER (WHERE anio = 2024) / sum(sum(volumen_m3) FILTER (WHERE anio = 2024)) OVER ()) AS pct_2024,
       round(100 * sum(volumen_m3) FILTER (WHERE anio = 2025) / sum(sum(volumen_m3) FILTER (WHERE anio = 2025)) OVER ()) AS pct_2025,
       round(100 * sum(volumen_m3) FILTER (WHERE anio = 2026) / sum(sum(volumen_m3) FILTER (WHERE anio = 2026)) OVER ()) AS pct_2026
FROM por_pais
GROUP BY pais
ORDER BY sum(volumen_m3) FILTER (WHERE anio = 2026) DESC NULLS LAST
LIMIT 14;

-- 14c. Quién exporta: participación de cada empresa cargadora desde 2025.
SELECT cargador,
       round(sum(volumen_m3) / 1e6, 2)                               AS millones_m3,
       round(100 * sum(volumen_m3) / sum(sum(volumen_m3)) OVER (), 1) AS porcentaje
FROM vm.exportacion
WHERE mes >= DATE '2025-01-01'
GROUP BY cargador
ORDER BY sum(volumen_m3) DESC
LIMIT 10;
