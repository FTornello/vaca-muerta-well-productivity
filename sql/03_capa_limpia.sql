-- Capa limpia (esquema vm): modelo relacional acotado a la formación Vaca Muerta.
-- Se reconstruye completa desde la capa raw cada vez que se corre:
--   psql -d vaca_muerta -f sql/03_capa_limpia.sql
--
-- Unidades de la fuente: petróleo y agua en m3, gas en miles de m3.

DROP SCHEMA IF EXISTS vm CASCADE;
CREATE SCHEMA vm;


-- ---------------------------------------------------------------------------
-- operadora: una fila por grupo empresario.
-- empresa:   una fila por razón social que informa producción (48), con el
--            grupo al que pertenece.
-- La agrupación es manual y conservadora: solo se unen razones sociales de la
-- misma marca (Vista tiene tres, Pan American, Pluspetrol, Wintershall y
-- GeoPark dos, YSUR era subsidiaria de YPF). No se siguen compras entre
-- empresas distintas.
-- ---------------------------------------------------------------------------
CREATE TABLE vm.operadora (
    operadora_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       text NOT NULL UNIQUE
);

CREATE TABLE vm.empresa (
    empresa_codigo text PRIMARY KEY,
    razon_social   text NOT NULL,
    operadora_id   integer NOT NULL REFERENCES vm.operadora
);

CREATE TEMP TABLE grupo_manual (empresa_codigo text PRIMARY KEY, operadora text NOT NULL);
INSERT INTO grupo_manual VALUES
    ('YPF',  'YPF'),
    ('YSUR', 'YPF'),
    ('VST',  'Vista'),
    ('VIS',  'Vista'),
    ('VOG',  'Vista'),
    ('PAL',  'Pan American Energy'),
    ('PAE',  'Pan American Energy'),
    ('PLU',  'Pluspetrol'),
    ('PCN',  'Pluspetrol'),
    ('WIN',  'Wintershall'),
    ('WDA',  'Wintershall'),
    ('GEA',  'GeoPark'),
    ('GAL',  'GeoPark'),
    ('TPT',  'Tecpetrol'),
    ('SHE',  'Shell'),
    ('TAU',  'TotalEnergies'),
    ('PAM',  'Pampa Energía'),
    ('PGR',  'Phoenix Global Resources'),
    ('PTRE', 'Petrolera El Trébol'),
    ('CHE',  'Chevron'),
    ('EMEA', 'ExxonMobil'),
    ('KILW', 'Kilwer'),
    ('OGDV', 'O&G Developments'),
    ('VMI',  'Vaca Muerta Inversiones'),
    ('APS',  'Capex');

CREATE TEMP TABLE empresa_fuente AS
SELECT DISTINCT ON (idempresa)
       idempresa AS empresa_codigo,
       empresa   AS razon_social
FROM raw.produccion
WHERE lower(formacion) = 'vaca muerta'
ORDER BY idempresa, fecha_data DESC;

INSERT INTO vm.operadora (nombre)
SELECT DISTINCT coalesce(g.operadora, e.razon_social)
FROM empresa_fuente e
LEFT JOIN grupo_manual g USING (empresa_codigo)
ORDER BY 1;

INSERT INTO vm.empresa (empresa_codigo, razon_social, operadora_id)
SELECT e.empresa_codigo, e.razon_social, o.operadora_id
FROM empresa_fuente e
LEFT JOIN grupo_manual g USING (empresa_codigo)
JOIN vm.operadora o ON o.nombre = coalesce(g.operadora, e.razon_social);


-- ---------------------------------------------------------------------------
-- area: una fila por concesión o permiso (Loma Campana, Fortín de Piedra...).
-- ---------------------------------------------------------------------------
CREATE TABLE vm.area (
    area_id text PRIMARY KEY,
    nombre  text NOT NULL
);

INSERT INTO vm.area (area_id, nombre)
SELECT DISTINCT idareapermisoconcesion,
       regexp_replace(trim(areapermisoconcesion), '\s+', ' ', 'g')
FROM raw.produccion
WHERE lower(formacion) = 'vaca muerta';


