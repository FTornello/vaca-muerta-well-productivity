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
- **Curva de declinación:** la forma en que cae la producción de un pozo con el tiempo. Se describe con una fórmula (la más usada es la hiperbólica de Arps) y sirve para proyectar cuánto va a producir en total.
- **Nivel de navegación:** Vaca Muerta tiene más de 100 metros de espesor y no es pareja. Se divide en seis unidades numeradas desde abajo (U1 a U6). La rama de un pozo "navega" dentro de una de ellas. U1 es la parte inferior, la más rica en materia orgánica.
- **Pozo padre y pozo hijo:** el padre es un pozo que ya lleva tiempo produciendo; el hijo es uno nuevo que se perfora al lado. El padre ya drenó parte de la roca, y el hijo puede rendir menos.

## Cómo se conectan las tablas

**El núcleo.** Seis tablas unidas por claves que la base hace cumplir: no puede existir producción de un pozo que no esté en `pozo`.

```
operadora ──< empresa ──< pozo >── area
                           │
           ┌───────────────┼────────────────┐
  produccion_mensual    fractura       trayectoria ──< trayectoria_punto
                                            │
                                      pozo_vecindad
```

Se lee así: una operadora tiene varias empresas (razones sociales), una empresa tiene muchos pozos, un pozo está en un área, y cada pozo tiene muchos meses de producción, una o más fracturas y, si se informó, una trayectoria.

**Lo que se suma alrededor.** Las demás tablas vienen de otros datasets y no se enlazan todas igual:

| Tabla | Se une al núcleo por | Qué tan firme es el enlace |
|---|---|---|
| `inversion` | El nombre del área | Engancha el 98 % de los dólares |
| `reserva` | El nombre del área | Engancha el 99 % del petróleo comprobado |
| `precio_gas`, `oleoducto_troncal`, `exportacion`, `regalia_petroleo` | Solo el mes | Son series de toda la cuenca o la provincia: se comparan con totales mensuales, no con pozos |
| `empleo_neuquen` | Solo el mes | Es de la provincia de Neuquén entera |
| `regalia_gas`, `tipo_de_cambio`, `precio_surtidor`, `comercio_energia`, `pais_energia`, `metros_perforados`, `crudo_procesado`, `pozos_terminados`, `brent`, `henry_hub`, `eeuu_tight_oil` | Solo el mes | Las regalías y los precios son por provincia; el tipo de cambio, del país |

**Los nombres de empresa** cambian de una fuente a otra. La tabla `grupo_alias` los une: `inversion` y `exportacion` tienen una columna `grupo` que permite cruzarlas con `operadora`. Algunos grupos invierten o exportan sin operar ningún área (son socios de quien opera); esos no tienen operadora.

**De dónde sale cada archivo y cuándo se bajó:** [data/FUENTES.csv](data/FUENTES.csv).

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

## `precio_gas`: una fila por mes (89)

Precio del gas de la cuenca Neuquina, total de contratos, en dólares por millón de BTU. Desde enero de 2019.

| Columna | Qué es |
|---|---|
| `mes` | Mes |
| `precio_promedio` | Promedio ponderado de todas las ventas al mercado interno |
| `precio_distribuidoras` | Precio de venta a las distribuidoras que abastecen hogares y comercios |
| `precio_gnc` | Precio de venta para gas vehicular |
| `precio_usinas` | Precio de venta a centrales eléctricas |
| `precio_industria` | Precio de venta a industrias |
| `precio_exportacion` | Precio del gas exportado |

## `oleoducto_troncal`: una fila por mes (92)

Volumen del oleoducto Allen - Puerto Rosales de Oldelval, la salida principal del petróleo de la cuenca hacia el Atlántico. Datos confiables desde 2020.

| Columna | Qué es | Unidad |
|---|---|---|
| `mes` | Mes | |
| `cano_original_m3` | Petróleo transportado por el caño original | metros cúbicos |
| `duplicar_m3` | Petróleo transportado por el caño nuevo (Duplicar), desde marzo de 2025 | metros cúbicos |

## `inversion`: una fila por mes, área, empresa y concepto (12.465)

