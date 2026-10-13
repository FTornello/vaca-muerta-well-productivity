-- Pregunta 37: ¿a qué precio del petróleo se paga un pozo?
-- Tomo el pozo típico de 2025 de las cuatro áreas históricas: cuesta 14,2
-- millones de dólares (pregunta 12) y da 38.533 m3 en su primer año, repartidos
-- en el tiempo según la curva de vida (pregunta 22). A lo que vende le resto
-- el 12 % de regalías.
--
-- LO QUE ESTA CUENTA NO TIENE: gastos de operación, transporte, impuestos a las
-- ganancias, retenciones ni el costo del dinero. Mide solo cuánto tarda la
-- venta del petróleo en igualar lo que costó perforar. El precio real al que
-- conviene perforar es más alto que el que sale de acá.

-- 37a. Meses hasta recuperar la perforación, y cuántas veces el costo deja el
--      pozo en 5 y en 25 años, según el precio.
WITH precios AS (
    SELECT p AS usd_bbl FROM (VALUES (30), (40), (50), (60), (70), (80), (100)) AS v(p)
),
flujo AS (
    SELECT pr.usd_bbl, d.mes_de_vida,
           sum(d.caudal_base * 38533 * 6.2898 * pr.usd_bbl * 0.88 / 1e6)
               OVER (PARTITION BY pr.usd_bbl ORDER BY d.mes_de_vida) AS acumulado_usd_mm
    FROM precios pr
    CROSS JOIN vm.declinacion d
)
SELECT usd_bbl                                                              AS precio_usd_bbl,
       min(mes_de_vida) FILTER (WHERE acumulado_usd_mm >= 14.2)             AS meses_para_recuperar,
       round(max(acumulado_usd_mm) FILTER (WHERE mes_de_vida = 12), 1)      AS vende_el_primer_anio_usd_mm,
       round(max(acumulado_usd_mm) FILTER (WHERE mes_de_vida = 60) / 14.2, 1)  AS veces_el_costo_a_5_anios,
       round(max(acumulado_usd_mm) FILTER (WHERE mes_de_vida = 300) / 14.2, 1) AS veces_el_costo_a_25_anios
FROM flujo
GROUP BY 1
ORDER BY 1;

-- 37b. El precio mínimo para recuperar la perforación en 1, 2, 3 y 5 años.
SELECT d.mes_de_vida / 12                                                   AS anios,
       round(14.2e6 / (d.acumulado_base * 38533 * 6.2898 * 0.88), 1)        AS precio_minimo_usd_bbl
FROM vm.declinacion d
WHERE d.mes_de_vida IN (12, 24, 36, 60, 300)
ORDER BY 1;

-- 37c. Lo mismo con el pozo de 2021, que costaba 8,8 millones y rendía igual.
SELECT d.mes_de_vida / 12                                                   AS anios,
       round(8.8e6  / (d.acumulado_base * 38573 * 6.2898 * 0.88), 1)        AS precio_minimo_pozo_2021,
       round(14.2e6 / (d.acumulado_base * 38533 * 6.2898 * 0.88), 1)        AS precio_minimo_pozo_2025
FROM vm.declinacion d
WHERE d.mes_de_vida IN (12, 24, 60)
ORDER BY 1;
