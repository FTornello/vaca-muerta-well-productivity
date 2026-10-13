-- Pregunta 36: ¿qué pasa si mañana se deja de perforar? ¿Y cuántos pozos pide cada meta?
-- Junto tres cosas que ya tenía: la curva de vida del pozo (vm.declinacion,
-- pregunta 22), la producción de cada pozo hoy y lo que aporta un pozo nuevo.
--
-- El método: cada pozo sigue bajando por la curva típica desde la edad que
-- tiene. Si un pozo de 30 meses produce hoy X, dentro de un año va a producir
-- X por lo que la curva da a los 42 meses, dividido por lo que da a los 30.
-- A los pozos de menos de 4 meses, que todavía están subiendo, los trato como
-- si estuvieran en el pico (mes 4): es una simplificación que los subestima.
-- Miles de barriles por día.

-- 36a. Primero pruebo el método con el pasado: tomo los pozos que producían en
--      diciembre de cada año, proyecto un año, y comparo con lo que esos mismos
--      pozos produjeron de verdad.
WITH base AS (
    SELECT y.anio, pm.pozo_id, pm.petroleo_m3 * 6.2898 / 31 / 1000 AS kbd,
           greatest((extract(year FROM age(make_date(y.anio, 12, 1), po.primer_mes_produccion)) * 12
                   + extract(month FROM age(make_date(y.anio, 12, 1), po.primer_mes_produccion)))::integer + 1, 4) AS edad
    FROM generate_series(2020, 2024) AS y(anio)
    JOIN vm.produccion_mensual pm ON pm.mes = make_date(y.anio, 12, 1) AND pm.petroleo_m3 > 0
    JOIN vm.pozo po USING (pozo_id)
),
proyectado AS (
    SELECT b.anio, sum(b.kbd) AS hoy, sum(b.kbd * d2.caudal_base / d1.caudal_base) AS proyectado
    FROM base b
    JOIN vm.declinacion d1 ON d1.mes_de_vida = least(b.edad, 288)
    JOIN vm.declinacion d2 ON d2.mes_de_vida = least(b.edad, 288) + 12
    GROUP BY 1
),
real AS (
    SELECT b.anio, sum(pm.petroleo_m3) * 6.2898 / 31 / 1000 AS real
    FROM base b
    JOIN vm.produccion_mensual pm ON pm.pozo_id = b.pozo_id AND pm.mes = make_date(b.anio + 1, 12, 1)
    GROUP BY 1
)
SELECT p.anio                              AS diciembre_de,
       round(p.hoy)                        AS producian,
       round(p.proyectado)                 AS proyectado_a_un_anio,
       round(r.real)                       AS real_a_un_anio,
       round(100 * (p.proyectado / r.real - 1)) AS error_pct
FROM proyectado p
JOIN real r USING (anio)
ORDER BY 1;

-- 36b. Ahora para adelante: lo que darían los pozos que existen en agosto de
--      2026 si no se perforara ninguno más, en los tres escenarios de la curva.
WITH hoy AS (
    SELECT pm.pozo_id, pm.petroleo_m3 * 6.2898 / 31 / 1000 AS kbd,
           greatest((extract(year FROM age(DATE '2026-08-01', po.primer_mes_produccion)) * 12
                   + extract(month FROM age(DATE '2026-08-01', po.primer_mes_produccion)))::integer + 1, 4) AS edad
    FROM vm.produccion_mensual pm
    JOIN vm.pozo po USING (pozo_id)
    WHERE pm.mes = DATE '2026-08-01' AND pm.petroleo_m3 > 0
)
SELECT to_char(DATE '2026-08-01' + make_interval(months => t.meses), 'YYYY-MM') AS mes,
       round(sum(h.kbd * coalesce(d2.caudal_bajo, 0) / d1.caudal_bajo))  AS escenario_bajo,
       round(sum(h.kbd * coalesce(d2.caudal_base, 0) / d1.caudal_base))  AS escenario_base,
       round(sum(h.kbd * coalesce(d2.caudal_alto, 0) / d1.caudal_alto))  AS escenario_alto,
       round(100 * (sum(h.kbd * coalesce(d2.caudal_base, 0) / d1.caudal_base) / sum(h.kbd) - 1)) AS cambio_pct
FROM hoy h
CROSS JOIN (VALUES (0), (4), (12), (16), (28), (40), (52)) AS t(meses)
JOIN vm.declinacion d1 ON d1.mes_de_vida = least(h.edad, 300)
LEFT JOIN vm.declinacion d2 ON d2.mes_de_vida = h.edad + t.meses
GROUP BY t.meses
ORDER BY t.meses;

-- 36c. Cuántos pozos por año pide cada meta. A la base de 36b le sumo pozos
--      nuevos que arrancan parejos todos los meses desde septiembre de 2026 y
--      rinden como el pozo típico de 2025 (38.533 m3 en el primer año).
--      Un pozo típico aporta, a la edad m, caudal_base(m) * 38.533 m3 por mes;
--      N pozos por año puestos de a N/12 por mes aportan en el mes T
--      (N/12) * acumulado_base(T) * 38.533 m3 por mes.
--      Despejo N para tres metas, tomando el promedio del año de la meta.
WITH hoy AS (
    SELECT pm.petroleo_m3 * 6.2898 / 31 / 1000 AS kbd,
           greatest((extract(year FROM age(DATE '2026-08-01', po.primer_mes_produccion)) * 12
                   + extract(month FROM age(DATE '2026-08-01', po.primer_mes_produccion)))::integer + 1, 4) AS edad
    FROM vm.produccion_mensual pm
    JOIN vm.pozo po USING (pozo_id)
    WHERE pm.mes = DATE '2026-08-01' AND pm.petroleo_m3 > 0
),
meses AS (
    SELECT t AS meses, extract(year FROM DATE '2026-08-01' + make_interval(months => t))::integer AS anio
    FROM generate_series(1, 52) AS t
),
base AS (
    SELECT m.anio, m.meses, sum(h.kbd * coalesce(d2.caudal_base, 0) / d1.caudal_base) AS kbd
    FROM hoy h
    CROSS JOIN meses m
    JOIN vm.declinacion d1 ON d1.mes_de_vida = least(h.edad, 300)
    LEFT JOIN vm.declinacion d2 ON d2.mes_de_vida = h.edad + m.meses
    GROUP BY 1, 2
),
por_anio AS (
    SELECT b.anio,
           avg(b.kbd)                                                   AS base_kbd,
           -- miles de barriles por día que aporta UN pozo por año sostenido
           avg(d.acumulado_base * 38533 * 6.2898 / 30.44 / 1000 / 12)   AS kbd_por_pozo_anual
    FROM base b
    JOIN vm.declinacion d ON d.mes_de_vida = b.meses
    GROUP BY 1
)
SELECT m.meta, m.anio, m.objetivo_kbd,
       round(p.base_kbd)                                         AS dan_los_pozos_de_hoy,
       round(m.objetivo_kbd - p.base_kbd)                        AS falta,
       round((m.objetivo_kbd - p.base_kbd) / p.kbd_por_pozo_anual) AS pozos_por_anio_necesarios
FROM (VALUES ('mantener el nivel de agosto de 2026', 2029, 670),
             ('lo que las empresas declararon para 2029', 2029, 754),
             ('un millón de barriles en 2030', 2030, 1000)) AS m(meta, anio, objetivo_kbd)
JOIN por_anio p USING (anio)
ORDER BY 3;
