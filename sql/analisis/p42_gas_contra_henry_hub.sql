-- Pregunta 42: ¿el gas de Vaca Muerta es caro o barato?
-- Comparo lo que cobra el productor en la cuenca Neuquina (vm.precio_gas) con
-- el Henry Hub (vm.henry_hub), que es el precio del gas en Estados Unidos, el
-- país que inventó el shale. Las dos series están en dólares por millón de BTU.

-- 42a. Año por año.
SELECT extract(year FROM g.mes)::integer                 AS anio,
       count(*)                                          AS meses,
       round(avg(g.precio_promedio), 2)                  AS neuquen_promedio,
       round(avg(g.precio_exportacion), 2)               AS neuquen_exportacion,
       round(avg(h.usd_mmbtu), 2)                        AS henry_hub,
       round(avg(g.precio_promedio) - avg(h.usd_mmbtu), 2) AS diferencia,
       round(100 * avg(g.precio_promedio) / avg(h.usd_mmbtu)) AS pct_del_henry_hub
FROM vm.precio_gas g
JOIN vm.henry_hub h USING (mes)
GROUP BY 1
ORDER BY 1;

-- 42b. La estacionalidad de los dos precios: invierno de cada hemisferio
--      contra el resto del año. En Argentina el invierno es junio a agosto;
--      en Estados Unidos, diciembre a febrero.
SELECT 'Neuquén (invierno: junio a agosto)'                                                   AS serie,
       round(avg(precio_promedio) FILTER (WHERE extract(month FROM mes) IN (6, 7, 8)), 2)     AS en_invierno,
       round(avg(precio_promedio) FILTER (WHERE extract(month FROM mes) NOT IN (6, 7, 8)), 2) AS resto_del_anio,
       round(100 * (avg(precio_promedio) FILTER (WHERE extract(month FROM mes) IN (6, 7, 8))
                  / avg(precio_promedio) FILTER (WHERE extract(month FROM mes) NOT IN (6, 7, 8)) - 1)) AS invierno_mas_caro_pct
FROM vm.precio_gas
WHERE mes >= DATE '2021-01-01'
UNION ALL
SELECT 'Henry Hub (invierno: diciembre a febrero)',
       round(avg(usd_mmbtu) FILTER (WHERE extract(month FROM mes) IN (12, 1, 2)), 2),
       round(avg(usd_mmbtu) FILTER (WHERE extract(month FROM mes) NOT IN (12, 1, 2)), 2),
       round(100 * (avg(usd_mmbtu) FILTER (WHERE extract(month FROM mes) IN (12, 1, 2))
                  / avg(usd_mmbtu) FILTER (WHERE extract(month FROM mes) NOT IN (12, 1, 2)) - 1))
FROM vm.henry_hub
WHERE mes >= DATE '2021-01-01' AND mes <= (SELECT max(mes) FROM vm.precio_gas);
