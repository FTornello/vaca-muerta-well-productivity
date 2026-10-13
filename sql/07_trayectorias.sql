-- Trayectorias de pozos de Vaca Muerta: el recorrido de cada rama y el nivel
-- de la roca en el que navega. Se corre después de 03_capa_limpia.sql:
--   psql -d vaca_muerta -f sql/07_trayectorias.sql
--
-- Niveles de navegación (instructivo de Planos Base, Res. 319/93, página 33):
-- la formación se divide en seis unidades numeradas desde la base. U1 es Vaca
-- Muerta Inferior, U2 y U3 Vaca Muerta Medio, U4 a U6 Vaca Muerta Superior.
-- El detalle indica la parte de la unidad: 1 inferior, 2 medio, 3 superior.

-- Capa raw -------------------------------------------------------------------
DROP TABLE IF EXISTS raw.trayectorias;
CREATE TABLE raw.trayectorias (
    sigla                               text,
    idpo                                text,
    profundidad_final_total_mt          text,
    profundidad_vertical_mt             text,
    profundidad_sidetrack_mt            text,
    largo_rama_horizontal_mt            text,
    unidad_intervalo_navegacion         text,
    detalle_unidad_intervalo_navegacion text,
    pnl_md                              text,
    pnl_tvd                             text,
    termini                             text,
    termfin                             text,
    drilini                             text,
    drilfin                             text,
    tipopozo                            text,
    geometria                           text,
    geojson                             text
);
\copy raw.trayectorias FROM 'data/raw/trayectorias_vaca_muerta.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')


-- trayectoria: una fila por pozo del modelo que tiene trayectoria informada.
-- La fuente trae 460 filas sin código de pozo (idpo = 0): se enlazan por sigla.
-- Si un pozo aparece más de una vez se toma la fila con rama más larga.
DROP TABLE IF EXISTS vm.trayectoria_punto;
DROP TABLE IF EXISTS vm.trayectoria;
CREATE TABLE vm.trayectoria (
    pozo_id             integer PRIMARY KEY REFERENCES vm.pozo,
    unidad              integer,     -- 1 a 6; nulo si no se informó
    detalle             integer,     -- 1 inferior, 2 medio, 3 superior; nulo si no se informó
    nivel               text,        -- por ejemplo 'U1 medio'
    rama_m              numeric,
    profundidad_rama_m  numeric,     -- profundidad vertical donde empieza la rama
    geojson             jsonb NOT NULL
);

WITH enlazada AS (
    SELECT coalesce(p_id.pozo_id, p_sigla.pozo_id) AS pozo_id, t.*
    FROM raw.trayectorias t
    LEFT JOIN vm.pozo p_id    ON t.idpo <> '0' AND p_id.pozo_id = t.idpo::integer
    LEFT JOIN vm.pozo p_sigla ON t.idpo = '0'  AND p_sigla.sigla = t.sigla
),
una_por_pozo AS (
    SELECT DISTINCT ON (pozo_id) *
    FROM enlazada
    WHERE pozo_id IS NOT NULL
    ORDER BY pozo_id, largo_rama_horizontal_mt::numeric DESC NULLS LAST
)
INSERT INTO vm.trayectoria
SELECT pozo_id,
       nullif(unidad_intervalo_navegacion::numeric::integer, 0),
       nullif(detalle_unidad_intervalo_navegacion::numeric::integer % 10, 0),
       CASE WHEN nullif(unidad_intervalo_navegacion::numeric::integer, 0) IS NOT NULL
            THEN 'U' || unidad_intervalo_navegacion::numeric::integer
                 || coalesce(' ' || (ARRAY['inferior', 'medio', 'superior'])
                                    [nullif(detalle_unidad_intervalo_navegacion::numeric::integer % 10, 0)], '')
       END,
       nullif(largo_rama_horizontal_mt::numeric, 0),
       CASE WHEN pnl_tvd::numeric BETWEEN 1000 AND 5000 THEN pnl_tvd::numeric END,
       geojson::jsonb
FROM una_por_pozo;


