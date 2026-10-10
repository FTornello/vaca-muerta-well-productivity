# Bitácora del proyecto

Acá voy anotando el razonamiento a medida que avanzo: qué decidí, por qué, y qué descarté. No es el README (ese cuenta el resultado); esto cuenta el camino.

Trabajé con Claude Code como asistente: lo usé para relevar los portales de datos, perfilar las tablas y escribir los scripts de carga y limpieza. Las preguntas, las decisiones y las consultas de análisis son mías.

---

## 1. De dónde salió la idea

*9 de octubre de 2026*

Quise analizar uno de los temas más candentes hoy en Argentina: la minería y la energía. En San Juan se habla del boom del cobre, y en Neuquén Vaca Muerta ya cambió la balanza energética del país. Además había visto que en Vaca Muerta buscan gente que sepa analizar datos.

No arranqué con una pregunta fija. Arranqué por los datos, porque de proyectos anteriores aprendí que si el dato no existe con el detalle necesario, el análisis termina apoyado en cifras sueltas de informes y declaraciones.

## 2. Screening de datasets

Revisé los portales oficiales de datos abiertos buscando tablas grandes, con detalle fino y actualizadas.

| Tema | Lo que encontré | Conclusión |
|---|---|---|
| Vaca Muerta (Secretaría de Energía) | Producción mes a mes de cada pozo, datos de fractura de cada pozo y un padrón con todos los pozos del país. Actualizado a agosto de 2026. | Granular y al día |
| Minería (SIACAM, Secretaría de Minería) | Empleo por provincia, exportaciones por mineral, cartera de proyectos, anuncios de inversión. | Todo viene ya resumido; no hay producción por mina |
| Electricidad (CAMMESA) | Demanda mensual de cada gran usuario, incluidas algunas mineras. | La serie abierta se corta en febrero de 2020 |

Minería me interesa más por cercanía, pero los datos abiertos no alcanzan para un análisis a nivel operación. Los archivos que cruzaban minería con consumo de energía por proyecto figuran en el catálogo pero dan error al abrirlos.

**Decisión:** Vaca Muerta. Es donde el dato permite contestar preguntas con evidencia y no con supuestos.

## 3. Qué hay adentro del dataset

Son tres tablas que se conectan por el identificador del pozo:

- **Producción:** una fila por pozo y por mes, con petróleo, gas, agua y días que estuvo activo. 426.145 filas de todo el no convencional del país.
- **Fractura:** cómo se construyó cada pozo: largo de la rama horizontal, cantidad de etapas, arena y agua inyectadas, presión. 4.984 filas.
- **Padrón:** los 85.611 pozos del país con empresa, área, coordenadas y fechas de perforación.

Me quedé solo con la formación Vaca Muerta: **3.417 pozos de 48 empresas, 219.848 registros mensuales entre 2006 y agosto de 2026**. Dejé afuera el resto del no convencional (tight gas de otras formaciones) porque son pozos de otro tipo y mezclarlos ensucia las comparaciones.

Unidades, según la fuente: petróleo y agua en metros cúbicos, gas en miles de metros cúbicos.

## 4. La pregunta

Al mirar qué contenía cada tabla, las preguntas salieron solas. El dataset tiene tres cosas de cada pozo: **cómo se diseñó** (fractura), **quién lo opera y dónde está** (padrón) y **cuánto produjo** (producción). Eso permite cruzar decisiones con resultados.

La pregunta que elegí:

> **¿Qué hace que un pozo de Vaca Muerta rinda más: el diseño, la operadora o el lugar?**

La divido en cuatro:

1. ¿Cómo evoluciona la producción de un pozo típico mes a mes, y los pozos nuevos rinden más que los de hace cinco años?
2. ¿Los pozos con rama más larga, más etapas y más arena producen más, o llega un punto donde ya no rinde?
3. ¿Qué operadora saca más por pozo en su primer año, y cuánto mejoró cada una?
4. ¿Cuánto de toda la producción sale de unas pocas áreas y unos pocos pozos?

Para comparar pozos uso la **producción acumulada en los primeros 12 meses**, que pone en igualdad a un pozo de 2018 con uno de 2024.

