-- Pregunta 50: ¿de dónde salió el crecimiento?
-- Una forma de juntar las preguntas 1, 2 y 8 en una sola cuenta. El petróleo
-- que da en su primer año la camada de pozos de un año es exactamente:
--
--     cantidad de pozos  x  largo medio de la rama  x  petróleo por km de rama
--
-- Entonces, si la camada de 2024 da más que la de 2021, puedo decir cuánto se
-- debe a que hay más pozos, cuánto a que son más largos y cuánto a que cada
-- kilómetro rinde distinto. Como los tres factores se multiplican, reparto el
-- crecimiento con logaritmos: el logaritmo del total es la suma de los tres.
--
-- Solo pozos con diseño confiable. No uso 2025 como punto de llegada porque
-- un cuarto de sus pozos todavía no cumplió el año de producción que hace
-- falta para medirlos (pregunta 51).

-- 50a. Los tres factores, año por año.
SELECT anio_arranque,
       count(*)                                           AS pozos,
       round(avg(rama_m))                                 AS rama_media_m,
       round(sum(petroleo_12m_m3) / sum(rama_m) * 1000)   AS m3_por_km,
       round(sum(petroleo_12m_m3) / 1e6, 2)               AS petroleo_de_la_camada_mm_m3
FROM vm.pozo_analisis
WHERE diseno_confiable AND petroleo_12m_m3 IS NOT NULL AND rama_m > 0
  AND anio_arranque BETWEEN 2016 AND 2025
GROUP BY 1
ORDER BY 1;

-- 50b. El reparto del crecimiento en dos etapas: de 2016 a 2021 y de 2021 a 2024.
WITH camada AS (
    SELECT anio_arranque AS anio,
           count(*)::numeric                         AS pozos,
           avg(rama_m)                               AS rama,
           sum(petroleo_12m_m3) / sum(rama_m)        AS por_metro,
           sum(petroleo_12m_m3)                      AS total
    FROM vm.pozo_analisis
    WHERE diseno_confiable AND petroleo_12m_m3 IS NOT NULL AND rama_m > 0
    GROUP BY 1
),
etapas (etapa, desde, hasta) AS (
    VALUES ('2016 a 2021', 2016, 2021), ('2021 a 2024', 2021, 2024)
)
SELECT e.etapa,
       round(b.total / a.total, 2)                                         AS la_camada_se_multiplico_por,
       round(b.pozos / a.pozos, 2)                                         AS pozos_por,
       round((b.rama / a.rama)::numeric, 2)                                AS rama_por,
       round((b.por_metro / a.por_metro)::numeric, 2)                      AS rendimiento_por_km_por,
       round(100 * ln(b.pozos / a.pozos) / ln(b.total / a.total))          AS pct_por_mas_pozos,
       round((100 * ln(b.rama / a.rama) / ln(b.total / a.total))::numeric) AS pct_por_ramas_mas_largas,
       round((100 * ln(b.por_metro / a.por_metro) / ln(b.total / a.total))::numeric) AS pct_por_rendimiento
FROM etapas e
JOIN camada a ON a.anio = e.desde
JOIN camada b ON b.anio = e.hasta
ORDER BY 1;
