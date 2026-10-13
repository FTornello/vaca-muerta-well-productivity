-- Pregunta 11: ¿el precio del gas acompaña la caída de primavera?
-- Completa la pregunta 9. Precio promedio del gas de la cuenca Neuquina, en
-- dólares por millón de BTU, en el pico de invierno (julio y agosto) y en el
-- valle de primavera (octubre y noviembre), junto al volumen de los pozos de gas.

WITH gas AS (
    SELECT m.mes, sum(m.gas_miles_m3) AS gas_miles_m3
    FROM vm.produccion_mensual m
    JOIN vm.pozo p USING (pozo_id)
    WHERE p.tipo_pozo = 'Gasífero'
    GROUP BY m.mes
),
por_mes AS (
    SELECT extract(year FROM g.mes)::integer  AS anio,
           extract(month FROM g.mes)::integer AS nro_mes,
           g.gas_miles_m3 / extract(day FROM g.mes + INTERVAL '1 month - 1 day') / 1000 AS mm3_dia,
           pr.precio_promedio,
           pr.precio_exportacion
    FROM gas g
    JOIN vm.precio_gas pr USING (mes)
)
SELECT anio,
       round(avg(mm3_dia)            FILTER (WHERE nro_mes IN (7, 8))::numeric, 1)   AS volumen_invierno,
       round(avg(mm3_dia)            FILTER (WHERE nro_mes IN (10, 11))::numeric, 1) AS volumen_primavera,
       round(avg(precio_promedio)    FILTER (WHERE nro_mes IN (7, 8)), 2)            AS precio_invierno,
       round(avg(precio_promedio)    FILTER (WHERE nro_mes IN (10, 11)), 2)          AS precio_primavera,
       round(100 * (1 - avg(precio_promedio) FILTER (WHERE nro_mes IN (10, 11))
                      / avg(precio_promedio) FILTER (WHERE nro_mes IN (7, 8))))      AS caida_del_precio_pct,
       round(avg(precio_exportacion) FILTER (WHERE nro_mes IN (10, 11)), 2)          AS precio_exportacion_primavera
FROM por_mes
WHERE anio BETWEEN 2019 AND 2025
GROUP BY anio
ORDER BY anio;