**Límite que tengo que decir claro:** la pregunta 2 muestra asociación, no causa. Las mejores zonas reciben los pozos más grandes, así que parte del efecto del diseño es efecto del lugar. Para acotarlo voy a comparar pozos dentro de una misma área.

## 5. Herramienta: PostgreSQL

Elegí PostgreSQL porque SQL es lo que más piden los avisos de analista de datos y lo que evalúan en las pruebas técnicas, y hasta ahora no tenía un proyecto propio en SQL. Además el dataset lo pide: son tres tablas relacionadas, no una planilla.

## 6. El modelo de datos

Los CSV repiten en cada fila el nombre de la empresa, el área y la provincia. Los separé en seis tablas donde cada dato vive en un solo lugar:

| Tabla | Una fila es | Filas |
|---|---|---|
| `operadora` | Un grupo empresario | 41 |
| `empresa` | Una razón social que informa producción, con su grupo | 48 |
| `area` | Una concesión | 93 |
| `pozo` | Un pozo | 3.417 |
| `produccion_mensual` | Un pozo en un mes | 219.848 |
| `fractura` | Una operación de fractura de un pozo | 3.090 |

Trabajo en dos capas. La capa `raw` guarda los CSV tal cual vienen, sin tocar. La capa `vm` es el modelo limpio y se reconstruye entera desde `raw` con un script, así cualquier decisión de limpieza queda escrita y se puede rehacer.

## 7. Problemas de calidad y qué decidí

| Problema | Qué era en realidad | Decisión |
|---|---|---|
| La misma empresa con varios nombres (Vista tiene tres) | Cambios de razón social | Tabla `empresa` que agrupa razones sociales por marca. Solo uní las de la misma marca; no seguí compras entre empresas distintas |
| 284 pozos cambiaron de empresa en el tiempo | Ventas de áreas | Guardo la empresa inicial y la actual de cada pozo. Para evaluar a una operadora uso la inicial, que es la que diseñó el pozo |
| Rama horizontal en cero en 458 fracturas | Pozos verticales de la etapa piloto (2013 a 2015), no datos faltantes | Los conservo con una marca `es_horizontal` para poder separarlos |
| 37 pozos con sigla de horizontal y rama en cero | Dato sin cargar | Quedan marcados como sospechosos |
| Pozos repetidos en fractura | Casi todos son de otras formaciones; en Vaca Muerta hay 11 refracturas y unas pocas cargas dobles | Elimino las cargas dobles y numero las fracturas; la número 1 es la original |
| Presiones, volúmenes de agua y de arena imposibles (16 filas) | Errores de carga | No los borro: quedan marcados con el motivo |
| 33 fracturas con fecha de fin anterior a la de inicio | Errores de carga | Marcadas como sospechosas |
| 3 valores negativos de producción | Errores de carga | Pasan a nulo |
| El tipo de pozo cambia con el tiempo (un pozo parado pasa a "Otro tipo") | Así lo informa la fuente | Tomo el tipo más frecuente entre los meses en que produjo |
| 113 pozos de producción no están en el padrón | Todos son de 2026: el padrón publicado es de julio y la producción llega a agosto | Los conservo sin fechas de perforación |

Criterio general: **marcar en vez de borrar.** Así cada análisis decide qué excluir y queda a la vista.

## 8. Controles

Después de limpiar comparé la fuente contra el modelo: cantidad de pozos, filas de producción, petróleo total, gas total, empresas, áreas y pozos con fractura. Los ocho controles coinciden exactamente; no se perdió nada en el camino.

Como chequeo de sentido común: el modelo da 29,1 millones de metros cúbicos de petróleo en 2025, unos 500.000 barriles por día, que es el orden de magnitud que se informa públicamente para Vaca Muerta.

## 9. Pregunta 1: la curva de un pozo y si los nuevos rinden más

*10 de octubre de 2026*

Antes de promediar miré un solo pozo, uno horizontal de YPF en Loma Campana que arrancó en 2019. Ahí se ve la forma: el primer mes produce pocos días, hace pico al tercer o cuarto mes y después cae rápido. También se ve el ruido real: lo pararon en abril y mayo de 2020 por la pandemia.