Inversiones declaradas por las empresas en áreas no convencionales de la cuenca Neuquina (Resolución 2057). Son declaraciones juradas; la fuente no las audita y no todas las empresas cargan los conceptos igual.

| Columna | Qué es |
|---|---|
| `mes` | Mes de la inversión |
| `area_nombre` | Área según la declaración |
| `area_id` | Enlace con `area`; vacío si el área no tiene pozos de Vaca Muerta |
| `empresa` | Empresa que declara |
| `concepto` | En qué se gastó (perforación, plantas, ductos, etc.) |
| `es_perforacion` | Verdadero si el concepto es perforación de pozos |
| `usd_millones` | Monto en millones de dólares |

## `exportacion`: una fila por mes, vía, país y empresa (1.099)

Petróleo de la cuenca Neuquina que sale del país. Hoy es casi todo de Vaca Muerta.

| Columna | Qué es |
|---|---|
| `mes` | Mes |
| `via` | `barco` (desde la terminal de Puerto Rosales) u `oleoducto` (a Chile por el Oleoducto Trasandino, desde 2023) |
| `pais` | País de destino |
| `cargador` | Empresa dueña del petróleo embarcado |
| `volumen_m3` | Volumen, en metros cúbicos |

## `reserva`: una fila por área y por año (529)

Reservas no convencionales de la cuenca Neuquina al 31 de diciembre de cada año, de 2017 a 2025. Petróleo en miles de m³, gas en millones de m³.

| Columna | Qué es |
|---|---|
| `anio` | Año del cierre |
| `area_nombre`, `area_id` | Área; `area_id` enlaza con `area` |
| `petroleo_comprobadas`, `gas_comprobadas` | Lo que se puede producir con certeza razonable, con la tecnología y los precios de hoy |
| `petroleo_probables`, `gas_probables` | Menos seguras que las comprobadas |
| `petroleo_recursos`, `gas_recursos` | Volúmenes identificados que todavía no son comerciales |

## `regalia_petroleo`: una fila por mes y provincia (4.475)

Lo que cobra cada provincia por el petróleo crudo, desde 1991. Fuente: informe de regalías de la Secretaría de Energía.

| Columna | Qué es |
|---|---|
| `mes`, `provincia` | Mes y provincia |
| `regalias_usd` | Regalías liquidadas, en dólares |
| `precio_usd_m3` | Precio al que se liquidó el petróleo, en dólares por m³ (dividir por 6,2898 para llevarlo a barril) |
| `produccion_m3` | Volumen sobre el que se calculó. No coincide exacto con la producción por pozo: el condensado de los pozos de gas se liquida aparte |

## `empleo_neuquen`: una fila por mes, departamento y sector (65.243)

Puestos de trabajo privados registrados en Neuquén y su salario mediano, de enero de 2014 a noviembre de 2023. Fuente: CEP XXI, Secretaría de Producción. La serie se dejó de publicar.

| Columna | Qué es |
|---|---|
| `mes` | Mes |
| `departamento` | Departamento que declara el empleador (no siempre es donde se trabaja) |
| `sector` | Rama de actividad |
| `es_petroleo_y_gas` | Verdadero para extracción de petróleo y gas y para sus servicios de apoyo |
| `puestos` | Cantidad de puestos. Las celdas con pocos empleadores vienen ocultas en la fuente y no están |
| `salario_mediano` | Salario bruto mediano, en pesos corrientes |

## `grupo_alias`: una fila por nombre de empresa (60)

Une los nombres con que cada fuente escribe a las empresas.

| Columna | Qué es |
|---|---|
| `nombre_normalizado` | El nombre en mayúsculas, sin acentos y sin espacios repetidos |
| `grupo` | Grupo empresario al que pertenece (YPF, Vista, Equinor…) |
| `operadora_id` | Enlace con `operadora`. Vacío si el grupo no opera áreas en Vaca Muerta |

## `tipo_de_cambio`: una fila por mes (141)

| Columna | Qué es |
|---|---|
| `mes` | Mes, desde diciembre de 2014 |
| `pesos_por_dolar` | Tipo de cambio oficial vendedor del Banco Nación, promedio del mes |

## `comercio_energia`: una fila por mes (desde 2010)