-- trayectoria_punto: la rama horizontal de cada pozo como una serie de puntos
-- cada 50 metros, en coordenadas planas (metros al este y al norte de un punto
-- fijo). Sirve para medir distancias entre ramas vecinas.
--
-- La fuente da el recorrido completo desde la boca del pozo, sin profundidad.
-- Para quedarse con la rama se recorre el trazado desde el fondo hacia atrás
-- y se conservan los puntos hasta completar el largo de rama informado.
CREATE TABLE vm.trayectoria_punto (
    pozo_id integer NOT NULL REFERENCES vm.trayectoria,
    orden   integer NOT NULL,
    x_m     numeric NOT NULL,
    y_m     numeric NOT NULL,
    PRIMARY KEY (pozo_id, orden)
);

WITH vertices AS (
    SELECT t.pozo_id,
           t.rama_m,
           v.ordinality                                                    AS n,
           ((v.punto ->> 0)::numeric + 68.6) * 111320 * cos(radians(-38.3)) AS x_m,
           ((v.punto ->> 1)::numeric + 38.3) * 110570                       AS y_m
    FROM vm.trayectoria t
    CROSS JOIN LATERAL jsonb_array_elements(t.geojson -> 'coordinates' -> 0)
               WITH ORDINALITY AS v(punto, ordinality)
),
tramos AS (
    SELECT *,
           coalesce(sqrt(power(x_m - lead(x_m) OVER w, 2) + power(y_m - lead(y_m) OVER w, 2)), 0) AS largo_al_siguiente
    FROM vertices
    WINDOW w AS (PARTITION BY pozo_id ORDER BY n)
),
desde_el_fondo AS (
    SELECT *,
           sum(largo_al_siguiente) OVER (PARTITION BY pozo_id ORDER BY n DESC) AS metros_desde_el_fondo
    FROM tramos
),
rama AS (
    SELECT *,
           floor(metros_desde_el_fondo / 50) AS tramo_50m
    FROM desde_el_fondo
    WHERE rama_m IS NOT NULL
      AND metros_desde_el_fondo <= rama_m
)
INSERT INTO vm.trayectoria_punto
SELECT pozo_id,
       row_number() OVER (PARTITION BY pozo_id ORDER BY tramo_50m),
       round(x_m::numeric, 1),
       round(y_m::numeric, 1)
FROM (
    SELECT DISTINCT ON (pozo_id, tramo_50m) pozo_id, tramo_50m, x_m, y_m
    FROM rama
    ORDER BY pozo_id, tramo_50m, n
) un_punto_por_tramo;

ANALYZE vm.trayectoria;
ANALYZE vm.trayectoria_punto;