Para comparar pozos de distintos años no sirve el calendario; sirve la edad. Calculé el **mes de vida** de cada pozo (mes 1 = primer mes con producción).

**Una decisión de método:** la primera versión numeraba las filas de cada pozo. Al revisar encontré 169 pozos con meses sin informar, y numerar filas les corría la edad. Lo cambié por la diferencia entre fechas, que no depende de que estén todas las filas.

**Otra decisión:** para el acumulado del primer año solo cuento pozos que ya cumplieron 12 meses. Si no, estaría comparando un año entero contra uno incompleto. Por eso 2025 incluye solo los pozos que arrancaron hasta septiembre, y 2026 no aparece.

Población: pozos horizontales petrolíferos.

**Lo que encontré:**

| Año de arranque | Pozos | Petróleo en el primer año, mediana (m³) |
|---|---|---|
| 2016 | 67 | 17.323 |
| 2018 | 85 | 27.125 |
| 2020 | 72 | 34.457 |
| 2022 | 201 | 39.545 |
| 2024 | 321 | 35.794 |
| 2025 | 302 | 38.883 |

- **Entre 2016 y 2021 el pozo típico más que duplicó lo que produce en su primer año.**
- **Desde 2021 la mejora se frenó:** la mediana se mueve entre 36.000 y 40.000 m³ sin tendencia clara. Lo que creció desde entonces es la cantidad de pozos, no el rendimiento de cada uno.
- **La forma de la curva no cambió:** todos los años hacen pico al tercer o cuarto mes y al mes 12 producen menos de la mitad que en el pico.
- **La dispersión es grande:** en 2025 el 10 % mejor de los pozos triplica al 10 % peor. Eso es lo que las preguntas 2 y 3 tienen que explicar.

Usé la mediana y no el promedio porque unos pocos pozos excepcionales lo inflan.

## 10. Pregunta 2: el diseño del pozo

*10 de octubre de 2026*

Armé una tabla de trabajo (`pozo_analisis`) con una fila por pozo horizontal petrolífero que ya cumplió 12 meses: su área, su operadora inicial, el petróleo del primer año y el diseño de su fractura original. Son 1.688 pozos; 1.580 tienen el diseño completo y sin datos sospechosos.

**Cómo cambió el pozo típico:**

| Año | Rama (m) | Etapas | Arena (t) | Petróleo 1er año (m³) | Petróleo por km de rama (m³) |
|---|---|---|---|---|---|
| 2016 | 1.411 | 18 | 4.252 | 17.455 | 13.306 |
| 2019 | 2.250 | 33 | 7.931 | 33.511 | 16.846 |
| 2021 | 2.518 | 36 | 8.218 | 38.573 | 16.307 |
| 2023 | 2.684 | 44 | 10.226 | 37.861 | 14.797 |
| 2025 | 3.065 | 50 | 11.761 | 38.533 | 12.695 |

Esto explica el freno que vi en la pregunta 1. Entre 2021 y 2025 los pozos siguieron creciendo: la rama se alargó 22 %, las etapas pasaron de 36 a 50 y la arena subió 43 %. Pero el petróleo del primer año quedó igual. **Cada kilómetro de rama rinde hoy 22 % menos que en 2021.**

Mirando solo los pozos desde 2021, por largo de rama: los de 1.500 a 2.000 metros dan 29.945 m³ en el primer año y los de 3.500 a 4.000 dan 44.337. Más rama da más petróleo por pozo, pero menos por metro (de 16.951 a 12.057 m³ por kilómetro). Son rendimientos decrecientes.

Con la arena pasa algo parecido hasta cierto punto: de 2,5 a 4 toneladas por metro el rendimiento por kilómetro sube, y entre 3,5 y 4,5 se aplana.

**Lo que no puedo afirmar:** que alargar la rama *cause* la caída por kilómetro. Hay al menos dos explicaciones más que los datos no separan: que los pozos nuevos estén en roca menos buena que los primeros, y que las empresas regulen el caudal del primer año por razones operativas o de capacidad de transporte. Lo dejo como asociación.

