-- Pregunta 9: ¿la producción de gas de Vaca Muerta sigue a las estaciones?
-- El gas sale de dos lados: de los pozos gasíferos, y de los petrolíferos, que
-- lo producen junto con el petróleo (gas asociado). Volúmenes en millones de m3
-- por día.

-- 9a. Gas por mes desde 2024, separando las dos fuentes.
SELECT to_char(m.mes, 'YYYY-MM')                                                        AS mes,
       round(sum(m.gas_miles_m3) FILTER (WHERE p.tipo_pozo = 'Gasífero')
             / extract(day FROM m.mes + INTERVAL '1 month - 1 day') / 1000, 1)          AS de_pozos_de_gas,
       round(sum(m.gas_miles_m3) FILTER (WHERE p.tipo_pozo = 'Petrolífero')
             / extract(day FROM m.mes + INTERVAL '1 month - 1 day') / 1000, 1)          AS asociado_al_petroleo
FROM vm.produccion_mensual m
JOIN vm.pozo p USING (pozo_id)
WHERE m.mes >= DATE '2024-01-01'
GROUP BY m.mes
ORDER BY m.mes;

-- 9b. Por año: pico de invierno (julio y agosto) contra valle de primavera
--     (octubre y noviembre) en los pozos de gas, con los días que trabajaron y
--     la parte que no produjo nada.
WITH pozos_de_gas AS (
    SELECT m.*,
           extract(year FROM m.mes)::integer  AS anio,
           extract(month FROM m.mes)::integer AS nro_mes
    FROM vm.produccion_mensual m
    JOIN vm.pozo p USING (pozo_id)
    WHERE p.tipo_pozo = 'Gasífero'
      AND p.es_horizontal
      AND m.mes >= p.primer_mes_produccion
)
SELECT anio,
       round(sum(gas_miles_m3) FILTER (WHERE nro_mes IN (7, 8))   / 62 / 1000, 1)  AS pico_invierno,
       round(sum(gas_miles_m3) FILTER (WHERE nro_mes IN (10, 11)) / 61 / 1000, 1)  AS valle_primavera,
       round(100 * (1 - (sum(gas_miles_m3) FILTER (WHERE nro_mes IN (10, 11)) / 61)
                      / (sum(gas_miles_m3) FILTER (WHERE nro_mes IN (7, 8)) / 62))) AS caida_pct,
       round(avg(dias_activo) FILTER (WHERE nro_mes IN (7, 8)), 1)                 AS dias_activos_invierno,
       round(avg(dias_activo) FILTER (WHERE nro_mes IN (10, 11)), 1)               AS dias_activos_primavera,
       round(100.0 * count(*) FILTER (WHERE nro_mes IN (10, 11) AND coalesce(gas_miles_m3, 0) = 0)
                   / count(*) FILTER (WHERE nro_mes IN (10, 11)))                  AS pct_pozos_parados_primavera
FROM pozos_de_gas
WHERE anio BETWEEN 2018 AND 2025
GROUP BY anio
ORDER BY anio;

-- 9c. Qué áreas absorben la variación (2023 a 2025, las de mayor volumen).
WITH pozos_de_gas AS (
    SELECT m.gas_miles_m3, a.nombre AS area, extract(month FROM m.mes)::integer AS nro_mes
    FROM vm.produccion_mensual m
    JOIN vm.pozo p USING (pozo_id)
    JOIN vm.area a USING (area_id)
    WHERE p.tipo_pozo = 'Gasífero'
      AND p.es_horizontal
      AND m.mes BETWEEN DATE '2023-01-01' AND DATE '2025-12-01'
)
SELECT area,
       round(sum(gas_miles_m3) FILTER (WHERE nro_mes IN (7, 8))   / 186 / 1000, 1) AS pico_invierno,
       round(sum(gas_miles_m3) FILTER (WHERE nro_mes IN (10, 11)) / 183 / 1000, 1) AS valle_primavera,
       round(100 * (1 - (sum(gas_miles_m3) FILTER (WHERE nro_mes IN (10, 11)) / 183)
                      / (sum(gas_miles_m3) FILTER (WHERE nro_mes IN (7, 8)) / 186))) AS caida_pct
FROM pozos_de_gas
GROUP BY area
HAVING sum(gas_miles_m3) > 1500000
ORDER BY pico_invierno DESC;

-- 9d. En qué mes del año empiezan a producir los pozos nuevos (2021 a 2025):
--     gasíferos contra petrolíferos, como porcentaje de cada tipo.
SELECT extract(month FROM primer_mes_produccion)::integer                                     AS mes,
       round(100.0 * count(*) FILTER (WHERE tipo_pozo = 'Gasífero')
             / sum(count(*) FILTER (WHERE tipo_pozo = 'Gasífero')) OVER (), 1)                 AS pct_de_los_gasiferos,
       round(100.0 * count(*) FILTER (WHERE tipo_pozo = 'Petrolífero')
             / sum(count(*) FILTER (WHERE tipo_pozo = 'Petrolífero')) OVER (), 1)              AS pct_de_los_petroliferos
FROM vm.pozo
WHERE es_horizontal
  AND primer_mes_produccion BETWEEN DATE '2021-01-01' AND DATE '2025-12-01'
GROUP BY 1
ORDER BY 1;