-- ---------------------------------------------------------------------------
-- pozo: una fila por pozo.
-- Los atributos fijos salen del último mes informado. El tipo de pozo cambia
-- en el tiempo (un pozo parado pasa a "Otro tipo"), así que se toma el más
-- frecuente entre los meses en que produjo.
-- ---------------------------------------------------------------------------
CREATE TABLE vm.pozo (
    pozo_id                  integer PRIMARY KEY,
    sigla                    text NOT NULL,
    area_id                  text NOT NULL REFERENCES vm.area,
    yacimiento               text,
    provincia                text NOT NULL,
    tipo_pozo                text,
    es_horizontal            boolean NOT NULL,
    profundidad_m            numeric,
    longitud                 numeric,
    latitud                  numeric,
    fecha_inicio_perforacion date,
    fecha_fin_perforacion    date,
    fecha_fin_terminacion    date,
    primer_mes_produccion    date,
    empresa_inicial          text NOT NULL REFERENCES vm.empresa,
    empresa_actual           text NOT NULL REFERENCES vm.empresa,
    en_padron                boolean NOT NULL
);

WITH prod AS (
    SELECT idpozo::integer                              AS pozo_id,
           make_date(anio::integer, mes::integer, 1)    AS mes_fecha,
           prod_pet::numeric > 0 OR prod_gas::numeric > 0 AS produjo,
           *
    FROM raw.produccion
    WHERE lower(formacion) = 'vaca muerta'
),
ultimo AS (
    SELECT DISTINCT ON (pozo_id) *
    FROM prod
    ORDER BY pozo_id, mes_fecha DESC
),
primero AS (
    -- primer mes con producción; si nunca produjo, el primer mes informado
    SELECT DISTINCT ON (pozo_id) pozo_id, idempresa, mes_fecha, produjo
    FROM prod
    ORDER BY pozo_id, produjo DESC, mes_fecha
),
tipo AS (
    SELECT pozo_id, mode() WITHIN GROUP (ORDER BY tipopozo) AS tipo_pozo
    FROM prod
    WHERE produjo AND tipopozo IS NOT NULL
    GROUP BY pozo_id
),
rama AS (
    SELECT idpozo::integer AS pozo_id
    FROM raw.fractura
    GROUP BY 1
    HAVING max(longitud_rama_horizontal_m::numeric) > 0
)
INSERT INTO vm.pozo
SELECT u.pozo_id,
       u.sigla,
       u.idareapermisoconcesion,
       regexp_replace(trim(u.areayacimiento), '\s+', ' ', 'g'),
       u.provincia,
       coalesce(t.tipo_pozo, u.tipopozo),
       u.sigla ~ '\(h\)\s*$' OR r.pozo_id IS NOT NULL,
       u.profundidad::numeric,
       u.coordenadax::numeric,
       u.coordenaday::numeric,
       pz.adjiv_fecha_inicio_perf::date,
       pz.adjiv_fecha_fin_perf::date,
       pz.adjiv_fecha_fin_term::date,
       CASE WHEN p.produjo THEN p.mes_fecha END,
       p.idempresa,
       u.idempresa,
       pz.idpozo IS NOT NULL
FROM ultimo u
JOIN primero p USING (pozo_id)
LEFT JOIN tipo t USING (pozo_id)
LEFT JOIN rama r USING (pozo_id)
LEFT JOIN raw.padron_pozos pz ON pz.idpozo::integer = u.pozo_id;


-- ---------------------------------------------------------------------------
-- produccion_mensual: una fila por pozo y por mes.
-- Se conservan los meses sin producción (pozo parado). Los volúmenes
-- negativos y los días activos fuera de 0-31 pasan a nulo.
-- ---------------------------------------------------------------------------
CREATE TABLE vm.produccion_mensual (
    pozo_id         integer NOT NULL REFERENCES vm.pozo,
    mes             date    NOT NULL,
    petroleo_m3     numeric,
    gas_miles_m3    numeric,
    agua_m3         numeric,
    dias_activo     numeric,
    estado          text,
    tipo_extraccion text,
    empresa_codigo  text NOT NULL REFERENCES vm.empresa,
    PRIMARY KEY (pozo_id, mes)
);

INSERT INTO vm.produccion_mensual
SELECT idpozo::integer,
       make_date(anio::integer, mes::integer, 1),
       CASE WHEN prod_pet::numeric  >= 0 THEN prod_pet::numeric  END,
       CASE WHEN prod_gas::numeric  >= 0 THEN prod_gas::numeric  END,
       CASE WHEN prod_agua::numeric >= 0 THEN prod_agua::numeric END,
       CASE WHEN tef::numeric BETWEEN 0 AND 31 THEN tef::numeric END,
       tipoestado,
       tipoextraccion,
       idempresa
