# Diccionario de datos

Qué significa cada tabla y cada columna del modelo limpio (esquema `vm`). Fuente: Secretaría de Energía de la Nación, datos abiertos de hidrocarburos (Capítulo IV y Adjunto IV), descargados el 9 de octubre de 2026.

## Conceptos del sector, en dos líneas cada uno

- **Vaca Muerta:** una formación de roca a unos 3.000 metros de profundidad, sobre todo en Neuquén. El petróleo y el gas están atrapados dentro de la roca (shale) y no fluyen solos.
- **Pozo horizontal:** se perfora hacia abajo y después se dobla para avanzar de costado dentro de la roca. Ese tramo es la **rama horizontal**; cuanto más larga, más roca toca.
- **Fractura:** se inyecta agua con arena a mucha presión para romper la roca y que el petróleo pueda salir. El agua abre las grietas y la arena las mantiene abiertas.
- **Etapas:** la rama se fractura por tramos, uno por vez. Un pozo moderno tiene entre 40 y 70 etapas.
- **Declinación:** un pozo shale produce su máximo a los pocos meses y después cae rápido. Por eso hay que perforar pozos nuevos todo el tiempo para sostener la producción.
- **Área o concesión:** el bloque de terreno que una empresa tiene permiso para explotar (Loma Campana, Fortín de Piedra).
- **Operadora:** la empresa que perfora y maneja los pozos de un área.
- **Nivel de navegación:** Vaca Muerta tiene más de 100 metros de espesor y no es pareja. Se divide en seis unidades numeradas desde abajo (U1 a U6). La rama de un pozo "navega" dentro de una de ellas. U1 es la parte inferior, la más rica en materia orgánica.
- **Pozo padre y pozo hijo:** el padre es un pozo que ya lleva tiempo produciendo; el hijo es uno nuevo que se perfora al lado. El padre ya drenó parte de la roca, y el hijo puede rendir menos.

## Cómo se conectan las tablas

```
operadora ──< empresa ──< pozo >── area
                           │
                   ┌───────┴────────┐
          produccion_mensual     fractura
```

Se lee así: una operadora tiene varias empresas (razones sociales), una empresa tiene muchos pozos, un pozo está en un área, y cada pozo tiene muchos meses de producción y una o más fracturas.

## `pozo`: una fila por pozo (3.417)

| Columna | Qué es |
|---|---|
| `pozo_id` | Identificador único del pozo. Conecta con las otras tablas |
| `sigla` | Nombre oficial, por ejemplo `YPF.Nq.SOil-390(h)`: empresa que lo perforó, provincia, yacimiento, número. La `(h)` final indica horizontal y la `(d)` dirigido |
| `area_id` | Concesión donde está. Conecta con `area` |
| `yacimiento` | Subdivisión del área |
| `provincia` | Neuquén en casi todos; unos pocos en Mendoza y Río Negro |
| `tipo_pozo` | Petrolífero o Gasífero, según lo que más produjo |
| `es_horizontal` | Verdadero si es horizontal. Los falsos son los pozos verticales de la etapa piloto |
| `profundidad_m` | Profundidad total en metros |
| `longitud`, `latitud` | Coordenadas |
| `fecha_inicio_perforacion`, `fecha_fin_perforacion` | Cuándo se perforó |
| `fecha_fin_terminacion` | Cuándo se terminó de preparar para producir (después de la fractura) |
| `primer_mes_produccion` | Primer mes en que produjo petróleo o gas. Vacío si nunca produjo |
| `empresa_inicial` | Empresa que lo informaba cuando empezó a producir. Conecta con `empresa` |
| `empresa_actual` | Empresa que lo informa hoy |
| `en_padron` | Falso para 113 pozos de 2026 que todavía no figuran en el padrón oficial |

## `produccion_mensual`: una fila por pozo y por mes (219.848)

| Columna | Qué es | Unidad |
|---|---|---|
| `pozo_id` | A qué pozo corresponde | |
| `mes` | Mes informado, como fecha del día 1 | |
| `petroleo_m3` | Petróleo producido en el mes | metros cúbicos |
| `gas_miles_m3` | Gas producido en el mes | miles de metros cúbicos |
| `agua_m3` | Agua que salió junto con el petróleo | metros cúbicos |
| `dias_activo` | Días del mes que el pozo estuvo produciendo | días (0 a 31) |
| `estado` | Extracción Efectiva, Parado Transitoriamente, En Estudio, etc. | |
| `tipo_extraccion` | Cómo sale el fluido: surgencia natural (por su propia presión) o con ayuda mecánica | |
| `empresa_codigo` | Empresa que informó ese mes | |

