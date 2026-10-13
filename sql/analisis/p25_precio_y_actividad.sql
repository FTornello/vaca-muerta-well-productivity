-- Pregunta 25: ¿se perfora más cuando el petróleo vale más?
-- Actividad = etapas de fractura por mes (vm.fractura). Precio = el de
-- liquidación de regalías de Neuquén (vm.regalia_petroleo), en USD por barril.
-- Las empresas no reaccionan en el momento, así que pruebo demoras de 0 a 12
-- meses entre el precio y la actividad.
--
-- Dos correlaciones, porque la primera engaña: las dos series crecieron en el
-- período, y dos cosas que crecen siempre "se parecen". La segunda compara el
-- CAMBIO contra el mismo mes del año anterior, que saca la tendencia.
-- Hasta 2025: las fracturas de 2026 están incompletas.

-- 25a. Correlación según la demora.
WITH etapas AS (
    SELECT date_trunc('month', fecha_inicio)::date AS mes, sum(etapas) AS etapas
    FROM vm.fractura
    WHERE fecha_inicio BETWEEN DATE '2017-01-01' AND DATE '2025-12-31' AND NOT dato_sospechoso
    GROUP BY 1
),
precio AS (
    SELECT mes, precio_usd_m3 / 6.2898 AS usd_bbl FROM vm.regalia_petroleo WHERE provincia = 'Neuquen'
)
SELECT d.demora_meses,
       round(corr(e.etapas, p.usd_bbl)::numeric, 2)                             AS correlacion_de_niveles,
       round(corr(e.etapas - e12.etapas, p.usd_bbl - p12.usd_bbl)::numeric, 2)  AS correlacion_de_cambios_anuales,
       count(*)                                                                 AS meses
FROM generate_series(0, 12, 2) AS d(demora_meses)
JOIN etapas e   ON true
JOIN precio p   ON p.mes   = e.mes - make_interval(months => d.demora_meses)
JOIN etapas e12 ON e12.mes = e.mes - INTERVAL '12 months'
JOIN precio p12 ON p12.mes = p.mes - INTERVAL '12 months'
GROUP BY 1
ORDER BY 1;

-- 25b. Lo mismo año por año, para verlo sin estadística.
SELECT e.anio, p.usd_bbl, e.etapas,
       round(100.0 * (e.etapas - lag(e.etapas) OVER (ORDER BY e.anio)) / lag(e.etapas) OVER (ORDER BY e.anio)) AS cambio_etapas_pct,
       round(100.0 * (p.usd_bbl - lag(p.usd_bbl) OVER (ORDER BY e.anio)) / lag(p.usd_bbl) OVER (ORDER BY e.anio)) AS cambio_precio_pct
FROM (SELECT extract(year FROM fecha_inicio)::integer AS anio, sum(etapas) AS etapas
      FROM vm.fractura
      WHERE fecha_inicio BETWEEN DATE '2016-01-01' AND DATE '2025-12-31' AND NOT dato_sospechoso
      GROUP BY 1) e
JOIN (SELECT extract(year FROM mes)::integer AS anio, round(avg(precio_usd_m3 / 6.2898)::numeric, 1) AS usd_bbl
      FROM vm.regalia_petroleo WHERE provincia = 'Neuquen' GROUP BY 1) p USING (anio)
ORDER BY 1;
