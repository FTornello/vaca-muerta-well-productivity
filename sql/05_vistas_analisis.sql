-- Vistas de apoyo para el análisis. Se crean una vez y las usan todas las preguntas.
--   psql -d vaca_muerta -f sql/05_vistas_analisis.sql

-- produccion_edad: la producción mensual con la edad del pozo.
-- mes_de_vida = 1 es el primer mes con producción. Se calcula por diferencia de
-- fechas y no numerando filas, porque 169 pozos tienen meses sin informar y
-- numerar filas les correría la edad.
CREATE OR REPLACE VIEW vm.produccion_edad AS
SELECT m.pozo_id,
       m.mes,
       (EXTRACT(YEAR  FROM age(m.mes, p.primer_mes_produccion)) * 12
      + EXTRACT(MONTH FROM age(m.mes, p.primer_mes_produccion)))::integer + 1 AS mes_de_vida,
       m.petroleo_m3,
       m.gas_miles_m3,
       m.agua_m3,
       m.dias_activo
FROM vm.produccion_mensual m
JOIN vm.pozo p USING (pozo_id)
WHERE m.mes >= p.primer_mes_produccion;

-- pozo_primer_anio: una fila por pozo con lo que produjo en sus primeros 12
-- meses. Solo incluye pozos que ya cumplieron 12 meses a la fecha del último
-- dato, para no comparar un año entero contra uno incompleto.
CREATE OR REPLACE VIEW vm.pozo_primer_anio AS
SELECT e.pozo_id,
       EXTRACT(YEAR FROM p.primer_mes_produccion)::integer AS anio_arranque,
       sum(e.petroleo_m3)  AS petroleo_12m_m3,
       sum(e.gas_miles_m3) AS gas_12m_miles_m3
FROM vm.produccion_edad e
JOIN vm.pozo p USING (pozo_id)
WHERE e.mes_de_vida <= 12
  AND p.primer_mes_produccion <= (SELECT max(mes) FROM vm.produccion_mensual) - INTERVAL '11 months'
GROUP BY e.pozo_id, p.primer_mes_produccion;

-- pozo_analisis: la tabla de trabajo de las preguntas 1 a 5. Una fila por pozo
-- horizontal petrolífero que ya cumplió 12 meses, con su lugar, su operadora
-- inicial, lo que produjo el primer año y el diseño de su fractura original.
-- diseno_confiable es falso si falta la fractura, la rama o la arena están en
-- cero, o la fila quedó marcada como sospechosa en la limpieza.
CREATE OR REPLACE VIEW vm.pozo_analisis AS
SELECT p.pozo_id,
       p.sigla,
       ar.nombre                                   AS area,
       o.nombre                                    AS operadora,
       a.anio_arranque,
       a.petroleo_12m_m3,
       f.longitud_rama_m                           AS rama_m,
       f.etapas,
       f.arena_nacional_tn + f.arena_importada_tn  AS arena_tn,
       coalesce(f.longitud_rama_m > 0
            AND f.arena_nacional_tn + f.arena_importada_tn > 0
            AND NOT f.dato_sospechoso, false)      AS diseno_confiable
FROM vm.pozo p
JOIN vm.pozo_primer_anio a USING (pozo_id)
JOIN vm.area ar USING (area_id)
JOIN vm.empresa e ON e.empresa_codigo = p.empresa_inicial
JOIN vm.operadora o USING (operadora_id)
LEFT JOIN vm.fractura f ON f.pozo_id = p.pozo_id AND f.nro_fractura = 1
WHERE p.es_horizontal
  AND p.tipo_pozo = 'Petrolífero';
