-- Pregunta 48: ¿cuántos pozos están parados, y cuándo?
-- La fuente informa todos los meses el estado de cada pozo
-- (vm.produccion_mensual.estado) y cuántos días produjo (dias_activo).

-- 48a. El estado de todos los pozos de Vaca Muerta, cada enero y julio.
SELECT to_char(mes, 'YYYY-MM')                                                                    AS mes,
       count(*)                                                                                   AS pozos,
       round(100.0 * count(*) FILTER (WHERE estado = 'Extracción Efectiva') / count(*))           AS pct_produciendo,
       count(*) FILTER (WHERE estado = 'Parado Transitoriamente')                                 AS parados_transitoriamente,
       count(*) FILTER (WHERE estado IN ('En Estudio', 'En Espera de Reparación'))                AS en_estudio_o_reparacion,
       count(*) FILTER (WHERE estado IN ('A Abandonar', 'Abandonado', 'Abandono Temporario'))     AS abandonados_o_por_abandonar
FROM vm.produccion_mensual
WHERE (extract(month FROM mes) IN (1, 7) AND mes >= DATE '2019-01-01') OR mes = DATE '2026-08-01'
GROUP BY 1
ORDER BY 1;

-- 48b. Los pozos de gas parados según el mes del año (2023 a 2025). Es otra
--      forma de ver la estacionalidad de la pregunta 9: ahí la medí por el
--      volumen, acá por el estado que informa la empresa.
SELECT x.mes_del_anio,
       round(avg(x.pozos))                                AS pozos_de_gas,
       round(100 * avg(x.parados::numeric / x.pozos), 1)  AS pct_parados
FROM (
    SELECT pm.mes, extract(month FROM pm.mes)::integer AS mes_del_anio,
           count(*) AS pozos,
           count(*) FILTER (WHERE pm.estado IN ('Parado Transitoriamente', 'En Reserva de Gas')) AS parados
    FROM vm.produccion_mensual pm
    JOIN vm.pozo_analisis_gas g USING (pozo_id)
    WHERE pm.mes BETWEEN DATE '2023-01-01' AND DATE '2025-12-01'
    GROUP BY 1, 2
) x
GROUP BY 1
ORDER BY 1;

-- 48c. Los pozos de petróleo: qué parte de los días del mes produjeron, por
--      año. Si un pozo se cierra por falta de transporte, o para protegerlo
--      mientras se fractura al vecino, acá se ve.
SELECT extract(year FROM pm.mes)::integer                                                    AS anio,
       round(100 * avg(pm.dias_activo / extract(day FROM pm.mes + INTERVAL '1 month' - INTERVAL '1 day'))::numeric, 1) AS pct_de_los_dias_produciendo,
       round(100.0 * count(*) FILTER (WHERE pm.petroleo_m3 = 0) / count(*), 1)               AS pct_de_meses_sin_producir
FROM vm.produccion_mensual pm
JOIN vm.pozo_analisis a USING (pozo_id)
JOIN vm.pozo po USING (pozo_id)
WHERE pm.mes > po.primer_mes_produccion AND pm.mes >= DATE '2017-01-01'
GROUP BY 1
ORDER BY 1;
