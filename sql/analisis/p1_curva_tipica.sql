-- Pregunta 1: ¿cómo evoluciona la producción de un pozo típico, y los pozos
-- nuevos rinden más que los de hace unos años?
-- Población: pozos horizontales petrolíferos que ya cumplieron 12 meses.

-- 1a. Curva típica: petróleo promedio por mes de vida, según el año de arranque.
SELECT e.mes_de_vida,
       round(avg(e.petroleo_m3) FILTER (WHERE a.anio_arranque = 2016)) AS arranque_2016,
       round(avg(e.petroleo_m3) FILTER (WHERE a.anio_arranque = 2018)) AS arranque_2018,
       round(avg(e.petroleo_m3) FILTER (WHERE a.anio_arranque = 2020)) AS arranque_2020,
       round(avg(e.petroleo_m3) FILTER (WHERE a.anio_arranque = 2022)) AS arranque_2022,
       round(avg(e.petroleo_m3) FILTER (WHERE a.anio_arranque = 2024)) AS arranque_2024
FROM vm.produccion_edad e
JOIN vm.pozo_analisis a USING (pozo_id)
WHERE e.mes_de_vida <= 12
GROUP BY e.mes_de_vida
ORDER BY e.mes_de_vida;

-- 1b. Petróleo del primer año por pozo, según el año de arranque.
SELECT anio_arranque,
       count(*)                                                            AS pozos,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3)) AS mediana_m3,
       round(percentile_cont(0.1) WITHIN GROUP (ORDER BY petroleo_12m_m3)) AS peor_10_m3,
       round(percentile_cont(0.9) WITHIN GROUP (ORDER BY petroleo_12m_m3)) AS mejor_10_m3
FROM vm.pozo_analisis
GROUP BY anio_arranque
ORDER BY anio_arranque;