**Dentro de una misma área** la relación con el diseño cambia mucho: en Loma Campana y Cruz de Lorena los pozos más largos producen claramente más (correlación de 0,61 y 0,65); en Bajada del Palo Oeste no hay relación (−0,05). No hay una receta única.

## 11. Pregunta 3: las operadoras

Tomé como operadora de un pozo a la que lo informaba cuando empezó a producir, porque es la que lo diseñó.

Pozos desde 2021, operadoras con 15 o más:

| Operadora | Pozos | Áreas | Petróleo 1er año, mediana (m³) | Por km de rama (m³) |
|---|---|---|---|---|
| Vista | 166 | 4 | 43.792 | 16.000 |
| Pampa Energía | 19 | 1 | 41.696 | 16.705 |
| YPF | 731 | 13 | 37.184 | 13.909 |
| Kilwer | 35 | 1 | 35.306 | 14.497 |
| Pan American Energy | 86 | 4 | 35.181 | 11.432 |
| Chevron | 31 | 1 | 34.601 | 11.429 |
| Shell | 106 | 3 | 33.713 | 12.629 |
| Tecpetrol | 22 | 2 | 21.467 | 9.355 |

Vista fue primera todos los años entre 2020 y 2024. En 2025 pasó al tercer puesto, detrás de Chevron y Pan American. Tecpetrol aparece última, pero su negocio en Vaca Muerta es el gas (Fortín de Piedra), no el petróleo, así que esta tabla no la representa.

**El hallazgo que cambia cómo leer el ranking:** en Vaca Muerta cada área la opera una sola empresa. De 35 áreas con pozos desde 2021, la única con dos operadoras es Bajo del Choique, y fue un cambio de dueño (de ExxonMobil a Pluspetrol), no dos empresas a la vez. Entonces **no puedo separar a la operadora del lugar**: cuando Vista rinde más que Shell, no sé si es por cómo trabaja o por dónde le tocó perforar.

Lo que sí puedo ver es la misma operadora en distintos lugares. YPF, con el mismo equipo y la misma forma de trabajar, saca 42.477 m³ en Loma Campana y 28.947 en Bajo del Toro Norte. El lugar pesa.

## 12. Pregunta 4: concentración

Acá uso todos los pozos de Vaca Muerta, no solo los horizontales petrolíferos.

- **Cuatro áreas produjeron el 62 % de todo el petróleo** desde 2006: Loma Campana (26 %), La Amarga Chica (15 %), Bandurria Sur (10 %) y Bajada del Palo Oeste (10 %). Son 4 de 93.
- **Esa concentración está bajando:** en los últimos 12 meses las mismas cuatro suman 49 %. Loma Campana pasó de 26 % histórico a 15 %. Entraron áreas nuevas como La Angostura Sur, El Trapial Este y Rincón de Aranda.
- **Por pozo:** el 10 % de los pozos que más produjo aportó el 28 % del petróleo acumulado, y la mitad superior el 85 %. Este número hay que leerlo con cuidado porque un pozo viejo tuvo más tiempo para acumular que uno nuevo.
- **Por operadora:** YPF informa el 52 % del petróleo de los últimos 12 meses.

## 13. La respuesta: ¿diseño, operadora o lugar?

Medí qué parte de las diferencias de producción entre pozos acompaña a cada factor, en los 1.143 pozos desde 2021 con diseño confiable:

| Factor | Parte de las diferencias que explica |
|---|---|
| El lugar (área) | 18 % |
| La operadora | 10 % |
| El año de arranque | 1 % |
| La arena inyectada | 20 % |
| La cantidad de etapas | 22 % |
| El largo de la rama | 15 % |

Los porcentajes no se suman entre sí: la operadora está contenida en el lugar (cada área tiene una sola), y las tres medidas de diseño se mueven juntas.

Para combinar lugar y diseño le resté a cada pozo el promedio de su área y volví a medir. Dentro de una misma área, la arena explica otro 20 % de lo que queda. **Sumando lugar y diseño se llega a un 35 % aproximadamente.**

**Mi conclusión:**

