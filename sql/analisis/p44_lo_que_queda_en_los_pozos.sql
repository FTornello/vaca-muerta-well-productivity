-- Pregunta 44: ¿cuánto petróleo les queda por dar a los pozos que ya existen?
-- Las reservas comprobadas (pregunta 15) son lo que las empresas declaran que
-- van a sacar. Una parte está en pozos que ya producen y otra en pozos que
-- todavía no se perforaron. Las fuentes no separan una de otra; acá estimo la
-- primera con la curva de vida del pozo (pregunta 22).
--
-- El método es el de la pregunta 36: cada pozo sigue la curva típica desde la
-- edad que tiene. Lo que le queda es lo que la curva acumula entre esa edad y
-- los 25 años. Millones de m3.

-- 44a. Lo ya producido, lo que queda en los pozos que existen y las reservas.
WITH hoy AS (
    SELECT pm.petroleo_m3 AS m3_mes,
           greatest((extract(year FROM age(DATE '2026-08-01', po.primer_mes_produccion)) * 12
                   + extract(month FROM age(DATE '2026-08-01', po.primer_mes_produccion)))::integer + 1, 4) AS edad
    FROM vm.produccion_mensual pm
    JOIN vm.pozo po USING (pozo_id)
    WHERE pm.mes = DATE '2026-08-01' AND pm.petroleo_m3 > 0
),
queda AS (
    SELECT count(*) AS pozos,
           sum(h.m3_mes * (f.acumulado_bajo - d.acumulado_bajo) / d.caudal_bajo) / 1e6 AS bajo,
           sum(h.m3_mes * (f.acumulado_base - d.acumulado_base) / d.caudal_base) / 1e6 AS base,
           sum(h.m3_mes * (f.acumulado_alto - d.acumulado_alto) / d.caudal_alto) / 1e6 AS alto
    FROM hoy h
    JOIN vm.declinacion d ON d.mes_de_vida = least(h.edad, 300)
    CROSS JOIN (SELECT * FROM vm.declinacion WHERE mes_de_vida = 300) f
)
SELECT (SELECT round(sum(petroleo_m3) / 1e6, 1) FROM vm.produccion_mensual)                           AS ya_producido,
       q.pozos                                                                                       AS pozos_en_produccion,
       round(q.base, 1)                                                                              AS les_queda_escenario_base,
       round(q.bajo, 1)                                                                              AS escenario_bajo,
       round(q.alto, 1)                                                                              AS escenario_alto,
       (SELECT round(sum(petroleo_comprobadas) / 1000, 1) FROM vm.reserva WHERE anio = 2025)         AS reservas_comprobadas_2025,
       round(100 * q.base / (SELECT sum(petroleo_comprobadas) / 1000 FROM vm.reserva WHERE anio = 2025)) AS pct_de_las_reservas
FROM queda q;

-- 44b. Cuánto de lo que queda se saca en cada tramo: la curva cae rápido, así
--      que la mayor parte sale en los primeros años.
WITH hoy AS (
    SELECT pm.petroleo_m3 AS m3_mes,
           greatest((extract(year FROM age(DATE '2026-08-01', po.primer_mes_produccion)) * 12
                   + extract(month FROM age(DATE '2026-08-01', po.primer_mes_produccion)))::integer + 1, 4) AS edad
    FROM vm.produccion_mensual pm
    JOIN vm.pozo po USING (pozo_id)
    WHERE pm.mes = DATE '2026-08-01' AND pm.petroleo_m3 > 0
)
SELECT t.anios                                                                                           AS en_los_proximos_anios,
       round(sum(h.m3_mes * (f.acumulado_base - d.acumulado_base) / d.caudal_base) / 1e6, 1)             AS sale_mm_m3,
       round(100 * sum(h.m3_mes * (f.acumulado_base - d.acumulado_base) / d.caudal_base)
                 / sum(h.m3_mes * (g.acumulado_base - d.acumulado_base) / d.caudal_base))                AS pct_de_lo_que_queda
FROM hoy h
CROSS JOIN (VALUES (1), (3), (5), (10)) AS t(anios)
JOIN vm.declinacion d ON d.mes_de_vida = least(h.edad, 300)
JOIN vm.declinacion f ON f.mes_de_vida = least(h.edad + t.anios * 12, 300)
CROSS JOIN (SELECT * FROM vm.declinacion WHERE mes_de_vida = 300) g
GROUP BY 1
ORDER BY 1;

-- 44c. Pozos nuevos que hacen falta para sacar el resto de las reservas: lo que
--      no está en pozos existentes, dividido por lo que da un pozo típico en
--      toda su vida (38.533 m3 del primer año por 4,23).
WITH hoy AS (
    SELECT pm.petroleo_m3 AS m3_mes,
           greatest((extract(year FROM age(DATE '2026-08-01', po.primer_mes_produccion)) * 12
                   + extract(month FROM age(DATE '2026-08-01', po.primer_mes_produccion)))::integer + 1, 4) AS edad
    FROM vm.produccion_mensual pm
    JOIN vm.pozo po USING (pozo_id)
    WHERE pm.mes = DATE '2026-08-01' AND pm.petroleo_m3 > 0
),
queda AS (
    SELECT sum(h.m3_mes * (f.acumulado_base - d.acumulado_base) / d.caudal_base) / 1e6 AS base
    FROM hoy h
    JOIN vm.declinacion d ON d.mes_de_vida = least(h.edad, 300)
    CROSS JOIN (SELECT * FROM vm.declinacion WHERE mes_de_vida = 300) f
),
tipico AS (
    SELECT 38533 * acumulado_base / 1e6 AS mm_m3_por_pozo FROM vm.declinacion WHERE mes_de_vida = 300
)
SELECT round(r.comprobadas - q.base, 1)                       AS reservas_fuera_de_pozos_existentes,
       round(t.mm_m3_por_pozo, 3)                             AS da_un_pozo_en_su_vida,
       round((r.comprobadas - q.base) / t.mm_m3_por_pozo)     AS pozos_que_harian_falta,
       round((r.comprobadas - q.base) / t.mm_m3_por_pozo / 470, 1) AS anios_al_ritmo_de_2025
FROM queda q, tipico t,
     (SELECT sum(petroleo_comprobadas) / 1000 AS comprobadas FROM vm.reserva WHERE anio = 2025) r;
