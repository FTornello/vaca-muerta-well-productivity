-- Pregunta 28: ¿las empresas cumplen lo que pronostican? ¿Y qué pronostican ahora?
-- Cada marzo las empresas le declaran a la Secretaría de Energía cuánto petróleo
-- va a producir cada área ese año y los cuatro siguientes (vm.pronostico_petroleo).
-- Lo comparo con lo que el área produjo de verdad (vm.produccion_mensual).
--
-- Cuidado con la comparación: el pronóstico es del área entera y mi producción
-- es solo la de Vaca Muerta. Por eso el contraste fino lo hago en las cuatro
-- áreas históricas, donde casi todo el petróleo es de Vaca Muerta.

-- 28a. Producción real sobre pronóstico en las cuatro áreas históricas.
--      1,00 = acertaron; más de 1 = produjeron más de lo que habían dicho.
--      "a N años" = el pronóstico se hizo N años antes.
WITH real AS (
    SELECT po.area_id, extract(year FROM pm.mes)::integer AS anio,
           sum(pm.petroleo_m3) AS m3, count(DISTINCT pm.mes) AS meses
    FROM vm.produccion_mensual pm
    JOIN vm.pozo po USING (pozo_id)
    GROUP BY 1, 2
),
cruce AS (
    SELECT p.anio_informe, p.anio_pronostico - p.anio_informe AS a_anios,
           sum(r.m3) AS real_m3, sum(p.petroleo_m3) AS pronostico_m3
    FROM vm.pronostico_petroleo p
    JOIN vm.area a USING (area_id)
    JOIN real r ON r.area_id = p.area_id AND r.anio = p.anio_pronostico AND r.meses = 12
    WHERE a.nombre IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR', 'BAJADA DEL PALO OESTE')
      AND p.petroleo_m3 > 0
      AND p.anio_informe >= 2016
    GROUP BY 1, 2
)
SELECT anio_informe,
       round(max(real_m3 / pronostico_m3) FILTER (WHERE a_anios = 0), 2) AS el_mismo_anio,
       round(max(real_m3 / pronostico_m3) FILTER (WHERE a_anios = 1), 2) AS a_1_anio,
       round(max(real_m3 / pronostico_m3) FILTER (WHERE a_anios = 2), 2) AS a_2_anios,
       round(max(real_m3 / pronostico_m3) FILTER (WHERE a_anios = 3), 2) AS a_3_anios,
       round(max(real_m3 / pronostico_m3) FILTER (WHERE a_anios = 4), 2) AS a_4_anios
FROM cruce
GROUP BY 1
ORDER BY 1;

-- 28b. Lo que pronostican para adelante: suma de todas las áreas con pozos de
--      Vaca Muerta, según el informe de 2024 y el de 2025, en miles de barriles
--      por día. La última columna es cuánto subió el pronóstico de un año a otro.
SELECT anio_pronostico,
       round(sum(petroleo_m3) FILTER (WHERE anio_informe = 2024) * 6.2898 / 365 / 1000) AS dicho_en_2024,
       round(sum(petroleo_m3) FILTER (WHERE anio_informe = 2025) * 6.2898 / 365 / 1000) AS dicho_en_2025,
       round(100 * (sum(petroleo_m3) FILTER (WHERE anio_informe = 2025)
                  / nullif(sum(petroleo_m3) FILTER (WHERE anio_informe = 2024), 0) - 1))  AS correccion_pct
FROM vm.pronostico_petroleo
WHERE area_id IS NOT NULL AND anio_informe IN (2024, 2025)
GROUP BY 1
ORDER BY 1;

-- 28c. Las áreas que más pesan en el pronóstico para 2029, y cuánto esperan crecer.
SELECT a.nombre AS area,
       round(max(p.petroleo_m3) FILTER (WHERE p.anio_pronostico = 2025) * 6.2898 / 365 / 1000) AS miles_bbl_dia_2025,
       round(max(p.petroleo_m3) FILTER (WHERE p.anio_pronostico = 2029) * 6.2898 / 365 / 1000) AS miles_bbl_dia_2029,
       round(100 * (max(p.petroleo_m3) FILTER (WHERE p.anio_pronostico = 2029)
                  / nullif(max(p.petroleo_m3) FILTER (WHERE p.anio_pronostico = 2025), 0) - 1)) AS crecimiento_pct
FROM vm.pronostico_petroleo p
JOIN vm.area a USING (area_id)
WHERE p.anio_informe = 2025
GROUP BY 1
ORDER BY 3 DESC NULLS LAST
LIMIT 10;
