-- Pregunta 12: ¿cuánto cuesta un pozo, y cuánto cuesta cada barril?
-- Cruza las inversiones en perforación declaradas por las empresas (Res. 2057)
-- con los pozos horizontales que empezaron a producir.
-- Límites: (1) son declaraciones juradas sin auditar y algunas empresas cargan
-- la perforación bajo otros conceptos; (2) la plata se gasta meses antes de que
-- el pozo produzca, así que comparar el mismo año es una aproximación.

-- 12a. Por año: inversión en perforación, pozos conectados y costo por pozo.
WITH inversion AS (
    SELECT extract(year FROM mes)::integer AS anio,
           sum(usd_millones)                               AS total_mm,
           sum(usd_millones) FILTER (WHERE es_perforacion) AS perforacion_mm
    FROM vm.inversion
    WHERE area_id IS NOT NULL
    GROUP BY 1
),
pozos AS (
    SELECT extract(year FROM primer_mes_produccion)::integer AS anio, count(*) AS pozos
    FROM vm.pozo
    WHERE es_horizontal AND primer_mes_produccion IS NOT NULL
    GROUP BY 1
)
SELECT i.anio,
       round(i.total_mm)                         AS inversion_total_mm_usd,
       round(i.perforacion_mm)                   AS inversion_perforacion_mm_usd,
       p.pozos                                   AS pozos_conectados,
       round(i.perforacion_mm / p.pozos, 1)      AS mm_usd_por_pozo
FROM inversion i
JOIN pozos p USING (anio)
WHERE i.anio BETWEEN 2019 AND 2025
ORDER BY i.anio;

-- 12b. Por área, 2022 a 2025 (mínimo 20 pozos): costo por pozo y, en las áreas
--      petroleras, dólares de perforación por cada barril del primer año.
WITH inversion AS (
    SELECT area_id, sum(usd_millones) AS perforacion_mm
    FROM vm.inversion
    WHERE es_perforacion
      AND mes BETWEEN DATE '2022-01-01' AND DATE '2025-12-01'
    GROUP BY area_id
),
pozos AS (
    SELECT p.area_id,
           count(*)                                                      AS pozos,
           round(100.0 * count(*) FILTER (WHERE p.tipo_pozo = 'Petrolífero') / count(*)) AS pct_petroliferos,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY a.petroleo_12m_m3) AS petroleo_12m_m3
    FROM vm.pozo p
    LEFT JOIN vm.pozo_primer_anio a USING (pozo_id)
    WHERE p.es_horizontal
      AND p.primer_mes_produccion BETWEEN DATE '2022-01-01' AND DATE '2025-12-01'
    GROUP BY p.area_id
)
SELECT ar.nombre                                           AS area,
       z.pozos,
       z.pct_petroliferos,
       round(i.perforacion_mm)                             AS perforacion_mm_usd,
       round(i.perforacion_mm / z.pozos, 1)                AS mm_usd_por_pozo,
       CASE WHEN z.pct_petroliferos >= 80
            THEN round((i.perforacion_mm / z.pozos * 1e6 / (z.petroleo_12m_m3 * 6.2898))::numeric) END
                                                           AS usd_por_barril_del_primer_anio
FROM pozos z
JOIN inversion i USING (area_id)
JOIN vm.area ar USING (area_id)
WHERE z.pozos >= 20
ORDER BY z.pozos DESC;

-- 12c. Las cuatro áreas históricas (todas petroleras y de las que más
--      invierten), año por año: costo por pozo, petróleo del primer año y
--      dólares por barril del primer año.
WITH inversion AS (
    SELECT extract(year FROM i.mes)::integer AS anio, sum(i.usd_millones) AS perforacion_mm
    FROM vm.inversion i
    JOIN vm.area a USING (area_id)
    WHERE i.es_perforacion
      AND a.nombre IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR', 'BAJADA DEL PALO OESTE')
    GROUP BY 1
),
pozos AS (
    SELECT extract(year FROM p.primer_mes_produccion)::integer AS anio,
           count(*)                                                        AS pozos,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY y.petroleo_12m_m3)  AS petroleo_12m_m3
    FROM vm.pozo p
    JOIN vm.area a USING (area_id)
    LEFT JOIN vm.pozo_primer_anio y USING (pozo_id)
    WHERE p.es_horizontal
      AND p.primer_mes_produccion IS NOT NULL
      AND a.nombre IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR', 'BAJADA DEL PALO OESTE')
    GROUP BY 1
)
SELECT i.anio,
       z.pozos,
       round(i.perforacion_mm / z.pozos, 1)                                            AS mm_usd_por_pozo,
       round(z.petroleo_12m_m3::numeric)                                               AS petroleo_12m_m3,
       round((i.perforacion_mm / z.pozos * 1e6 / (z.petroleo_12m_m3 * 6.2898))::numeric) AS usd_por_barril_del_primer_anio
FROM inversion i
JOIN pozos z USING (anio)
WHERE i.anio BETWEEN 2019 AND 2025
ORDER BY i.anio;
