-- Curva tipo: cómo se reparte en el tiempo la producción de un pozo petrolero,
-- medida contra lo que produce en su primer año. Es el insumo para estimar
-- cuánto produce un pozo en toda su vida (pregunta 22).
--   psql -d vaca_muerta -f sql/11_curva_tipo.sql
--
-- Para cada año de arranque se promedia el petróleo de cada mes de vida entre
-- TODOS los pozos del año (un pozo parado cuenta como cero), y se divide por el
-- acumulado promedio de los primeros 12 meses. Solo se usan las edades que
-- todos los pozos de ese año ya cumplieron, para no mezclar pozos de distinta
-- antigüedad.

DROP TABLE IF EXISTS vm.curva_tipo;
CREATE TABLE vm.curva_tipo AS
WITH pozos AS (
    SELECT pozo_id, anio_arranque
    FROM vm.pozo_analisis
    WHERE anio_arranque BETWEEN 2016 AND 2023
),
cantidad AS (
    SELECT anio_arranque,
           count(*) AS pozos,
           -- meses cumplidos por el pozo más nuevo del año (el que arrancó en diciembre)
           (extract(year  FROM age((SELECT max(mes) FROM vm.produccion_mensual), make_date(anio_arranque, 12, 1))) * 12
          + extract(month FROM age((SELECT max(mes) FROM vm.produccion_mensual), make_date(anio_arranque, 12, 1))))::integer + 1 AS edad_maxima
    FROM pozos
    GROUP BY anio_arranque
),
por_edad AS (
    SELECT p.anio_arranque, e.mes_de_vida, sum(e.petroleo_m3) AS petroleo_m3
    FROM pozos p
    JOIN vm.produccion_edad e USING (pozo_id)
    GROUP BY p.anio_arranque, e.mes_de_vida
),
primer_anio AS (
    SELECT anio_arranque, sum(petroleo_m3) AS petroleo_12m_m3
    FROM por_edad
    WHERE mes_de_vida <= 12
    GROUP BY anio_arranque
)
SELECT e.anio_arranque,
       c.pozos,
       e.mes_de_vida,
       round(e.petroleo_m3 / c.pozos, 1)                        AS caudal_m3_por_mes,
       round(e.petroleo_m3 / a.petroleo_12m_m3, 5)              AS caudal_sobre_primer_anio,
       round(sum(e.petroleo_m3) OVER (PARTITION BY e.anio_arranque ORDER BY e.mes_de_vida)
             / a.petroleo_12m_m3, 4)                            AS acumulado_sobre_primer_anio
FROM por_edad e
JOIN cantidad c USING (anio_arranque)
JOIN primer_anio a USING (anio_arranque)
WHERE e.mes_de_vida <= c.edad_maxima;

ALTER TABLE vm.curva_tipo ADD PRIMARY KEY (anio_arranque, mes_de_vida);

\copy (SELECT * FROM vm.curva_tipo ORDER BY anio_arranque, mes_de_vida) TO 'data/curva_tipo.csv' WITH (FORMAT csv, HEADER true)
