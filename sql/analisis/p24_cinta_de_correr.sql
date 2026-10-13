-- Pregunta 24: ¿cuánto hay que perforar solo para no caer?
-- Un pozo de Vaca Muerta pierde producción rápido (pregunta 1). Entonces el
-- total depende de que entren pozos nuevos todo el tiempo. Acá mido tres cosas:
-- de qué edad son los pozos que dan el petróleo, cuánto pierde en un año el
-- conjunto de pozos que ya existía, y cuántos pozos nuevos hacen falta para
-- tapar esa pérdida. Barriles por día = m3 del mes * 6,2898 / 31.

-- 24a. De qué edad son los pozos que dan el petróleo de cada diciembre.
WITH p AS (
    SELECT pm.mes, pm.petroleo_m3,
           (extract(year FROM age(pm.mes, po.primer_mes_produccion)) * 12
            + extract(month FROM age(pm.mes, po.primer_mes_produccion)))::integer AS edad_meses
    FROM vm.produccion_mensual pm
    JOIN vm.pozo po USING (pozo_id)
    WHERE po.primer_mes_produccion IS NOT NULL
)
SELECT to_char(mes, 'YYYY-MM')                                                             AS mes,
       round(sum(petroleo_m3) * 6.2898 / 31 / 1000)                                        AS miles_bbl_dia,
       round(100 * sum(petroleo_m3) FILTER (WHERE edad_meses < 12) / sum(petroleo_m3))     AS pct_pozos_de_menos_de_1_anio,
       round(100 * sum(petroleo_m3) FILTER (WHERE edad_meses BETWEEN 12 AND 35) / sum(petroleo_m3)) AS pct_de_1_a_3_anios,
       round(100 * sum(petroleo_m3) FILTER (WHERE edad_meses >= 36) / sum(petroleo_m3))    AS pct_de_mas_de_3_anios
FROM p
WHERE (extract(month FROM mes) = 12 AND mes >= DATE '2017-01-01') OR mes = DATE '2026-08-01'
GROUP BY 1
ORDER BY 1;

-- 24b. La cuenta completa de cada año.
--      base:    los pozos que ya producían en diciembre del año anterior.
--      caída:   lo que esos mismos pozos dejaron de dar un año después.
--      nuevos:  lo que daban en diciembre los pozos arrancados durante el año.
--      pozos_para_empatar: caída dividida por el aporte de un pozo nuevo.
WITH base AS (
    SELECT y AS anio, pm.pozo_id
    FROM generate_series(2017, 2025) AS y
    JOIN vm.pozo po ON po.primer_mes_produccion < make_date(y, 1, 1)
    JOIN vm.produccion_mensual pm ON pm.pozo_id = po.pozo_id AND pm.mes = make_date(y - 1, 12, 1)
    GROUP BY 1, 2
),
caida AS (
    SELECT b.anio,
           sum(pm.petroleo_m3) FILTER (WHERE pm.mes = make_date(b.anio - 1, 12, 1)) * 6.2898 / 31 / 1000 AS base_inicio,
           sum(pm.petroleo_m3) FILTER (WHERE pm.mes = make_date(b.anio, 12, 1))     * 6.2898 / 31 / 1000 AS base_fin
    FROM base b
    JOIN vm.produccion_mensual pm
      ON pm.pozo_id = b.pozo_id AND pm.mes IN (make_date(b.anio - 1, 12, 1), make_date(b.anio, 12, 1))
    GROUP BY 1
),
nuevos AS (
    SELECT extract(year FROM po.primer_mes_produccion)::integer AS anio,
           count(DISTINCT po.pozo_id)                           AS pozos,
           sum(pm.petroleo_m3) * 6.2898 / 31 / 1000             AS aporte
    FROM vm.pozo po
    JOIN vm.produccion_mensual pm
      ON pm.pozo_id = po.pozo_id
     AND pm.mes = make_date(extract(year FROM po.primer_mes_produccion)::integer, 12, 1)
    WHERE po.primer_mes_produccion BETWEEN DATE '2017-01-01' AND DATE '2025-12-01'
    GROUP BY 1
)
SELECT c.anio,
       round(c.base_inicio)                                   AS base_miles_bbl_dia,
       round(100 * (1 - c.base_fin / c.base_inicio))          AS caida_de_la_base_pct,
       round(c.base_inicio - c.base_fin)                      AS se_pierden_miles_bbl_dia,
       n.pozos                                                AS pozos_nuevos,
       round(n.aporte)                                        AS aportan_miles_bbl_dia,
       round(n.aporte * 1000 / n.pozos)                       AS bbl_dia_por_pozo_nuevo,
       round((c.base_inicio - c.base_fin) / (n.aporte / n.pozos))            AS pozos_para_empatar,
       round(100 * (c.base_inicio - c.base_fin) / n.aporte)   AS pct_del_esfuerzo_que_solo_repone
FROM caida c
JOIN nuevos n USING (anio)
ORDER BY 1;

-- 24c. Contraste de tres afirmaciones que circulan en la prensa, con agosto de 2026:
--      "el 80 % de la producción viene de menos del 20 % de los pozos",
--      "el 60 % de los pozos produce menos de 125 barriles por día" y
--      "ningún pozo de más de cuatro años sostiene niveles de pozo nuevo".
WITH a AS (
    SELECT pm.pozo_id,
           pm.petroleo_m3 * 6.2898 / 31                                  AS bbl_dia,
           (DATE '2026-08-01' - po.primer_mes_produccion) / 365.25       AS edad_anios
    FROM vm.produccion_mensual pm
    JOIN vm.pozo po USING (pozo_id)
    WHERE pm.mes = DATE '2026-08-01' AND pm.petroleo_m3 > 0
),
r AS (
    SELECT *, ntile(5) OVER (ORDER BY bbl_dia DESC) AS quinto,
           sum(bbl_dia) OVER () AS total, count(*) OVER () AS n
    FROM a
)
SELECT max(n)                                                                    AS pozos_con_petroleo,
       round(100 * sum(bbl_dia) FILTER (WHERE quinto = 1) / max(total))          AS pct_que_da_el_20_mejor,
       round(100.0 * count(*) FILTER (WHERE bbl_dia < 125) / max(n))             AS pct_de_pozos_bajo_125,
       round(100 * sum(bbl_dia) FILTER (WHERE bbl_dia < 125) / max(total))       AS pct_del_petroleo_que_dan,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY bbl_dia) FILTER (WHERE edad_anios < 1)::numeric)  AS mediana_pozo_de_menos_de_1_anio,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY bbl_dia) FILTER (WHERE edad_anios >= 4)::numeric) AS mediana_pozo_de_mas_de_4_anios,
       count(*) FILTER (WHERE edad_anios >= 4 AND bbl_dia >= 500)                AS pozos_viejos_sobre_500
FROM r;
