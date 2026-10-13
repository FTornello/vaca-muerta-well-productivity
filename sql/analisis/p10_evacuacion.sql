-- Pregunta 10: ¿el oleoducto alcanza para sacar el petróleo de Vaca Muerta?
-- Compara la producción de petróleo de Vaca Muerta con lo que transporta el
-- oleoducto troncal Allen - Puerto Rosales (Oldelval), en miles de barriles por
-- día. 1 m3 = 6,2898 barriles.
-- Por el troncal también pasa petróleo convencional de la cuenca, y Vaca Muerta
-- tiene otras salidas (refinerías de la zona, oleoducto a Chile), así que las
-- dos columnas no tienen por qué coincidir.

-- 10a. Promedio por año.
WITH produccion AS (
    SELECT mes, sum(petroleo_m3) AS petroleo_m3
    FROM vm.produccion_mensual
    GROUP BY mes
)
SELECT extract(year FROM o.mes)::integer                                                        AS anio,
       round(avg(p.petroleo_m3 * 6.2898 / extract(day FROM o.mes + INTERVAL '1 month - 1 day') / 1000)) AS produccion_vaca_muerta,
       round(avg((o.cano_original_m3 + o.duplicar_m3) * 6.2898
                 / extract(day FROM o.mes + INTERVAL '1 month - 1 day') / 1000))                AS oleoducto_troncal
FROM vm.oleoducto_troncal o
JOIN produccion p USING (mes)
WHERE o.mes >= DATE '2020-01-01'
GROUP BY 1
ORDER BY 1;

-- 10b. Mes a mes desde 2024, separando el caño original del Duplicar.
SELECT to_char(mes, 'YYYY-MM')                                                                  AS mes,
       round(cano_original_m3 * 6.2898 / extract(day FROM mes + INTERVAL '1 month - 1 day') / 1000) AS cano_original,
       round(duplicar_m3      * 6.2898 / extract(day FROM mes + INTERVAL '1 month - 1 day') / 1000) AS duplicar,
       round((cano_original_m3 + duplicar_m3) * 6.2898
             / extract(day FROM mes + INTERVAL '1 month - 1 day') / 1000)                       AS total
FROM vm.oleoducto_troncal
WHERE mes >= DATE '2024-01-01'
ORDER BY 1;
