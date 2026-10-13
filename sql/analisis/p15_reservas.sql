-- Pregunta 15: ¿cuánto petróleo y gas queda, y se repone lo que se saca?
-- Fuente: vm.reserva (reservas no convencionales de la cuenca Neuquina al 31 de
-- diciembre de cada año) y la producción de Vaca Muerta.
-- Petróleo en millones de m3; gas en miles de millones de m3.
-- Las reservas incluyen todo lo no convencional de cada área y la producción
-- solo la formación Vaca Muerta: en petróleo es casi lo mismo, en gas no tanto.

-- 15a. Por año: reservas comprobadas, producción del año, cuántos años alcanzan
--      a ese ritmo, y cuánto se sumó por cada unidad producida.
WITH reservas AS (
    SELECT anio,
           sum(petroleo_comprobadas) / 1000 AS petroleo,
           sum(gas_comprobadas) / 1000      AS gas
    FROM vm.reserva
    GROUP BY anio
),
produccion AS (
    SELECT extract(year FROM mes)::integer AS anio,
           sum(petroleo_m3) / 1e6          AS petroleo,
           sum(gas_miles_m3) / 1e6         AS gas
    FROM vm.produccion_mensual
    GROUP BY 1
)
SELECT r.anio,
       round(r.petroleo, 1)                                                       AS petroleo_comprobado,
       round(p.petroleo, 1)                                                       AS petroleo_producido,
       round(r.petroleo / p.petroleo, 1)                                          AS anios_de_petroleo,
       round((r.petroleo - lag(r.petroleo) OVER (ORDER BY r.anio) + p.petroleo) / p.petroleo, 1) AS petroleo_sumado_por_cada_producido,
       round(r.gas, 1)                                                            AS gas_comprobado,
       round(p.gas, 1)                                                            AS gas_producido,
       round(r.gas / p.gas, 1)                                                    AS anios_de_gas
FROM reservas r
JOIN produccion p USING (anio)
ORDER BY r.anio;

-- 15b. Las áreas con más petróleo comprobado a fines de 2025: cuánto tienen,
--      cuánto produjeron ese año y cuánto creció la reserva desde 2021.
WITH produccion AS (
    SELECT p.area_id, sum(m.petroleo_m3) / 1e6 AS petroleo_2025
    FROM vm.produccion_mensual m
    JOIN vm.pozo p USING (pozo_id)
    WHERE m.mes BETWEEN DATE '2025-01-01' AND DATE '2025-12-01'
    GROUP BY p.area_id
)
SELECT r.area_nombre                                                    AS area,
       round(r.petroleo_comprobadas / 1000, 1)                          AS comprobado_2025,
       round(r21.petroleo_comprobadas / 1000, 1)                        AS comprobado_2021,
       round(pr.petroleo_2025, 1)                                       AS producido_2025,
       round(r.petroleo_comprobadas / 1000 / nullif(pr.petroleo_2025, 0), 1) AS anios_al_ritmo_actual,
       round(r.petroleo_recursos / 1000, 1)                             AS recursos_no_comerciales
FROM vm.reserva r
LEFT JOIN vm.reserva r21 ON r21.area_nombre = r.area_nombre AND r21.anio = 2021
LEFT JOIN produccion pr ON pr.area_id = r.area_id
WHERE r.anio = 2025
ORDER BY r.petroleo_comprobadas DESC
LIMIT 12;

-- 15c. Concentración de las reservas de petróleo de 2025 en las cuatro áreas
--      históricas, comparada con su peso en la producción.
SELECT round(100 * sum(petroleo_comprobadas) FILTER (
           WHERE area_nombre IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR', 'BAJADA DEL PALO OESTE'))
       / sum(petroleo_comprobadas)) AS pct_de_las_reservas_en_las_4_historicas,
       count(*) FILTER (WHERE petroleo_comprobadas > 0) AS areas_con_reservas
FROM vm.reserva
WHERE anio = 2025;
