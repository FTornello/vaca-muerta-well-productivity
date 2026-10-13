-- Pregunta 22: ¿cuánto produce un pozo en toda su vida, y cuánto cuesta entonces
-- cada barril?
-- Usa vm.curva_tipo (lo observado) y vm.declinacion (lo observado más la
-- extensión a 25 años hecha en scripts/ajustar_declinacion.py).
-- Todo lo que pasa del mes 117 es una proyección, no un dato.

-- 22a. Lo observado: cuántas veces el primer año lleva producido un pozo a los
--      2, 3, 5, 7 y 9 años, según el año en que arrancó. Si la forma de la
--      curva fuera cambiando, estas columnas cambiarían de un año a otro.
SELECT anio_arranque,
       max(pozos)                                                                   AS pozos,
       max(mes_de_vida)                                                             AS meses_observados,
       round(max(acumulado_sobre_primer_anio) FILTER (WHERE mes_de_vida = 24), 2)   AS a_2_anios,
       round(max(acumulado_sobre_primer_anio) FILTER (WHERE mes_de_vida = 36), 2)   AS a_3_anios,
       round(max(acumulado_sobre_primer_anio) FILTER (WHERE mes_de_vida = 60), 2)   AS a_5_anios,
       round(max(acumulado_sobre_primer_anio) FILTER (WHERE mes_de_vida = 84), 2)   AS a_7_anios,
       round(max(acumulado_sobre_primer_anio) FILTER (WHERE mes_de_vida = 108), 2)  AS a_9_anios
FROM vm.curva_tipo
GROUP BY anio_arranque
ORDER BY anio_arranque;

-- 22b. La vida completa: acumulado en veces el primer año, y qué parte del total
--      de 25 años ya salió en cada momento (escenario base).
SELECT mes_de_vida / 12                                                              AS anios,
       origen,
       round(acumulado_bajo, 2)                                                      AS veces_el_primer_anio_bajo,
       round(acumulado_base, 2)                                                      AS veces_el_primer_anio_base,
       round(acumulado_alto, 2)                                                      AS veces_el_primer_anio_alto,
       round(100 * acumulado_base / (SELECT acumulado_base FROM vm.declinacion WHERE mes_de_vida = 300)) AS pct_del_total_base
FROM vm.declinacion
WHERE mes_de_vida IN (12, 24, 36, 60, 120, 180, 240, 300)
ORDER BY mes_de_vida;

-- 22c. Producción estimada de un pozo en 25 años, según su año de arranque:
--      la mediana del primer año por el multiplicador. Miles de m3 y miles de
--      barriles.
WITH multiplicador AS (
    SELECT acumulado_bajo, acumulado_base, acumulado_alto FROM vm.declinacion WHERE mes_de_vida = 300
),
primer_anio AS (
    SELECT anio_arranque,
           count(*) AS pozos,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY petroleo_12m_m3) AS petroleo_12m_m3
    FROM vm.pozo_analisis
    WHERE anio_arranque >= 2016
    GROUP BY anio_arranque
)
SELECT p.anio_arranque,
       p.pozos,
       round((p.petroleo_12m_m3 / 1000)::numeric, 1)                              AS primer_anio_miles_m3,
       round((p.petroleo_12m_m3 * m.acumulado_bajo / 1000)::numeric)              AS vida_bajo_miles_m3,
       round((p.petroleo_12m_m3 * m.acumulado_base / 1000)::numeric)              AS vida_base_miles_m3,
       round((p.petroleo_12m_m3 * m.acumulado_alto / 1000)::numeric)              AS vida_alto_miles_m3,
       round((p.petroleo_12m_m3 * m.acumulado_base * 6.2898 / 1000)::numeric)     AS vida_base_miles_de_barriles
FROM primer_anio p
CROSS JOIN multiplicador m
ORDER BY p.anio_arranque;

-- 22d. Costo de perforación por barril de toda la vida, y cuántos meses de
--      producción hacen falta para igualar el costo del pozo. Áreas históricas.
--      Valor bruto: no descuenta regalías, impuestos ni gastos de operación.
WITH historicas AS (
    SELECT area_id FROM vm.area
    WHERE nombre IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR', 'BAJADA DEL PALO OESTE')
),
costo AS (
    SELECT extract(year FROM i.mes)::integer AS anio, sum(i.usd_millones) * 1e6 AS perforacion_usd
    FROM vm.inversion i
    JOIN historicas USING (area_id)
    WHERE i.es_perforacion
    GROUP BY 1
),
conectados AS (
    SELECT extract(year FROM p.primer_mes_produccion)::integer AS anio, count(*) AS pozos
    FROM vm.pozo p
    JOIN historicas USING (area_id)
    WHERE p.es_horizontal AND p.primer_mes_produccion IS NOT NULL
    GROUP BY 1
),
primer_anio AS (
    SELECT a.anio_arranque AS anio,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY a.petroleo_12m_m3) AS petroleo_12m_m3
    FROM vm.pozo_analisis a
    WHERE a.area IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR', 'BAJADA DEL PALO OESTE')
    GROUP BY 1
),
precio AS (
    SELECT extract(year FROM mes)::integer AS anio,
           sum(precio_usd_m3 * produccion_m3) / sum(produccion_m3) AS usd_m3
    FROM vm.regalia_petroleo
    WHERE provincia = 'Neuquen'
    GROUP BY 1
),
base AS (
    SELECT c.anio,
           c.perforacion_usd / k.pozos AS costo_pozo_usd,
           a.petroleo_12m_m3,
           pr.usd_m3
    FROM costo c
    JOIN conectados k USING (anio)
    JOIN primer_anio a USING (anio)
    JOIN precio pr USING (anio)
    WHERE c.anio BETWEEN 2019 AND 2025
)
SELECT b.anio,
       round((b.costo_pozo_usd / 1e6)::numeric, 1)                                              AS costo_del_pozo_mm_usd,
       round((b.costo_pozo_usd / (b.petroleo_12m_m3 * 6.2898))::numeric)                        AS usd_por_barril_del_primer_anio,
       round((b.costo_pozo_usd / (b.petroleo_12m_m3 * d.acumulado_alto * 6.2898))::numeric, 1)  AS usd_por_barril_de_la_vida_alto,
       round((b.costo_pozo_usd / (b.petroleo_12m_m3 * d.acumulado_base * 6.2898))::numeric, 1)  AS usd_por_barril_de_la_vida_base,
       round((b.costo_pozo_usd / (b.petroleo_12m_m3 * d.acumulado_bajo * 6.2898))::numeric, 1)  AS usd_por_barril_de_la_vida_bajo,
       round((b.usd_m3 / 6.2898)::numeric, 1)                                                   AS precio_usd_por_barril,
       (SELECT min(x.mes_de_vida)
        FROM vm.declinacion x
        WHERE b.petroleo_12m_m3 * x.acumulado_base * b.usd_m3 >= b.costo_pozo_usd)              AS meses_para_igualar_el_costo
FROM base b
CROSS JOIN (SELECT * FROM vm.declinacion WHERE mes_de_vida = 300) d
ORDER BY b.anio;
