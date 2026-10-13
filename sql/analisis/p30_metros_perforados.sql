-- Pregunta 30: ¿cuánto se perfora en Neuquén? (y una comprobación del pozo típico)
-- vm.metros_perforados es otra planilla de la Secretaría: metros perforados por
-- mes y provincia. No tiene nada que ver con las tablas de pozos y fracturas,
-- así que sirve para comprobar por otro lado lo que salió de ellas.

-- 30a. Kilómetros perforados por año en Neuquén y pozos de Vaca Muerta que
--      empezaron a producir. Dividiendo da los metros por pozo, que deberían
--      parecerse a "unos 3.000 m hacia abajo más la rama" (pregunta 2).
WITH metros AS (
    SELECT extract(year FROM mes)::integer AS anio, count(DISTINCT mes) AS meses,
           sum(metros) AS metros,
           sum(metros) FILTER (WHERE concepto = 'Explotación') AS metros_explotacion
    FROM vm.metros_perforados
    WHERE provincia LIKE 'Neuqu%' AND mes >= DATE '2015-01-01'
    GROUP BY 1
),
pozos AS (
    SELECT extract(year FROM primer_mes_produccion)::integer AS anio, count(*) AS pozos
    FROM vm.pozo
    GROUP BY 1
),
rama AS (
    SELECT anio_arranque AS anio, percentile_cont(0.5) WITHIN GROUP (ORDER BY rama_m) AS rama_m
    FROM vm.pozo_analisis
    WHERE diseno_confiable
    GROUP BY 1
)
SELECT m.anio, m.meses,
       round(m.metros / 1000)                         AS km_perforados,
       round(100 * m.metros_explotacion / m.metros)   AS pct_explotacion,
       p.pozos                                        AS pozos_vm_que_arrancaron,
       round(m.metros / p.pozos)                      AS metros_por_pozo,
       round(r.rama_m::numeric)                       AS rama_tipica_m,
       round(m.metros / p.pozos - r.rama_m::numeric)  AS lo_que_queda_para_bajar_m
FROM metros m
JOIN pozos p USING (anio)
LEFT JOIN rama r USING (anio)
ORDER BY 1;

-- 30b. Neuquén contra el resto del país.
SELECT extract(year FROM mes)::integer                                             AS anio,
       round(sum(metros) FILTER (WHERE provincia LIKE 'Neuqu%') / 1000)            AS km_neuquen,
       round(sum(metros) FILTER (WHERE provincia NOT LIKE 'Neuqu%') / 1000)        AS km_resto_del_pais,
       round(100 * sum(metros) FILTER (WHERE provincia LIKE 'Neuqu%') / sum(metros)) AS pct_neuquen
FROM vm.metros_perforados
WHERE mes BETWEEN DATE '2010-01-01' AND DATE '2025-12-01'
GROUP BY 1
ORDER BY 1;

-- 30c. ¿Cuántos pozos salen secos? Pozos terminados en Neuquén según el
--      resultado. En el petróleo convencional parte de los pozos no encuentra
--      nada; en una roca que está en todos lados eso casi no debería pasar.
SELECT extract(year FROM mes)::integer                                        AS anio,
       sum(pozos) FILTER (WHERE resultado = 'Productivos de Petróleo')::integer        AS de_petroleo,
       sum(pozos) FILTER (WHERE resultado = 'Productivos de Gas')::integer             AS de_gas,
       sum(pozos) FILTER (WHERE resultado = 'Servicio')::integer                       AS de_servicio,
       sum(pozos) FILTER (WHERE resultado = 'Improductivos')::integer                  AS improductivos,
       round(100.0 * sum(pozos) FILTER (WHERE resultado = 'Improductivos') / sum(pozos), 1) AS pct_improductivos
FROM vm.pozos_terminados
WHERE provincia LIKE 'Neuqu%' AND mes BETWEEN DATE '2009-01-01' AND DATE '2025-12-01'
GROUP BY 1
ORDER BY 1;

