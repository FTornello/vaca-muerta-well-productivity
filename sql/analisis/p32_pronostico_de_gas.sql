-- Pregunta 32: ¿qué esperan las empresas del gas?
-- Lo mismo que la pregunta 28, para el gas (vm.pronostico_gas): cada marzo las
-- empresas declaran cuánto gas va a dar cada área. Toda la provincia de
-- Neuquén, en millones de m3 por día.

-- 32a. Lo que cada informe dijo para los años siguientes. Leyendo una columna
--      de arriba abajo se ve cómo fue cambiando el pronóstico para ese año.
SELECT anio_informe,
       round(sum(gas_miles_m3) FILTER (WHERE anio_pronostico = 2024) / 366 / 1000, 1) AS para_2024,
       round(sum(gas_miles_m3) FILTER (WHERE anio_pronostico = 2025) / 365 / 1000, 1) AS para_2025,
       round(sum(gas_miles_m3) FILTER (WHERE anio_pronostico = 2026) / 365 / 1000, 1) AS para_2026,
       round(sum(gas_miles_m3) FILTER (WHERE anio_pronostico = 2027) / 365 / 1000, 1) AS para_2027,
       round(sum(gas_miles_m3) FILTER (WHERE anio_pronostico = 2028) / 366 / 1000, 1) AS para_2028,
       round(sum(gas_miles_m3) FILTER (WHERE anio_pronostico = 2029) / 365 / 1000, 1) AS para_2029
FROM vm.pronostico_gas
WHERE tipo = 'Totales Anuales' AND anio_informe >= 2021
GROUP BY 1
ORDER BY 1;

-- 32b. Petróleo y gas lado a lado: cuánto esperan crecer de 2026 a 2029 según
--      el informe de 2025. El petróleo es el de las áreas con pozos de Vaca
--      Muerta (pregunta 28); el gas, el de toda la provincia.
SELECT 'petróleo (miles de barriles por día)' AS producto,
       round(sum(petroleo_m3) FILTER (WHERE anio_pronostico = 2026) * 6.2898 / 365 / 1000) AS en_2026,
       round(sum(petroleo_m3) FILTER (WHERE anio_pronostico = 2029) * 6.2898 / 365 / 1000) AS en_2029,
       round(100 * (sum(petroleo_m3) FILTER (WHERE anio_pronostico = 2029)
                  / sum(petroleo_m3) FILTER (WHERE anio_pronostico = 2026) - 1))           AS crecimiento_pct
FROM vm.pronostico_petroleo
WHERE anio_informe = 2025 AND area_id IS NOT NULL
UNION ALL
SELECT 'gas (millones de m3 por día)',
       round(sum(gas_miles_m3) FILTER (WHERE anio_pronostico = 2026) / 365 / 1000),
       round(sum(gas_miles_m3) FILTER (WHERE anio_pronostico = 2029) / 365 / 1000),
       round(100 * (sum(gas_miles_m3) FILTER (WHERE anio_pronostico = 2029)
                  / sum(gas_miles_m3) FILTER (WHERE anio_pronostico = 2026) - 1))
FROM vm.pronostico_gas
WHERE anio_informe = 2025 AND tipo = 'Totales Anuales';

-- 32c. El gas que las empresas declaran que van a ventear en el año en curso,
--      y qué parte es de todo lo que piensan producir (mercado + consumo
--      propio + venteo + exportado).
SELECT anio_informe,
       round(sum(gas_miles_m3) FILTER (WHERE tipo = 'Gas Aventado') / 365 / 1000, 2) AS venteo_declarado_mm_m3_dia,
       round(sum(gas_miles_m3) / 365 / 1000, 1)                                      AS total_del_anio_mm_m3_dia,
       round(100 * sum(gas_miles_m3) FILTER (WHERE tipo = 'Gas Aventado') / sum(gas_miles_m3), 1) AS pct_venteo
FROM vm.pronostico_gas
WHERE anio_pronostico = anio_informe AND tipo <> 'Totales Anuales' AND anio_informe >= 2016
GROUP BY 1
ORDER BY 1;