Comercio exterior de todo el país, del INDEC. No es un dato de Vaca Muerta: sirve de contexto. En millones de dólares.

| Columna | Qué es |
|---|---|
| `mes` | Mes |
| `exportacion_energia` | Exportaciones del rubro combustibles y energía |
| `importacion_energia` | Importaciones de combustibles y lubricantes |
| `saldo_total` | Exportaciones menos importaciones de todos los rubros del país |

## `pais_energia`: una fila por mes (desde 2010)

Producción y refinación de todo el país, de la Secretaría de Energía. Sirve para medir qué parte del total es Vaca Muerta.

| Columna | Qué es | Unidad |
|---|---|---|
| `mes` | Mes | |
| `petroleo_producido_km3` | Petróleo crudo producido en el país. Vacío en los últimos meses | miles de m³ |
| `petroleo_procesado_km3` | Crudo que procesaron las refinerías del país. Vacío en los últimos meses | miles de m³ |
| `gas_producido_mm_m3` | Gas natural producido en el país | millones de m³ |

## `pronostico_petroleo`: una fila por informe, área y año pronosticado

Lo que cada empresa le declaró a la Secretaría de Energía que iba a producir. Solo áreas de Neuquén.

| Columna | Qué es |
|---|---|
| `anio_informe` | Año en que se presentó el pronóstico (se presenta en marzo) |
| `area_nombre` | Nombre del área como viene en la fuente |
| `area_id` | Enlace con `area`. Vacío si el área no tiene pozos de Vaca Muerta |
| `anio_pronostico` | Año para el que se pronostica: el del informe o alguno de los cuatro siguientes |
| `petroleo_m3` | Petróleo pronosticado para ese año, del área entera (incluye convencional si lo hay) |

## `venteo_detectado`: una fila por anomalía térmica vista por satélite

Puntos calientes, que en una zona petrolera son casi siempre antorchas quemando gas. Es un conteo de detecciones, no un volumen: una antorcha encendida se detecta muchas veces.

| Columna | Qué es |
|---|---|
| `mes` | Mes de la detección |
| `provincia` | Provincia |
| `satelite` | Satélite que la vio. Desde 2017 casi todas son de Suomi NPP |
| `latitud`, `longitud` | Ubicación |
| `km_al_pozo` | Distancia al pozo de Vaca Muerta más cercano. Solo para Neuquén; vacío si no hay ninguno a menos de unos 10 km |

## `metros_perforados`: una fila por mes, provincia y tipo de pozo

| Columna | Qué es |
|---|---|
| `mes` | Mes |
| `provincia` | Provincia |
| `concepto` | Exploración, Avanzada, Explotación o Servicio |
| `metros` | Metros perforados |

## `crudo_procesado`: una fila por mes, refinería y tipo de crudo

Qué petróleo procesó cada refinería del país, según de dónde viene.

| Columna | Qué es |
|---|---|
| `mes` | Mes |
| `empresa`, `refineria` | Quién lo procesó y dónde |
| `origen` | Neuquén, Resto de la cuenca Neuquina, Golfo San Jorge, Otras cuencas o Importado. La separación entre Neuquén y el resto de la cuenca la declara cada refinería y no es pareja: conviene sumarlas |
| `crudo` | Nombre del crudo como viene en la fuente |
| `m3` | Volumen procesado, en m³ |

## `pronostico_gas`: una fila por informe, área, año pronosticado y tipo

Igual que `pronostico_petroleo`, para el gas. Toda la provincia de Neuquén, en miles de m³.

| Columna | Qué es |
|---|---|
| `anio_informe`, `anio_pronostico` | Como en `pronostico_petroleo` |
| `area_codigo` | Código del área en la fuente |
| `area_nombre`, `area_id` | Nombre (sale de la planilla de petróleo, que usa los mismos códigos) y enlace con `area` |
| `tipo` | `Totales Anuales` para los años siguientes. Para el año en curso: `Disponible al Mercado`, `Consumo Propio`, `Gas Aventado` y `Exportado` |
| `gas_miles_m3` | Gas pronosticado |

## `venteo_punto_declarado`: una fila por chimenea o fosa de quema declarada