1. **Ningún factor domina.** El lugar y el diseño pesan parecido, alrededor de un quinto cada uno.
2. **La operadora no se puede aislar** con estos datos, porque viene pegada al lugar.
3. **Casi dos tercios de las diferencias entre pozos no los explica nada de lo que publica la Secretaría.** Ahí está la geología fina de cada pozo y decisiones operativas que no figuran en los datos abiertos.
4. **Lo más firme que encontré** es que desde 2021 los pozos son cada vez más grandes sin rendir más: cada kilómetro de rama produce 22 % menos.

Dentro de una misma área, cada metro extra de rama se asocia con 9,7 m³ más de petróleo en el primer año, y cada tonelada extra de arena con 2,4 m³ más.

## 14. El tablero

*10 de octubre de 2026*

Quería hacerlo en Power BI porque es lo que más piden los avisos y nunca lo usé, pero Power BI Desktop solo existe para Windows y mi Mac no tiene memoria ni disco para correr una máquina virtual. Lo hago en Tableau Public, que ya conozco, y dejo Power BI para el próximo proyecto.

Exporté tres tablas desde la base para alimentar el tablero: una fila por pozo, la producción por mes de vida y la producción mensual por área. Armé también una imagen con los cuatro hallazgos para tener una referencia de cómo tienen que verse los gráficos.

Una decisión de diseño: para mostrar que los pozos crecen pero no rinden más, puse las cuatro medidas (arena, rama, petróleo del primer año, petróleo por kilómetro) como índice con 2021 = 100. Así se comparan en una misma escala sin usar dos ejes, que confunden.

## 15. Una capa más: por qué pasa lo que encontré

*10 de octubre de 2026*

Los datos me dijeron qué pasó. Para el porqué busqué qué dicen consultoras, trabajos técnicos y prensa especializada, y después volví a los datos para poner a prueba cada explicación. Las consultas están en `sql/analisis/p6_por_que_cae_el_rendimiento.sql`.

### Lo que confirman otras fuentes

**La mejora hasta 2020 está documentada y coincide con mis números.** La consultora FDC armó un "pozo tipo" por año (nota de LM Neuquén, enero de 2021):

| Año | Rama según FDC (m) | Rama en mis datos (m) | Acumulada a 365 días según FDC (m³) | Mediana en mis datos (m³) |
|---|---|---|---|---|
| 2016 | 1.350 | 1.411 | 17.000 | 17.323 |
| 2018 | 2.030 | 2.000 | 27.800 | 27.125 |
| 2019 | 2.115 | 2.250 | 37.000 | 33.270 |
| 2020 | 2.215 | 2.207 | 41.500 | 34.457 |

Que dos caminos independientes den casi lo mismo es la mejor validación que tengo del modelo. La diferencia en 2019 y 2020 puede venir de que FDC usa un pozo tipo y yo la mediana de todos los pozos. La misma fuente muestra que el costo por pozo bajó de 16,5 a 9,5 millones de dólares entre 2016 y 2020: los pozos mejoraban y además salían más baratos.

**La caída por metro desde 2021 también la vio otro.** Un análisis de la consultora Enverus habla de una baja anual de 7 a 12 % en la productividad por pie de rama desde 2021, y la atribuye a que las operadoras se expanden a zonas menos productivas y a cambios en el espaciamiento entre pozos. Mi número es más moderado: 22 % en cuatro años, unos 6 % anual. No pude abrir la nota original (el sitio bloquea el acceso), así que la tomo del resumen del buscador y no sé de qué fecha es.

**La interferencia entre pozos vecinos está estudiada en Vaca Muerta.** Un trabajo presentado en el congreso del IAPG en 2022 analizó 107 pozos "padres" y 80 "hijos" en Loma Campana: cuando se fractura un pozo nuevo al lado de uno que ya produce, las fracturas se comunican y el pozo nuevo puede rendir menos.

**El transporte estuvo al límite.** La ampliación del oleoducto de Oldelval se inauguró en marzo de 2025 y a mediados de 2026 el sistema volvía a estar cerca de su tope.

### Las explicaciones, puestas a prueba

**1. "Se perfora en zonas menos buenas." Es cierto solo en parte.**

