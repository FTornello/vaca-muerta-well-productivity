-- Pregunta 26: ¿qué le cambió Vaca Muerta al comercio exterior del país?
-- vm.comercio_energia es del INDEC y es de todo el país: millones de dólares
-- por mes de energía exportada, energía importada y saldo comercial total.
-- 2026 llega hasta agosto.

-- 26a. El saldo energético por año, y cómo habría quedado el saldo del país sin él.
SELECT extract(year FROM mes)::integer                          AS anio,
       count(*)                                                 AS meses,
       round(sum(exportacion_energia))                          AS exporta_energia,
       round(sum(importacion_energia))                          AS importa_energia,
       round(sum(exportacion_energia - importacion_energia))    AS saldo_energia,
       round(sum(saldo_total))                                  AS saldo_del_pais,
       round(sum(saldo_total - exportacion_energia + importacion_energia)) AS saldo_del_pais_sin_energia
FROM vm.comercio_energia
WHERE mes >= DATE '2012-01-01'
GROUP BY 1
ORDER BY 1;

-- 26b. Las importaciones de invierno (junio a agosto). El país importaba gas
--      licuado y combustibles para pasar el frío; es la otra cara de la
--      estacionalidad del gas de la pregunta 9.
SELECT extract(year FROM c.mes)::integer                                       AS anio,
       round(sum(c.importacion_energia))                                       AS importado_en_invierno_usd_mm,
       round(avg(g.gas))                                                       AS gas_vaca_muerta_mm_m3_dia
FROM vm.comercio_energia c
JOIN (SELECT mes, sum(gas_miles_m3) / 1000 / extract(day FROM mes + INTERVAL '1 month' - INTERVAL '1 day') AS gas
      FROM vm.produccion_mensual GROUP BY mes) g USING (mes)
WHERE extract(month FROM c.mes) IN (6, 7, 8) AND c.mes >= DATE '2014-01-01'
GROUP BY 1
ORDER BY 1;

-- 26c. Cuánto de la energía exportada es petróleo de la cuenca Neuquina.
--      El valor exportado es el volumen embarcado por el precio de
--      liquidación de regalías de Neuquén. 2026 llega hasta julio.
WITH crudo AS (
    SELECT x.mes, sum(x.volumen_m3) * max(r.precio_usd_m3) / 1e6 AS usd_mm
    FROM vm.exportacion x
    JOIN vm.regalia_petroleo r ON r.mes = x.mes AND r.provincia = 'Neuquen'
    GROUP BY x.mes
)
SELECT extract(year FROM c.mes)::integer                       AS anio,
       round(sum(cr.usd_mm))                                   AS crudo_neuquino_exportado,
       round(sum(c.exportacion_energia))                       AS energia_exportada_por_el_pais,
       round(100 * sum(cr.usd_mm) / sum(c.exportacion_energia)) AS pct
FROM vm.comercio_energia c
LEFT JOIN crudo cr USING (mes)
WHERE c.mes BETWEEN DATE '2019-01-01' AND (SELECT max(mes) FROM vm.exportacion)
GROUP BY 1
ORDER BY 1;