| Columna | Qué es |
|---|---|
| `punto` | Código del punto de venteo |
| `tipo` | Chimenea de quema o fosa de quema |
| `procedencia` | Yacimiento o planta compresora |
| `latitud`, `longitud` | Ubicación |

`venteo_detectado` tiene además `km_al_punto_declarado`: la distancia de cada detección satelital al punto declarado más cercano.

## `pozos_terminados`: una fila por mes, provincia y resultado

| Columna | Qué es |
|---|---|
| `mes`, `provincia` | Mes y provincia |
| `resultado` | Productivos de Petróleo, Productivos de Gas, Improductivos o Servicio |
| `pozos` | Cantidad de pozos terminados |

## `brent`: una fila por mes (desde 1987)

| Columna | Qué es |
|---|---|
| `mes` | Mes |
| `usd_bbl` | Precio del crudo Brent, promedio del mes, en dólares por barril. Fuente: EIA |

## `henry_hub`: una fila por mes (desde 1997)

| Columna | Qué es |
|---|---|
| `mes` | Mes |
| `usd_mmbtu` | Precio del gas natural en Estados Unidos (Henry Hub), promedio del mes, en dólares por millón de BTU. Fuente: EIA |

## `eeuu_tight_oil`: una fila por mes y cuenca (desde 2000)

Petróleo de shale de Estados Unidos, de la EIA. Llega hasta marzo de 2024.

| Columna | Qué es |
|---|---|
| `mes` | Mes |
| `cuenca` | Nombre de la cuenca como viene en la fuente. Las tres formaciones del Permian (Wolfcamp, Spraberry y Bonespring) vienen separadas |
| `miles_bbl_dia` | Producción en miles de barriles por día |

## `regalia_gas`: una fila por mes y provincia

Igual que `regalia_petroleo`, para el gas natural. La fuente la publica en pesos.

| Columna | Qué es |
|---|---|
| `regalias_ars` | Regalías liquidadas, en pesos |
| `regalias_usd` | Las mismas en dólares, convertidas con el tipo de cambio promedio del mes. Es aproximado: la liquidación real usa el de un día puntual |
| `produccion_miles_m3` | Volumen sobre el que se calculó |

## `curva_tipo`: una fila por año de arranque y mes de vida (600)

Cómo se reparte en el tiempo la producción de un pozo petrolero, según lo observado.

| Columna | Qué es |
|---|---|
| `anio_arranque`, `pozos` | Año en que arrancaron los pozos y cuántos son |
| `mes_de_vida` | Edad. Solo llega hasta la que todos los pozos de ese año ya cumplieron |
| `caudal_m3_por_mes` | Petróleo promedio por pozo en ese mes de vida. Un pozo parado cuenta como cero |
| `caudal_sobre_primer_anio` | Lo mismo, como fracción de lo que el pozo produce en sus primeros 12 meses |
| `acumulado_sobre_primer_anio` | Cuántas veces el primer año lleva producido hasta ese mes |

## `declinacion`: una fila por mes de vida, de 1 a 300

La curva tipo extendida a 25 años. La calcula `scripts/ajustar_declinacion.py`.

| Columna | Qué es |
|---|---|
| `mes_de_vida` | Edad del pozo en meses |
| `origen` | `observado` hasta el mes 117; `ajustado` después: es una proyección |
| `acumulado_base` | Cuántas veces el primer año lleva producido, suponiendo que la declinación no baja de 8 % anual |
| `acumulado_bajo`, `acumulado_alto` | Lo mismo con pisos de 12 % y 6 % anual |
| `caudal_bajo`, `caudal_base`, `caudal_alto` | Producción de ese mes como fracción del primer año |

## `precio_surtidor`: una fila por mes, provincia y producto (8.832)

Precios de combustibles en estaciones de servicio, de enero de 2019 a agosto de 2026. Es la mediana entre las estaciones que venden al público.

| Columna | Qué es |
|---|---|
| `mes`, `provincia` | Mes y provincia |
| `producto` | `nafta súper`, `nafta premium`, `gasoil grado 2` o `gasoil grado 3` |
| `estaciones` | Cuántas estaciones informaron |
| `precio_surtidor` | Lo que paga quien carga, en pesos por litro |
| `precio_sin_impuestos` | Lo mismo antes de impuestos |
