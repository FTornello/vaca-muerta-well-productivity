-- Pregunta 51: ¿qué tan completos están los datos?
-- Todo el proyecto cruza cuatro planillas que publican cosas distintas con
-- demoras distintas: producción, pozos, fracturas y trayectorias. Acá mido qué
-- parte de los pozos tiene cada dato, para saber sobre qué años puedo afirmar
-- cosas y sobre cuáles no.

-- 51a. Pozos petrolíferos que arrancaron cada año: qué parte tiene dato de
--      fractura, qué parte tiene un diseño que considero confiable, qué parte
--      tiene trayectoria y qué parte entra en vm.pozo_analisis, la vista que
--      usan casi todas las preguntas sobre el diseño del pozo.
SELECT extract(year FROM p.primer_mes_produccion)::integer                                  AS anio,
       count(*)                                                                             AS pozos,
       round(100.0 * count(f.pozo_id) / count(*))                                           AS pct_con_fractura,
       round(100.0 * count(a.pozo_id) FILTER (WHERE a.diseno_confiable) / count(*))         AS pct_con_diseno_confiable,
       round(100.0 * count(t.pozo_id) / count(*))                                           AS pct_con_trayectoria,
       round(100.0 * count(a.pozo_id) / count(*))                                           AS pct_en_pozo_analisis
FROM vm.pozo p
LEFT JOIN (SELECT DISTINCT pozo_id FROM vm.fractura) f USING (pozo_id)
LEFT JOIN vm.pozo_analisis a USING (pozo_id)
LEFT JOIN vm.trayectoria t USING (pozo_id)
WHERE p.tipo_pozo = 'Petrolífero' AND p.primer_mes_produccion >= DATE '2014-01-01'
GROUP BY 1
ORDER BY 1;

-- 51b. La demora de la planilla de fracturas: pozos horizontales que empiezan a
--      producir cada mes y fracturas informadas como terminadas ese mes. Si la
--      fuente estuviera al día, las dos columnas irían parejas.
SELECT to_char(m, 'YYYY-MM')                                                                         AS mes,
       (SELECT count(*) FROM vm.pozo WHERE primer_mes_produccion = m AND es_horizontal)              AS pozos_que_arrancan,
       (SELECT count(*) FROM vm.fractura WHERE date_trunc('month', fecha_fin) = m)                   AS fracturas_terminadas
FROM generate_series(DATE '2025-09-01', DATE '2026-08-01', INTERVAL '1 month') AS m
ORDER BY 1;

-- 51c. Hasta qué mes llega cada fuente que depende del tiempo.
SELECT 'producción por pozo' AS fuente, to_char(max(mes), 'YYYY-MM') AS ultimo_dato FROM vm.produccion_mensual
UNION ALL SELECT 'fracturas',                    to_char(max(fecha_fin), 'YYYY-MM') FROM vm.fractura
UNION ALL SELECT 'oleoducto troncal',            to_char(max(mes), 'YYYY-MM') FROM vm.oleoducto_troncal
UNION ALL SELECT 'exportaciones',                to_char(max(mes), 'YYYY-MM') FROM vm.exportacion
UNION ALL SELECT 'precio del gas',               to_char(max(mes), 'YYYY-MM') FROM vm.precio_gas
UNION ALL SELECT 'regalías de petróleo',         to_char(max(mes), 'YYYY-MM') FROM vm.regalia_petroleo
UNION ALL SELECT 'inversiones',                  to_char(max(mes), 'YYYY-MM') FROM vm.inversion
UNION ALL SELECT 'empleo',                       to_char(max(mes), 'YYYY-MM') FROM vm.empleo_neuquen
UNION ALL SELECT 'venteo detectado',             to_char(max(mes), 'YYYY-MM') FROM vm.venteo_detectado
UNION ALL SELECT 'producción y refinación del país', to_char(max(mes) FILTER (WHERE petroleo_producido_km3 IS NOT NULL), 'YYYY-MM') FROM vm.pais_energia
UNION ALL SELECT 'crudo procesado por refinería', to_char(max(mes), 'YYYY-MM') FROM vm.crudo_procesado
UNION ALL SELECT 'comercio exterior de energía', to_char(max(mes), 'YYYY-MM') FROM vm.comercio_energia
UNION ALL SELECT 'shale de Estados Unidos',      to_char(max(mes), 'YYYY-MM') FROM vm.eeuu_tight_oil
UNION ALL SELECT 'reservas (anual)',             max(anio)::text FROM vm.reserva
UNION ALL SELECT 'pronósticos (año del informe)', max(anio_informe)::text FROM vm.pronostico_petroleo
ORDER BY 2, 1;

-- 51d. ¿Vaca Muerta es solo Neuquén? Pozos por provincia y lo que producían
--      en agosto de 2026, en miles de barriles por día.
SELECT p.provincia,
       count(*)                                                    AS pozos,
       min(extract(year FROM p.primer_mes_produccion))::integer    AS primer_pozo_en,
       round(coalesce(sum(pm.petroleo_m3), 0) * 6.2898 / 31 / 1000, 1) AS miles_bbl_dia_agosto_2026
FROM vm.pozo p
LEFT JOIN vm.produccion_mensual pm ON pm.pozo_id = p.pozo_id AND pm.mes = DATE '2026-08-01'
GROUP BY 1
ORDER BY 2 DESC;
