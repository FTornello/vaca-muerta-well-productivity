-- Pregunta 54: ¿el pozo es más caro porque es más largo o porque perforar se encareció?
-- La pregunta 12 dio el costo por pozo. Acá cruzo tres planillas que nunca
-- había puesto juntas: la plata declarada en perforación (vm.inversion), los
-- metros perforados en Neuquén (vm.metros_perforados) y los pozos terminados
-- (vm.pozos_terminados). Con eso el costo del pozo se parte en dos:
--
--     costo por pozo  =  metros por pozo  x  dólares por metro
--
-- "Perforación" en la planilla de inversiones incluye la terminación del pozo
-- (la fractura), así que el dólar por metro tiene adentro la arena y las etapas.

-- 54a. Los tres números, año por año.
SELECT i.anio,
       round(i.usd_mm)                                 AS inversion_en_perforacion_usd_mm,
       round(m.metros / 1000)                          AS km_perforados,
       t.pozos::integer                                AS pozos_terminados,
       round(m.metros / t.pozos)                       AS metros_por_pozo,
       round(i.usd_mm * 1e6 / m.metros)                AS usd_por_metro,
       round(i.usd_mm / t.pozos, 1)                    AS usd_mm_por_pozo
FROM (SELECT extract(year FROM mes)::integer AS anio, sum(usd_millones) FILTER (WHERE es_perforacion) AS usd_mm
      FROM vm.inversion GROUP BY 1) i
JOIN (SELECT extract(year FROM mes)::integer AS anio, sum(metros) AS metros
      FROM vm.metros_perforados WHERE provincia LIKE 'Neuqu%' GROUP BY 1) m USING (anio)
JOIN (SELECT extract(year FROM mes)::integer AS anio, sum(pozos) AS pozos
      FROM vm.pozos_terminados WHERE provincia LIKE 'Neuqu%' GROUP BY 1) t USING (anio)
WHERE i.anio BETWEEN 2017 AND 2025
ORDER BY 1;

-- 54b. El reparto del encarecimiento entre 2021 y 2024, con logaritmos como en
--      la pregunta 50, y cuánto creció la arena por metro de rama en el mismo
--      período (lo que el dólar por metro tiene adentro).
WITH anual AS (
    SELECT i.anio, i.usd_mm, m.metros, t.pozos
    FROM (SELECT extract(year FROM mes)::integer AS anio, sum(usd_millones) FILTER (WHERE es_perforacion) AS usd_mm
          FROM vm.inversion GROUP BY 1) i
    JOIN (SELECT extract(year FROM mes)::integer AS anio, sum(metros) AS metros
          FROM vm.metros_perforados WHERE provincia LIKE 'Neuqu%' GROUP BY 1) m USING (anio)
    JOIN (SELECT extract(year FROM mes)::integer AS anio, sum(pozos) AS pozos
          FROM vm.pozos_terminados WHERE provincia LIKE 'Neuqu%' GROUP BY 1) t USING (anio)
),
arena AS (
    SELECT anio_arranque AS anio, sum(arena_tn) / sum(rama_m) AS t_por_metro
    FROM vm.pozo_analisis WHERE diseno_confiable AND rama_m > 0 GROUP BY 1
)
SELECT round((b.usd_mm / b.pozos) / (a.usd_mm / a.pozos), 2)                       AS el_pozo_se_multiplico_por,
       round((b.metros / b.pozos) / (a.metros / a.pozos), 2)                       AS metros_por_pozo_por,
       round((b.usd_mm / b.metros) / (a.usd_mm / a.metros), 2)                     AS usd_por_metro_por,
       round(100 * ln((b.metros / b.pozos) / (a.metros / a.pozos))
                 / ln((b.usd_mm / b.pozos) / (a.usd_mm / a.pozos)))                AS pct_por_pozos_mas_largos,
       round(100 * ln((b.usd_mm / b.metros) / (a.usd_mm / a.metros))
                 / ln((b.usd_mm / b.pozos) / (a.usd_mm / a.pozos)))                AS pct_por_metro_mas_caro,
       round((ab.t_por_metro / aa.t_por_metro)::numeric, 2)                        AS arena_por_metro_de_rama_por
FROM anual a
JOIN anual b ON b.anio = 2024
JOIN arena aa ON aa.anio = 2021
JOIN arena ab ON ab.anio = 2024
WHERE a.anio = 2021;