FROM raw.produccion
WHERE lower(formacion) = 'vaca muerta';


-- ---------------------------------------------------------------------------
-- fractura: una fila por operación de fractura de un pozo.
-- Un pozo puede tener más de una (refracturas): nro_fractura = 1 es la
-- original. Las cargas duplicadas se eliminan. Los valores fuera de rango no
-- se borran: quedan marcados en dato_sospechoso con su motivo.
-- ---------------------------------------------------------------------------
CREATE TABLE vm.fractura (
    fractura_id        integer PRIMARY KEY,
    pozo_id            integer NOT NULL REFERENCES vm.pozo,
    nro_fractura       integer NOT NULL,
    fecha_inicio       date,
    fecha_fin          date,
    longitud_rama_m    numeric,
    etapas             integer,
    tipo_terminacion   text,
    arena_nacional_tn  numeric,
    arena_importada_tn numeric,
    agua_m3            numeric,
    presion_max_psi    numeric,
    potencia_hp        numeric,
    dato_sospechoso    boolean NOT NULL,
    motivo_sospecha    text,
    UNIQUE (pozo_id, nro_fractura)
);

WITH sin_duplicados AS (
    SELECT DISTINCT ON (idpozo, fecha_inicio_fractura, fecha_fin_fractura,
                        cantidad_fracturas, longitud_rama_horizontal_m,
                        agua_inyectada_m3, arena_bombeada_nacional_tn)
           id_base_fractura_adjiv::integer        AS fractura_id,
           idpozo::integer                        AS pozo_id,
           fecha_inicio_fractura::date            AS fecha_inicio,
           fecha_fin_fractura::date               AS fecha_fin,
           longitud_rama_horizontal_m::numeric    AS longitud_rama_m,
           cantidad_fracturas::integer            AS etapas,
           tipo_terminacion,
           arena_bombeada_nacional_tn::numeric    AS arena_nacional_tn,
           arena_bombeada_importada_tn::numeric   AS arena_importada_tn,
           agua_inyectada_m3::numeric             AS agua_m3,
           presion_maxima_psi::numeric            AS presion_max_psi,
           potencia_equipos_fractura_hp::numeric  AS potencia_hp
    FROM raw.fractura
    WHERE lower(formacion_productiva) = 'vaca muerta'
    ORDER BY idpozo, fecha_inicio_fractura, fecha_fin_fractura,
             cantidad_fracturas, longitud_rama_horizontal_m,
             agua_inyectada_m3, arena_bombeada_nacional_tn,
             id_base_fractura_adjiv::integer
),
con_motivo AS (
    SELECT f.*,
           nullif(concat_ws('; ',
               CASE WHEN f.presion_max_psi = 0 OR f.presion_max_psi > 20000
                    THEN 'presión fuera de rango' END,
               CASE WHEN f.agua_m3 = 0 OR f.agua_m3 > 200000
                    THEN 'agua fuera de rango' END,
               CASE WHEN f.arena_importada_tn > 20000
                    THEN 'arena fuera de rango' END,
               CASE WHEN f.longitud_rama_m = 0 AND p.es_horizontal
                    THEN 'rama horizontal sin informar' END,
               CASE WHEN f.fecha_fin < f.fecha_inicio
                    THEN 'fechas invertidas' END
           ), '') AS motivo_sospecha
    FROM sin_duplicados f
    JOIN vm.pozo p USING (pozo_id)   -- descarta fracturas de pozos sin producción informada
)
INSERT INTO vm.fractura
SELECT fractura_id,
       pozo_id,
       row_number() OVER (PARTITION BY pozo_id ORDER BY fecha_inicio, fractura_id),
       fecha_inicio,
       fecha_fin,
       longitud_rama_m,
       etapas,
       tipo_terminacion,
       arena_nacional_tn,
       arena_importada_tn,
       agua_m3,
       presion_max_psi,
       potencia_hp,
       motivo_sospecha IS NOT NULL,
       motivo_sospecha
FROM con_motivo;

CREATE INDEX ON vm.fractura (pozo_id);
CREATE INDEX ON vm.pozo (area_id);

ANALYZE;
