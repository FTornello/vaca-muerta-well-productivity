-- Pregunta 27: ¿cuánto pesa Vaca Muerta en el petróleo y el gas del país?
-- vm.pais_energia tiene la producción de todo el país y el crudo que procesan
-- las refinerías. Restando Vaca Muerta queda "el resto": el convencional y los
-- otros no convencionales. Miles de barriles por día = miles de m3 * 6,2898 / días.

-- 27a. Petróleo: Vaca Muerta, el resto, y lo que procesan las refinerías.
--      Lo que el país produce por encima de lo que refina es lo que tiene que
--      exportar. La última columna lo compara con lo embarcado (pregunta 14).
WITH vaca AS (
    SELECT mes, sum(petroleo_m3) / 1000 AS km3 FROM vm.produccion_mensual GROUP BY mes
),
expo AS (
    SELECT mes, sum(volumen_m3) / 1000 AS km3 FROM vm.exportacion GROUP BY mes
),
m AS (
    SELECT p.mes, p.petroleo_producido_km3 AS pais, p.petroleo_procesado_km3 AS procesado,
           coalesce(v.km3, 0) AS vaca, coalesce(e.km3, 0) AS exportado,
           extract(day FROM p.mes + INTERVAL '1 month' - INTERVAL '1 day') AS dias
    FROM vm.pais_energia p
    LEFT JOIN vaca v USING (mes)
    LEFT JOIN expo e USING (mes)
    WHERE p.petroleo_producido_km3 IS NOT NULL AND p.petroleo_procesado_km3 IS NOT NULL
)
SELECT extract(year FROM mes)::integer                             AS anio,
       count(*)                                                    AS meses,
       round(sum(pais) * 6.2898 / sum(dias))                       AS pais_miles_bbl_dia,
       round(sum(vaca) * 6.2898 / sum(dias))                       AS vaca_muerta,
       round(sum(pais - vaca) * 6.2898 / sum(dias))                AS el_resto,
       round(100 * sum(vaca) / sum(pais))                          AS pct_vaca_muerta,
       round(sum(procesado) * 6.2898 / sum(dias))                  AS procesan_las_refinerias,
       round(sum(pais - procesado) * 6.2898 / sum(dias))           AS sobra_para_exportar,
       round(sum(exportado) * 6.2898 / sum(dias))                  AS embarcado_desde_neuquen
FROM m
GROUP BY 1
ORDER BY 1;

-- 27b. Gas: lo mismo, en millones de m3 por día. 2026 llega hasta junio.
WITH vaca AS (
    SELECT mes, sum(gas_miles_m3) / 1000 AS mm_m3 FROM vm.produccion_mensual GROUP BY mes
)
SELECT extract(year FROM p.mes)::integer                                        AS anio,
       count(*)                                                                 AS meses,
       round(sum(p.gas_producido_mm_m3) / sum(d.dias), 1)                       AS pais_mm_m3_dia,
       round(sum(coalesce(v.mm_m3, 0)) / sum(d.dias), 1)                        AS vaca_muerta,
       round(sum(p.gas_producido_mm_m3 - coalesce(v.mm_m3, 0)) / sum(d.dias), 1) AS el_resto,
       round(100 * sum(coalesce(v.mm_m3, 0)) / sum(p.gas_producido_mm_m3))      AS pct_vaca_muerta
FROM vm.pais_energia p
LEFT JOIN vaca v USING (mes)
CROSS JOIN LATERAL (SELECT extract(day FROM p.mes + INTERVAL '1 month' - INTERVAL '1 day') AS dias) d
WHERE p.gas_producido_mm_m3 IS NOT NULL
GROUP BY 1
ORDER BY 1;
