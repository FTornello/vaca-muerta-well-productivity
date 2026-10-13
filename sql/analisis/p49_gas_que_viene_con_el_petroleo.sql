-- Pregunta 49: ¿los pozos de petróleo traen cada vez más gas?
-- En la pregunta 9 vi que el gas que sale junto con el petróleo se duplicó en
-- dos años y medio. Puede ser solo porque hay más pozos, o porque cada pozo
-- trae más gas a medida que envejece. Mido la relación gas/petróleo: m3 de gas
-- por cada m3 de petróleo. Solo pozos petrolíferos.

-- 49a. La relación gas/petróleo según la edad del pozo, por año de arranque.
SELECT a.anio_arranque,
       count(DISTINCT e.pozo_id)                                                                          AS pozos,
       round((sum(e.gas_miles_m3) FILTER (WHERE e.mes_de_vida <= 6) * 1000
            / nullif(sum(e.petroleo_m3) FILTER (WHERE e.mes_de_vida <= 6), 0))::numeric)                  AS primeros_6_meses,
       round((sum(e.gas_miles_m3) FILTER (WHERE e.mes_de_vida BETWEEN 13 AND 24) * 1000
            / nullif(sum(e.petroleo_m3) FILTER (WHERE e.mes_de_vida BETWEEN 13 AND 24), 0))::numeric)     AS segundo_anio,
       round((sum(e.gas_miles_m3) FILTER (WHERE e.mes_de_vida BETWEEN 37 AND 48) * 1000
            / nullif(sum(e.petroleo_m3) FILTER (WHERE e.mes_de_vida BETWEEN 37 AND 48), 0))::numeric)     AS cuarto_anio,
       round((sum(e.gas_miles_m3) FILTER (WHERE e.mes_de_vida BETWEEN 61 AND 72) * 1000
            / nullif(sum(e.petroleo_m3) FILTER (WHERE e.mes_de_vida BETWEEN 61 AND 72), 0))::numeric)     AS sexto_anio
FROM vm.pozo_analisis a
JOIN vm.produccion_edad e USING (pozo_id)
WHERE a.anio_arranque BETWEEN 2016 AND 2025
GROUP BY 1
ORDER BY 1;

-- 49b. La relación gas/petróleo de todos los pozos petrolíferos juntos, año
--      por año, y cuánto gas dan en total (millones de m3 por día). 2026 llega
--      hasta agosto.
SELECT extract(year FROM pm.mes)::integer                                  AS anio,
       round((sum(pm.gas_miles_m3) * 1000 / sum(pm.petroleo_m3))::numeric) AS m3_de_gas_por_m3_de_petroleo,
       round(sum(pm.gas_miles_m3) / 1000 / (count(DISTINCT pm.mes) * 30.44), 1) AS gas_asociado_mm_m3_dia,
       round(sum(pm.petroleo_m3) * 6.2898 / (count(DISTINCT pm.mes) * 30.44) / 1000) AS petroleo_miles_bbl_dia
FROM vm.produccion_mensual pm
JOIN vm.pozo po USING (pozo_id)
WHERE po.tipo_pozo = 'Petrolífero' AND pm.mes >= DATE '2018-01-01'
GROUP BY 1
ORDER BY 1;
