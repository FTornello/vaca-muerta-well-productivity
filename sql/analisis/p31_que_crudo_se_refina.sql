-- Pregunta 31: ¿qué petróleo procesan las refinerías argentinas?
-- vm.crudo_procesado dice, refinería por refinería, de dónde viene el crudo
-- que procesa. La pregunta 27 mostró que el total que se refina no creció;
-- acá miro si cambió la mezcla. Miles de barriles por día.

-- 31a. De dónde viene el crudo que se refina en el país.
WITH m AS (
    SELECT mes, origen, sum(m3) AS m3,
           extract(day FROM mes + INTERVAL '1 month' - INTERVAL '1 day') AS dias
    FROM vm.crudo_procesado
    GROUP BY 1, 2
),
anual AS (
    SELECT extract(year FROM mes)::integer AS anio, origen, sum(m3) AS m3
    FROM m GROUP BY 1, 2
),
dias AS (
    SELECT extract(year FROM mes)::integer AS anio, count(*) AS meses, sum(dias) AS dias
    FROM (SELECT DISTINCT mes, dias FROM m) x GROUP BY 1
)
SELECT a.anio, d.meses,
       round(sum(a.m3) FILTER (WHERE a.origen = 'Neuquén') * 6.2898 / max(d.dias) / 1000)                     AS neuquen,
       round(sum(a.m3) FILTER (WHERE a.origen = 'Resto de la cuenca Neuquina') * 6.2898 / max(d.dias) / 1000) AS resto_cuenca_neuquina,
       round(sum(a.m3) FILTER (WHERE a.origen = 'Golfo San Jorge') * 6.2898 / max(d.dias) / 1000)             AS golfo_san_jorge,
       round(coalesce(sum(a.m3) FILTER (WHERE a.origen = 'Otras cuencas'), 0) * 6.2898 / max(d.dias) / 1000)  AS otras_cuencas,
       round(coalesce(sum(a.m3) FILTER (WHERE a.origen = 'Importado'), 0) * 6.2898 / max(d.dias) / 1000)      AS importado,
       round(sum(a.m3) * 6.2898 / max(d.dias) / 1000)                                                         AS total,
       round(100 * sum(a.m3) FILTER (WHERE a.origen = 'Neuquén') / sum(a.m3))                                 AS pct_neuquen
FROM anual a
JOIN dias d USING (anio)
GROUP BY a.anio, d.meses
ORDER BY 1;

-- 31b. Cuánto del crecimiento de Vaca Muerta se quedó en las refinerías del país.
--      Comparo, contra 2017, lo que creció la producción de Vaca Muerta con lo
--      que creció el crudo de la cuenca Neuquina que se refina. Uso la cuenca
--      entera porque las refinerías no separan parejo Neuquén de Río Negro.
WITH vaca AS (
    SELECT extract(year FROM mes)::integer AS anio,
           sum(petroleo_m3) * 6.2898 / (count(DISTINCT mes) * 30.44) / 1000 AS kbd
    FROM vm.produccion_mensual GROUP BY 1
),
refinado AS (
    SELECT extract(year FROM mes)::integer AS anio,
           sum(m3) FILTER (WHERE origen IN ('Neuquén', 'Resto de la cuenca Neuquina'))
               * 6.2898 / (count(DISTINCT mes) * 30.44) / 1000 AS neuquina,
           sum(m3) FILTER (WHERE origen NOT IN ('Neuquén', 'Resto de la cuenca Neuquina'))
               * 6.2898 / (count(DISTINCT mes) * 30.44) / 1000 AS otros
    FROM vm.crudo_procesado GROUP BY 1
)
SELECT v.anio,
       round(v.kbd)                                               AS vaca_muerta_produce,
       round(r.neuquina)                                          AS crudo_neuquino_refinado,
       round(r.otros)                                             AS otros_crudos_refinados,
       round(v.kbd - first_value(v.kbd) OVER w)                   AS vaca_muerta_sumo_desde_2017,
       round(r.neuquina - first_value(r.neuquina) OVER w)         AS las_refinerias_tomaron_de_mas,
       round(100 * (r.neuquina - first_value(r.neuquina) OVER w)
                 / nullif(v.kbd - first_value(v.kbd) OVER w, 0))  AS pct_que_se_quedo_en_el_pais
FROM vaca v
JOIN refinado r USING (anio)
WHERE v.anio >= 2017
WINDOW w AS (ORDER BY v.anio)
ORDER BY 1;

-- 31c. Qué refinerías usan crudo de la cuenca Neuquina, 2025.
SELECT refineria,
       round(sum(m3) * 6.2898 / 365 / 1000)                                  AS procesa_miles_bbl_dia,
       round(coalesce(sum(m3) FILTER (WHERE origen IN ('Neuquén', 'Resto de la cuenca Neuquina')), 0) * 6.2898 / 365 / 1000) AS de_la_cuenca_neuquina,
       round(100 * coalesce(sum(m3) FILTER (WHERE origen IN ('Neuquén', 'Resto de la cuenca Neuquina')), 0) / sum(m3)) AS pct
FROM vm.crudo_procesado
WHERE mes BETWEEN DATE '2025-01-01' AND DATE '2025-12-01'
GROUP BY 1
HAVING sum(m3) * 6.2898 / 365 / 1000 >= 1
ORDER BY 2 DESC;
