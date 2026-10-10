-- Exporta a dashboard/datos/ las tablas que consume el tablero.
-- Correr desde la raíz del proyecto:
--   psql -d vaca_muerta -f sql/06_exportar_dashboard.sql

-- pozos.csv: una fila por pozo horizontal petrolífero con 12 meses cumplidos.
-- Es la tabla principal del tablero (preguntas 1, 2 y 3).
\copy (SELECT a.pozo_id, a.sigla, a.area, a.operadora, a.anio_arranque, p.latitud, p.longitud, round(a.petroleo_12m_m3) AS petroleo_12m_m3, a.rama_m, a.etapas, round(a.arena_tn) AS arena_tn, a.diseno_confiable, CASE WHEN a.diseno_confiable THEN round(a.petroleo_12m_m3 / a.rama_m * 1000) END AS petroleo_por_km_m3, CASE WHEN a.diseno_confiable THEN round(a.arena_tn / a.rama_m, 2) END AS arena_tn_por_m FROM vm.pozo_analisis a JOIN vm.pozo p USING (pozo_id) ORDER BY a.pozo_id) TO 'dashboard/datos/pozos.csv' WITH (FORMAT csv, HEADER true)

-- curva_por_edad.csv: petróleo por mes de vida de cada pozo, primeros 24 meses
-- (pregunta 1, curva típica).
\copy (SELECT e.pozo_id, a.anio_arranque, a.area, a.operadora, e.mes_de_vida, round(e.petroleo_m3) AS petroleo_m3 FROM vm.produccion_edad e JOIN vm.pozo_analisis a USING (pozo_id) WHERE e.mes_de_vida <= 24 ORDER BY e.pozo_id, e.mes_de_vida) TO 'dashboard/datos/curva_por_edad.csv' WITH (FORMAT csv, HEADER true)

-- produccion_por_area.csv: producción mensual de toda Vaca Muerta por área y
-- operadora (pregunta 4 y evolución general).
\copy (SELECT m.mes, a.nombre AS area, o.nombre AS operadora, count(*) FILTER (WHERE m.petroleo_m3 > 0 OR m.gas_miles_m3 > 0) AS pozos_activos, round(sum(m.petroleo_m3)) AS petroleo_m3, round(sum(m.gas_miles_m3)) AS gas_miles_m3 FROM vm.produccion_mensual m JOIN vm.pozo p USING (pozo_id) JOIN vm.area a USING (area_id) JOIN vm.empresa e USING (empresa_codigo) JOIN vm.operadora o USING (operadora_id) WHERE m.mes >= DATE '2012-01-01' GROUP BY m.mes, a.nombre, o.nombre HAVING sum(m.petroleo_m3) > 0 OR sum(m.gas_miles_m3) > 0 ORDER BY m.mes, a.nombre) TO 'dashboard/datos/produccion_por_area.csv' WITH (FORMAT csv, HEADER true)
