-- Pregunta 52: ¿los pozos pegados a un padre pierden la presión antes?
-- Cruza dos cosas que venían por separado: la distancia al pozo padre
-- (pregunta 7, vm.pozo_subsuelo) y el sistema con el que produce cada pozo
-- (pregunta 47, vm.produccion_mensual.tipo_extraccion).
--
-- La hipótesis: un pozo nuevo perforado al lado de uno que ya drenó parte de la
-- roca arranca con menos presión, y entonces deja de fluir solo antes. Mido qué
-- parte de los pozos seguía en surgencia natural entre los 25 y los 36 meses.
--
-- Dos decisiones que salen de mirar los datos:
--   * Solo Loma Campana, La Amarga Chica y Bandurria Sur, las tres de YPF. En
--     Bajada del Palo Oeste, Vista usa gas lift casi desde el primer mes (52a),
--     así que ahí el sistema de extracción no dice nada sobre la presión.
--   * Pozos de 2019 a 2023, que es donde las trayectorias cubren bien.

-- 52a. Por qué dejo afuera a Vista: parte de los meses del primer año en que
--      los pozos de cada operadora fluyen solos (pozos desde 2019).
SELECT a.operadora,
       count(DISTINCT e.pozo_id)                                                                  AS pozos,
       round(100.0 * count(*) FILTER (WHERE pm.tipo_extraccion = 'Surgencia Natural') / count(*)) AS pct_fluye_solo_el_primer_anio,
       round(100.0 * count(*) FILTER (WHERE pm.tipo_extraccion = 'Gas Lift') / count(*))          AS pct_gas_lift
FROM vm.produccion_edad e
JOIN vm.pozo_analisis a USING (pozo_id)
JOIN vm.produccion_mensual pm ON pm.pozo_id = e.pozo_id AND pm.mes = e.mes
WHERE e.mes_de_vida <= 12 AND e.petroleo_m3 > 0 AND a.anio_arranque >= 2019
GROUP BY 1
HAVING count(DISTINCT e.pozo_id) >= 20
ORDER BY 3;

-- 52b. La prueba: según la distancia al padre del mismo nivel.
WITH al_tercer_anio AS (
    SELECT e.pozo_id, avg((pm.tipo_extraccion = 'Surgencia Natural')::integer) AS fluye_solo
    FROM vm.produccion_edad e
    JOIN vm.produccion_mensual pm ON pm.pozo_id = e.pozo_id AND pm.mes = e.mes
    WHERE e.mes_de_vida BETWEEN 25 AND 36 AND e.petroleo_m3 > 0
    GROUP BY 1
    HAVING count(*) >= 6
)
SELECT CASE WHEN s.distancia_previo_mismo_nivel_m < 300 THEN '1. padre a menos de 300 m'
            WHEN s.distancia_previo_mismo_nivel_m < 500 THEN '2. padre entre 300 y 500 m'
            ELSE '3. padre a más de 500 m, o sin padre' END AS grupo,
       count(*)                                  AS pozos,
       round(100 * avg(t.fluye_solo))            AS pct_que_fluye_solo_al_tercer_anio,
       round(avg(s.anio_arranque), 1)            AS anio_medio_de_arranque,
       round(avg(s.petroleo_por_km_m3))          AS m3_por_km
FROM vm.pozo_subsuelo s
JOIN al_tercer_anio t USING (pozo_id)
WHERE s.anio_arranque BETWEEN 2019 AND 2023
  AND s.area IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR')
GROUP BY 1
ORDER BY 1;

-- 52c. Lo mismo área por área, para ver que no sea un efecto de mezclar áreas.
WITH al_tercer_anio AS (
    SELECT e.pozo_id, avg((pm.tipo_extraccion = 'Surgencia Natural')::integer) AS fluye_solo
    FROM vm.produccion_edad e
    JOIN vm.produccion_mensual pm ON pm.pozo_id = e.pozo_id AND pm.mes = e.mes
    WHERE e.mes_de_vida BETWEEN 25 AND 36 AND e.petroleo_m3 > 0
    GROUP BY 1
    HAVING count(*) >= 6
)
SELECT s.area,
       count(*) FILTER (WHERE s.distancia_previo_mismo_nivel_m < 500)                          AS pozos_con_padre_cerca,
       round(100 * avg(t.fluye_solo) FILTER (WHERE s.distancia_previo_mismo_nivel_m < 500))    AS pct_fluye_solo_con_padre,
       count(*) FILTER (WHERE s.distancia_previo_mismo_nivel_m >= 500
                           OR s.distancia_previo_mismo_nivel_m IS NULL)                        AS pozos_sin_padre_cerca,
       round(100 * avg(t.fluye_solo) FILTER (WHERE s.distancia_previo_mismo_nivel_m >= 500
                                                OR s.distancia_previo_mismo_nivel_m IS NULL))  AS pct_fluye_solo_sin_padre
FROM vm.pozo_subsuelo s
JOIN al_tercer_anio t USING (pozo_id)
WHERE s.anio_arranque BETWEEN 2019 AND 2023
  AND s.area IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR')
GROUP BY 1
ORDER BY 1;

-- 52d. Corrección a la pregunta 47: la caída de la surgencia por generación,
--      con todos los pozos, sin Vista y solo con YPF.
SELECT a.anio_arranque,
       count(DISTINCT e.pozo_id)                                                                  AS pozos,
       round(100.0 * count(*) FILTER (WHERE pm.tipo_extraccion = 'Surgencia Natural') / count(*)) AS todos,
       round(100.0 * count(*) FILTER (WHERE pm.tipo_extraccion = 'Surgencia Natural' AND a.operadora <> 'Vista')
                   / nullif(count(*) FILTER (WHERE a.operadora <> 'Vista'), 0))                   AS sin_vista,
       round(100.0 * count(*) FILTER (WHERE pm.tipo_extraccion = 'Surgencia Natural' AND a.operadora = 'YPF')
                   / nullif(count(*) FILTER (WHERE a.operadora = 'YPF'), 0))                      AS solo_ypf
FROM vm.produccion_edad e
JOIN vm.pozo_analisis a USING (pozo_id)
JOIN vm.produccion_mensual pm ON pm.pozo_id = e.pozo_id AND pm.mes = e.mes
WHERE e.mes_de_vida BETWEEN 25 AND 36 AND e.petroleo_m3 > 0
  AND a.anio_arranque BETWEEN 2018 AND 2023
GROUP BY 1
ORDER BY 1;
