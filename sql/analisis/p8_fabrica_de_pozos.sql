-- Pregunta 8: ¿cuánto creció y cuánto se aceleró la "fábrica" de pozos?
-- Fuente: vm.fractura (todas las operaciones de fractura en Vaca Muerta) y las
-- fechas de perforación y terminación de vm.pozo.
-- La fuente tiene unos tres meses de demora: los últimos meses están incompletos.

-- 8a. Actividad por año: pozos fracturados, etapas, arena y agua.
SELECT extract(year FROM fecha_inicio)::integer                                   AS anio,
       count(*)                                                                   AS fracturas,
       sum(etapas)                                                                AS etapas,
       round(sum(arena_nacional_tn + arena_importada_tn) / 1000)                  AS arena_miles_tn,
       round(100 * sum(arena_importada_tn) / sum(arena_nacional_tn + arena_importada_tn)) AS pct_arena_importada,
       round(sum(agua_m3) / 1e6, 1)                                               AS agua_millones_m3
FROM vm.fractura
WHERE fecha_inicio >= DATE '2015-01-01'
  AND NOT dato_sospechoso
GROUP BY 1
ORDER BY 1;

-- 8b. Velocidad: etapas por día y días que lleva fracturar un pozo.
--     Pozos horizontales, fractura original.
SELECT extract(year FROM f.fecha_inicio)::integer                                 AS anio,
       count(*)                                                                   AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY f.etapas))               AS etapas_por_pozo,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY f.fecha_fin - f.fecha_inicio + 1)) AS dias_por_pozo,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY f.etapas::numeric / (f.fecha_fin - f.fecha_inicio + 1))::numeric, 1) AS etapas_por_dia
FROM vm.fractura f
JOIN vm.pozo p USING (pozo_id)
WHERE p.es_horizontal
  AND f.nro_fractura = 1
  AND NOT f.dato_sospechoso
  AND f.fecha_inicio >= DATE '2017-01-01'
GROUP BY 1
ORDER BY 1;

-- 8c. La misma velocidad por operadora, pozos fracturados desde 2024 (mínimo 20).
SELECT o.nombre                                                                   AS operadora,
       count(*)                                                                   AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY f.etapas))               AS etapas_por_pozo,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY f.fecha_fin - f.fecha_inicio + 1)) AS dias_por_pozo,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY f.etapas::numeric / (f.fecha_fin - f.fecha_inicio + 1))::numeric, 1) AS etapas_por_dia
FROM vm.fractura f
JOIN vm.pozo p USING (pozo_id)
JOIN vm.empresa e ON e.empresa_codigo = p.empresa_inicial
JOIN vm.operadora o USING (operadora_id)
WHERE p.es_horizontal
  AND f.nro_fractura = 1
  AND NOT f.dato_sospechoso
  AND f.fecha_inicio >= DATE '2024-01-01'
GROUP BY o.nombre
HAVING count(*) >= 20
ORDER BY etapas_por_dia DESC;

-- 8d. El ciclo completo de un pozo, en días (medianas), según el año en que
--     empezó a producir. El total va desde el inicio de la perforación hasta
--     mediados del primer mes con producción, porque la producción se informa
--     por mes y no por día.
SELECT extract(year FROM p.primer_mes_produccion)::integer                                          AS anio,
       count(*)                                                                                      AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY f.fecha_inicio - p.fecha_fin_perforacion))  AS espera_entre_perforar_y_fracturar,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY f.fecha_fin - f.fecha_inicio + 1))          AS fractura,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY p.fecha_fin_terminacion - f.fecha_fin))     AS de_fractura_a_pozo_terminado,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY (p.primer_mes_produccion + 14) - p.fecha_inicio_perforacion)) AS total_de_perforar_a_producir
FROM vm.pozo p
JOIN vm.fractura f ON f.pozo_id = p.pozo_id AND f.nro_fractura = 1
WHERE p.es_horizontal
  AND p.primer_mes_produccion >= DATE '2017-01-01'
  AND p.fecha_inicio_perforacion IS NOT NULL
  AND NOT f.dato_sospechoso
GROUP BY 1
ORDER BY 1;
