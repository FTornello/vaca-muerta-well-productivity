-- Pregunta 38: ¿cuáles son los mejores pozos de Vaca Muerta, y hay cada vez más?
-- Mido el petróleo del primer año (vm.pozo_analisis). Para los pozos de 2025 en
-- adelante todavía no hay doce meses completos, así que quedan afuera.

-- 38a. Los quince mejores de la historia.
SELECT row_number() OVER (ORDER BY petroleo_12m_m3 DESC)   AS puesto,
       sigla, area, operadora, anio_arranque,
       round(petroleo_12m_m3)                              AS petroleo_primer_anio_m3,
       round(petroleo_12m_m3 * 6.2898 / 365)               AS barriles_dia_promedio,
       round(rama_m)                                       AS rama_m
FROM vm.pozo_analisis
WHERE petroleo_12m_m3 IS NOT NULL
ORDER BY petroleo_12m_m3 DESC
LIMIT 15;

-- 38b. ¿Hay cada vez más pozos excepcionales? Parte de los pozos de cada año
--      que superó los 70.000 m3 en el primer año (cerca del doble de un pozo
--      típico de hoy) y parte que no llegó a 20.000 (la mitad).
SELECT anio_arranque,
       count(*)                                                                   AS pozos,
       count(*) FILTER (WHERE petroleo_12m_m3 >= 70000)                           AS excepcionales,
       round(100.0 * count(*) FILTER (WHERE petroleo_12m_m3 >= 70000) / count(*), 1) AS pct_excepcionales,
       round(100.0 * count(*) FILTER (WHERE petroleo_12m_m3 <  20000) / count(*), 1) AS pct_flojos,
       round(percentile_cont(0.9) WITHIN GROUP (ORDER BY petroleo_12m_m3))        AS el_10_mejor_supera,
       round(percentile_cont(0.1) WITHIN GROUP (ORDER BY petroleo_12m_m3))        AS el_10_peor_no_llega_a
FROM vm.pozo_analisis
WHERE petroleo_12m_m3 IS NOT NULL AND anio_arranque BETWEEN 2016 AND 2025
GROUP BY 1
ORDER BY 1;

-- 38c. Dónde están los excepcionales.
SELECT area, operadora,
       count(*)                                                        AS pozos_desde_2019,
       count(*) FILTER (WHERE petroleo_12m_m3 >= 70000)                AS excepcionales,
       round(100.0 * count(*) FILTER (WHERE petroleo_12m_m3 >= 70000) / count(*)) AS pct
FROM vm.pozo_analisis
WHERE petroleo_12m_m3 IS NOT NULL AND anio_arranque >= 2019
GROUP BY 1, 2
HAVING count(*) FILTER (WHERE petroleo_12m_m3 >= 70000) >= 3
ORDER BY 4 DESC
LIMIT 10;
