-- Pregunta 33: ¿a cuánto se vende el petróleo de Neuquén comparado con el precio internacional?
-- Precio local = el de liquidación de regalías de Neuquén (vm.regalia_petroleo),
-- que promedia lo vendido adentro y afuera del país. Precio internacional = el
-- Brent (vm.brent). Dólares por barril.
--
-- Sirve para revisar con datos algo que en la pregunta 25 dije sin probar: que
-- durante años el precio local estuvo desenganchado del internacional.

-- 33a. Año por año: precio local, Brent y qué parte del Brent se cobró.
SELECT extract(year FROM r.mes)::integer                                   AS anio,
       count(*)                                                            AS meses,
       round(avg(r.precio_usd_m3 / 6.2898), 1)                             AS neuquen_usd_bbl,
       round(avg(b.usd_bbl), 1)                                            AS brent_usd_bbl,
       round(avg(r.precio_usd_m3 / 6.2898) - avg(b.usd_bbl), 1)            AS diferencia,
       round(100 * avg(r.precio_usd_m3 / 6.2898) / avg(b.usd_bbl))         AS pct_del_brent
FROM vm.regalia_petroleo r
JOIN vm.brent b USING (mes)
WHERE r.provincia = 'Neuquen' AND r.mes >= DATE '2010-01-01'
GROUP BY 1
ORDER BY 1;

-- 33b. ¿El precio local se mueve con el Brent? Correlación de los cambios de
--      un mes al siguiente, por período. Cerca de 0 = va por su cuenta; cerca
--      de 1 = lo sigue.
WITH m AS (
    SELECT r.mes,
           r.precio_usd_m3 / 6.2898 - lag(r.precio_usd_m3 / 6.2898) OVER (ORDER BY r.mes) AS cambio_local,
           b.usd_bbl - lag(b.usd_bbl) OVER (ORDER BY r.mes)                               AS cambio_brent
    FROM vm.regalia_petroleo r
    JOIN vm.brent b USING (mes)
    WHERE r.provincia = 'Neuquen' AND r.mes >= DATE '2010-01-01'
)
SELECT CASE WHEN mes < DATE '2015-01-01' THEN '2010 a 2014'
            WHEN mes < DATE '2021-01-01' THEN '2015 a 2020'
            ELSE '2021 en adelante' END                    AS periodo,
       count(*)                                            AS meses,
       round(corr(cambio_local, cambio_brent)::numeric, 2) AS correlacion_de_cambios
FROM m
WHERE cambio_local IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- 33c. Cuánta plata es la diferencia: lo que valió el petróleo de Vaca Muerta
--      al precio local, y lo que habría valido al Brent, en millones de dólares.
--      No es "plata perdida": el Brent es un crudo distinto, puesto en Europa,
--      y de ahí hay que restar flete, calidad y retenciones.
SELECT extract(year FROM p.mes)::integer                                        AS anio,
       round(sum(p.m3 * r.precio_usd_m3) / 1e6)                                 AS valor_a_precio_local,
       round(sum(p.m3 * 6.2898 * b.usd_bbl) / 1e6)                              AS valor_a_brent,
       round(sum(p.m3 * 6.2898 * b.usd_bbl - p.m3 * r.precio_usd_m3) / 1e6)     AS diferencia
FROM (SELECT mes, sum(petroleo_m3) AS m3 FROM vm.produccion_mensual GROUP BY mes) p
JOIN vm.regalia_petroleo r ON r.mes = p.mes AND r.provincia = 'Neuquen'
JOIN vm.brent b ON b.mes = p.mes
WHERE p.mes >= DATE '2017-01-01'
GROUP BY 1
ORDER BY 1;