Llamo áreas históricas a las cuatro que concentran la producción. En 2021 recibían el 76 % de los pozos nuevos; en 2025, el 47 %. Y fuera de ellas el rendimiento por kilómetro es menor. Hasta ahí coincide.

Pero al separar los dos grupos aparece otra cosa:

| Año | Áreas históricas (m³ por km) | Resto (m³ por km) |
|---|---|---|
| 2021 | 17.211 | 12.629 |
| 2023 | 15.526 | 12.460 |
| 2025 | 13.212 | 12.045 |

**La caída está dentro de las áreas históricas** (23 % menos), mientras el resto casi no se movió. En 2025 las mejores zonas rinden por kilómetro apenas un 10 % más que las nuevas. Área por área: Bajada del Palo Oeste pasó de 20.379 a 14.361 y Loma Campana de 18.136 a 14.083. Entonces el problema no es solo irse a zonas peores: las zonas buenas ya no rinden como antes.

**2. "Los pozos nuevos compiten con los vecinos." No lo pude confirmar.**

Conté, para cada pozo, cuántos pozos al menos un año más viejos tiene a menos de 1,5 km. Si la interferencia fuera fuerte, los pozos rodeados deberían rendir menos. No pasa: los que no tienen vecinos dan 13.503 m³ por km y los que tienen 16 o más dan 15.604. Solo en Bajada del Palo Oeste se ve el efecto esperado (19.536 contra 15.041).

Mi medición es tosca: uso la ubicación de la boca del pozo, no por dónde va la rama bajo tierra, y los pozos rodeados suelen estar en la mejor roca. No descarta la interferencia; dice que con este dato no se ve.

**3. "Doce meses es poco para juzgar un pozo largo." No.**

Repetí la cuenta a 24 meses: el rendimiento por kilómetro cae igual, de 25.094 (pozos de 2019) a 19.591 (pozos de 2024). Y los pozos largos no declinan más lento: el segundo año rinde la mitad del primero, sea cual sea el largo.

**4. Un dato que no esperaba: el mejor mes de un pozo no crece.**

El mes de mayor producción de un pozo típico está clavado entre 5.600 y 5.800 m³ desde 2021, aunque la rama creció 16 %. Es lo que se esperaría si las empresas limitaran el caudal inicial (por cuidado del pozo o por capacidad de las instalaciones), pero también si simplemente el tramo extra de rama aporta poco. Los datos no distinguen entre las dos.

### Lo que me queda

- **Confirmado:** la mejora hasta 2020 y la caída por kilómetro desde 2021 son reales y otros las vieron.
- **Parcialmente explicado:** irse a zonas nuevas explica una parte menor. La mayor parte de la caída ocurre en las áreas históricas.
- **Descartado:** que sea un efecto de mirar solo 12 meses.
- **Abierto:** por qué las áreas históricas rinden menos por kilómetro. Las candidatas son la interferencia entre vecinos, que mi dato no alcanza a medir, y el límite de caudal.

**Cómo seguiría:** la Secretaría publica las trayectorias de los pozos de Vaca Muerta (el recorrido de cada rama). Con eso se puede medir la distancia real entre ramas vecinas y probar bien la interferencia.

### Fuentes

- LM Neuquén (16 de enero de 2021), "La evolución de los pozos que hizo rentable Vaca Muerta", con datos de FDC: https://mase.lmneuquen.com/pozos/la-evolucion-los-pozos-que-hizo-rentable-vaca-muerta-n764268
- Mamani, Rosemblat y Álvarez Castillo (2022), "Evaluación de frac-hits y su impacto en Loma Campana", IAPG: https://biblioteca.iapg.org.ar/bib/195890
- Enverus, "Vaca Muerta: the global shale game changer" (no pude abrirla; cito el resumen del buscador): https://www.enverus.com/blog/vaca-muerta-the-global-shale-game-changer/
- EconoJournal, sobre la capacidad de Oldelval: https://econojournal.com.ar/?p=131806

## 16. Lo que sigue

- Armar y publicar el tablero en Tableau Public.
- Probar la interferencia entre pozos con el dataset de trayectorias.