-- pozo_vecindad: para cada pozo con rama, qué tan cerca tiene otras ramas.
-- Para cada punto de la rama se busca el punto más cercano de otro pozo (hasta
-- 1.500 m) y se toma la mediana a lo largo de la rama. Las distancias son en
-- planta, así que dos ramas apiladas a distinta profundidad figuran muy cerca;
-- por eso cada medida se calcula también solo contra ramas del mismo nivel.
--   distancia_vecino_m:  contra cualquier otro pozo, sin importar cuándo se hizo.
--   distancia_previo_m:  solo contra pozos que ya llevaban al menos 12 meses
--                        produciendo cuando este arrancó (pozos "padres").
--   ..._mismo_nivel_m:   lo mismo, pero solo contra ramas de la misma unidad.
-- Queda nulo si menos de la mitad de la rama tiene un vecino dentro del radio.
DROP TABLE IF EXISTS vm.pozo_vecindad;
CREATE TABLE vm.pozo_vecindad AS
WITH puntos AS (
    -- cada punto con la celda de 1.500 m en la que cae
    SELECT k.pozo_id, k.orden, k.x_m, k.y_m,
           floor(k.x_m / 1500)::integer AS celda_x,
           floor(k.y_m / 1500)::integer AS celda_y,
           p.primer_mes_produccion,
           t.unidad
    FROM vm.trayectoria_punto k
    JOIN vm.trayectoria t USING (pozo_id)
    JOIN vm.pozo p USING (pozo_id)
),
celdas_vecinas AS (
    -- las 9 celdas alrededor de cada punto: alcanza para cubrir 1.500 m
    SELECT dx, dy
    FROM generate_series(-1, 1) AS dx
    CROSS JOIN generate_series(-1, 1) AS dy
),
pares AS (
    -- cada punto contra los puntos de otros pozos en esas celdas
    SELECT a.pozo_id,
           a.orden,
           b.unidad = a.unidad AS mismo_nivel,
           b.primer_mes_produccion <= a.primer_mes_produccion - INTERVAL '12 months' AS es_previo,
           sqrt(power(a.x_m - b.x_m, 2) + power(a.y_m - b.y_m, 2)) AS distancia_m
    FROM puntos a
    CROSS JOIN celdas_vecinas c
    JOIN puntos b
      ON b.celda_x = a.celda_x + c.dx
     AND b.celda_y = a.celda_y + c.dy
     AND b.pozo_id <> a.pozo_id
    WHERE power(a.x_m - b.x_m, 2) + power(a.y_m - b.y_m, 2) <= 1500 * 1500
),
por_punto AS (
    SELECT pozo_id,
           orden,
           min(distancia_m)                                           AS al_vecino,
           min(distancia_m) FILTER (WHERE mismo_nivel)                AS al_vecino_mismo_nivel,
           min(distancia_m) FILTER (WHERE es_previo)                  AS al_previo,
           min(distancia_m) FILTER (WHERE es_previo AND mismo_nivel)  AS al_previo_mismo_nivel
    FROM pares
    GROUP BY pozo_id, orden
),
largo AS (
    SELECT pozo_id, count(*) AS puntos FROM vm.trayectoria_punto GROUP BY pozo_id
)
SELECT l.pozo_id,
       CASE WHEN count(pp.al_vecino) >= l.puntos / 2.0
            THEN round(percentile_cont(0.5) WITHIN GROUP (ORDER BY pp.al_vecino)::numeric) END             AS distancia_vecino_m,
       CASE WHEN count(pp.al_vecino_mismo_nivel) >= l.puntos / 2.0
            THEN round(percentile_cont(0.5) WITHIN GROUP (ORDER BY pp.al_vecino_mismo_nivel)::numeric) END AS distancia_vecino_mismo_nivel_m,
       CASE WHEN count(pp.al_previo) >= l.puntos / 2.0
            THEN round(percentile_cont(0.5) WITHIN GROUP (ORDER BY pp.al_previo)::numeric) END             AS distancia_previo_m,
       CASE WHEN count(pp.al_previo_mismo_nivel) >= l.puntos / 2.0
            THEN round(percentile_cont(0.5) WITHIN GROUP (ORDER BY pp.al_previo_mismo_nivel)::numeric) END AS distancia_previo_mismo_nivel_m
FROM largo l
LEFT JOIN por_punto pp USING (pozo_id)
GROUP BY l.pozo_id, l.puntos;

ALTER TABLE vm.pozo_vecindad ADD PRIMARY KEY (pozo_id);
ALTER TABLE vm.pozo_vecindad ADD FOREIGN KEY (pozo_id) REFERENCES vm.trayectoria;
ANALYZE vm.pozo_vecindad;


-- pozo_subsuelo: la tabla de trabajo de la pregunta 7. Los pozos de
-- pozo_analisis con diseño confiable que navegan en U1 o U2 (el 96 % de los que
-- tienen trayectoria), con su nivel, sus distancias a vecinos y el petróleo por
-- kilómetro de rama.
CREATE OR REPLACE VIEW vm.pozo_subsuelo AS
SELECT a.pozo_id,
       a.area,
       a.area IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR', 'BAJADA DEL PALO OESTE') AS area_historica,
       a.operadora,
       a.anio_arranque,
       a.petroleo_12m_m3,
       a.rama_m,
       a.arena_tn,
       a.petroleo_12m_m3 / a.rama_m * 1000 AS petroleo_por_km_m3,
       t.unidad,
       t.nivel,
       v.distancia_vecino_mismo_nivel_m,
       v.distancia_previo_mismo_nivel_m
FROM vm.pozo_analisis a
JOIN vm.trayectoria t USING (pozo_id)
JOIN vm.pozo_vecindad v USING (pozo_id)
WHERE a.diseno_confiable
  AND t.unidad IN (1, 2);