Referencia para leer los números: 1 metro cúbico de petróleo son 6,29 barriles. Un pozo que da 3.000 m³ en un mes produce unos 630 barriles por día.

## `fractura`: una fila por operación de fractura (3.090)

| Columna | Qué es | Unidad |
|---|---|---|
| `fractura_id` | Identificador de la operación | |
| `pozo_id` | A qué pozo corresponde | |
| `nro_fractura` | 1 es la fractura original; 2 es una refractura | |
| `fecha_inicio`, `fecha_fin` | Cuándo se hizo | |
| `longitud_rama_m` | Largo de la rama horizontal. Cero en pozos verticales | metros |
| `etapas` | Cantidad de etapas de fractura | |
| `tipo_terminacion` | Técnica usada (Tapón disparo es la estándar) | |
| `arena_nacional_tn`, `arena_importada_tn` | Arena inyectada, según origen | toneladas |
| `agua_m3` | Agua inyectada | metros cúbicos |
| `presion_max_psi` | Presión máxima durante la operación | psi |
| `potencia_hp` | Potencia de los equipos de bombeo | caballos de fuerza |
| `dato_sospechoso` | Verdadero si algún valor es imposible o incoherente | |
| `motivo_sospecha` | Por qué se marcó | |

## `area`: una fila por concesión (93)

| Columna | Qué es |
|---|---|
| `area_id` | Código de la concesión |
| `nombre` | Nombre (Loma Campana, La Amarga Chica, Bandurria Sur…) |

## `empresa`: una fila por razón social (48)

| Columna | Qué es |
|---|---|
| `empresa_codigo` | Código que usa la Secretaría (`YPF`, `VST`, `TPT`…) |
| `razon_social` | Nombre legal |
| `operadora_id` | Grupo al que pertenece. Conecta con `operadora` |

## `operadora`: una fila por grupo empresario (41)

| Columna | Qué es |
|---|---|
| `operadora_id` | Identificador del grupo |
| `nombre` | Nombre comercial (YPF, Vista, Tecpetrol…) |

## `trayectoria`: una fila por pozo con recorrido informado (1.915)

Fuente: Secretaría de Energía, Trayectorias de Pozo Vaca Muerta, descargado el 10 de octubre de 2026. Cubre más del 90 % de los pozos hasta 2023, 44 % de los de 2024 y 25 % de los de 2025.

| Columna | Qué es |
|---|---|
| `pozo_id` | A qué pozo corresponde |
| `unidad` | Unidad donde navega la rama, de 1 (la más profunda) a 6 |
| `detalle` | Parte de la unidad: 1 inferior, 2 medio, 3 superior |
| `nivel` | Las dos anteriores en texto, por ejemplo `U1 medio` |
| `rama_m` | Largo de la rama horizontal según esta fuente |
| `profundidad_rama_m` | Profundidad vertical a la que empieza la rama |
| `geojson` | El recorrido completo del pozo visto desde arriba, como lista de coordenadas |

## `trayectoria_punto`: un punto de una rama cada 50 metros (75.792)

| Columna | Qué es |
|---|---|
| `pozo_id` | A qué pozo corresponde |
| `orden` | Número del punto, contando desde el fondo del pozo |
| `x_m`, `y_m` | Posición en metros al este y al norte de un punto fijo. Sirve para medir distancias |

## `pozo_vecindad`: una fila por pozo con rama (1.615)

Las distancias son vistas desde arriba, sin considerar la profundidad. Por eso cada una se calcula también solo contra ramas del mismo nivel.

| Columna | Qué es |
|---|---|
| `distancia_vecino_m` | Distancia típica a la rama más cercana de cualquier otro pozo |
| `distancia_vecino_mismo_nivel_m` | Lo mismo, solo contra ramas de la misma unidad. Es el espaciamiento |
| `distancia_previo_m` | Distancia a la rama más cercana de un pozo que ya llevaba 12 meses o más produciendo (un padre) |
| `distancia_previo_mismo_nivel_m` | Lo mismo, solo contra padres de la misma unidad |
