# ¿Qué hace que un pozo de Vaca Muerta rinda más?

Análisis en SQL de los 3.417 pozos de la formación Vaca Muerta con datos abiertos de la Secretaría de Energía de Argentina: producción mes a mes de cada pozo, diseño de cada fractura y recorrido de cada rama bajo tierra, de 2006 a agosto de 2026.

## La respuesta

**Ni el diseño, ni la operadora, ni el lugar alcanzan por sí solos.** El lugar y el diseño explican cerca de un quinto de las diferencias cada uno, la operadora no se puede separar del lugar, y aun sumando el nivel de la roca donde navega cada pozo, cerca del 60 % de las diferencias no lo explica nada de lo que se publica.

**[Ver el tablero interactivo en Tableau Public](https://public.tableau.com/views/vaca_muerta_tablero/QuhacequeunpozodeVacaMuertarindams)**

[![Tablero de Tableau](dashboard/tablero_tableau.jpg)](https://public.tableau.com/views/vaca_muerta_tablero/QuhacequeunpozodeVacaMuertarindams)

![Los cuatro hallazgos](dashboard/boceto_resultados.png)

## Los cuatro hallazgos

1. **El pozo típico más que duplicó su rendimiento entre 2016 y 2021, y después se estancó.** El petróleo del primer año pasó de 17.300 a 38.200 m³ y desde entonces se mueve entre 36.000 y 40.000.

2. **Desde 2021 los pozos son cada vez más grandes sin rendir más.** La rama horizontal se alargó 22 % y la arena inyectada subió 43 %, con la misma producción. Cada kilómetro de rama rinde 22 % menos.

3. **El ranking de operadoras es también un ranking de lugares.** Vista lidera con 43.800 m³ por pozo en el primer año, pero cada área la opera una sola empresa, así que no se puede saber cuánto es mérito propio y cuánto es la roca. YPF saca 42.500 m³ por pozo en Loma Campana y 28.900 en Bajo del Toro Norte.

4. **Cuatro áreas de 93 produjeron el 62 % del petróleo histórico**, y pierden peso: en los últimos 12 meses suman 49 %.

| Año de arranque | Pozos | Rama (m) | Arena (t) | Petróleo 1er año (m³) | Por km de rama (m³) |
|---|---|---|---|---|---|
| 2016 | 66 | 1.411 | 4.252 | 17.455 | 13.306 |
| 2019 | 105 | 2.250 | 7.931 | 33.511 | 16.846 |
| 2021 | 162 | 2.518 | 8.218 | 38.573 | 16.307 |
| 2023 | 216 | 2.684 | 10.226 | 37.861 | 14.797 |
| 2025 | 291 | 3.065 | 11.761 | 38.533 | 12.695 |

*Medianas de pozos horizontales petrolíferos con datos de fractura completos.*

## Límites

- **Son asociaciones, no causas.** Que los pozos más largos rindan menos por kilómetro puede deberse al diseño, a roca menos buena o a que las empresas regulen el caudal. Estos datos no lo separan.
- **La pregunta central se responde con pozos de petróleo.** Los de gas son una cuarta parte de los horizontales.
- **Solo se comparan pozos con 12 meses cumplidos.** 2025 incluye los que arrancaron hasta septiembre; 2026 no entra.
- **La agrupación de empresas es manual:** uní razones sociales de la misma marca, sin seguir compras entre empresas distintas.
- **Las trayectorias cubren más del 90 % de los pozos hasta 2023,** pero 44 % de los de 2024 y 25 % de los de 2025.

---

## Más análisis

Lo que sigue profundiza la respuesta. Cada punto tiene su consulta y su sección en la [bitácora](BITACORA.md).

### Por qué cae el rendimiento por kilómetro

- **Los números coinciden con los de la industria.** La consultora FDC estimó la producción a 365 días del pozo tipo en 17.000 m³ para 2016 y 27.800 para 2018; mis medianas dan 17.323 y 27.125.
- **"Se perfora en zonas menos buenas" explica solo una parte.** La caída ocurre sobre todo dentro de las cuatro áreas históricas (de 17.211 a 13.212 m³ por km entre 2021 y 2025); en el resto casi no cambió.
- **No es un efecto de mirar solo 12 meses.** A 24 meses la caída es la misma.

Consulta: [p6](sql/analisis/p6_por_que_cae_el_rendimiento.sql). Bitácora, sección 15.

### Lo que pasa bajo tierra

- **El nivel de la roca importa.** En la misma área, los pozos que navegan en la unidad inferior de Vaca Muerta rinden entre 10 % y 47 % más por kilómetro que los de la unidad media.
- **La interferencia entre pozos vecinos existe.** Midiendo la distancia real entre ramas, un pozo con un "padre" del mismo nivel a menos de 300 metros rinde cerca de 15 % menos.
- **Sumar el nivel lleva lo explicado de 35 % a 39 %.**

Consulta: [p7](sql/analisis/p7_subsuelo.sql). Bitácora, sección 17.

### La fábrica de pozos

Las etapas de fractura pasaron de 3.244 en 2017 a 23.410 en 2025, y la velocidad de 0,9 a 2,2 etapas por día. Aun así, de empezar a perforar a producir siguen pasando unos 213 días: la velocidad ganada se usó en hacer pozos más grandes, y hay una espera de 70 días entre perforar y fracturar que no baja.

Consulta: [p8](sql/analisis/p8_fabrica_de_pozos.sql). Bitácora, sección 18.

### El gas y las estaciones

Entre el pico de invierno y el valle de primavera, los pozos de gas bajaron 14 % en 2022 y 36 % en 2025. Mientras tanto, el gas que sale junto con el petróleo, y que no se puede cerrar, más que se duplicó en dos años y medio.

Consulta: [p9](sql/analisis/p9_gas.sql). Bitácora, sección 19.

---

## Cómo está hecho

Cuatro tablas de la fuente (producción, fractura, padrón de pozos y trayectorias) cargadas en PostgreSQL en dos capas:

- **`raw`**: los CSV tal cual se publican.
- **`vm`**: un modelo limpio de seis tablas (`pozo`, `produccion_mensual`, `fractura`, `area`, `empresa`, `operadora`) más tres de trayectorias, con ocho controles que verifican que no se perdió nada respecto de la fuente.

Los valores imposibles no se borran: quedan marcados con su motivo, y cada consulta decide qué excluir.

| Archivo | Qué hace |
|---|---|
| [sql/01_raw_tablas.sql](sql/01_raw_tablas.sql), [02_raw_carga.sql](sql/02_raw_carga.sql) | Crea la capa `raw` y carga los CSV |
| [sql/03_capa_limpia.sql](sql/03_capa_limpia.sql) | Construye el modelo limpio y aplica las reglas de limpieza |
| [sql/04_controles.sql](sql/04_controles.sql) | Compara la fuente contra el modelo |
| [sql/05_vistas_analisis.sql](sql/05_vistas_analisis.sql) | Vistas de apoyo: edad del pozo y producción del primer año |
| [sql/07_trayectorias.sql](sql/07_trayectorias.sql) | Arma la rama de cada pozo punto por punto y mide distancias entre vecinos |
| [sql/analisis/](sql/analisis) | Una consulta por pregunta |
| [sql/06_exportar_dashboard.sql](sql/06_exportar_dashboard.sql) | Exporta las tablas que usa el tablero |

Para entender los datos: [diccionario](DICCIONARIO.md). Para entender las decisiones: [bitácora](BITACORA.md).

## Cómo reproducirlo

Requiere PostgreSQL 17 y Python 3.

```bash
./scripts/descargar_datos.sh
createdb vaca_muerta
./scripts/reconstruir.sh
psql -d vaca_muerta -f sql/analisis/p1_curva_tipica.sql
```

La fuente se actualiza todos los meses, así que una descarga nueva va a dar números algo distintos. Los de este análisis corresponden a la descarga del 9 de octubre de 2026.

## Fuente

Secretaría de Energía de la Nación: [Producción de petróleo y gas por pozo (Capítulo IV)](http://datos.energia.gob.ar/dataset/produccion-de-petroleo-y-gas-por-pozo), [Datos de fractura de pozos (Adjunto IV)](http://datos.energia.gob.ar/dataset/datos-de-fractura-de-pozos-adjunto-iv) y [Trayectorias de Pozo Vaca Muerta](http://datos.energia.gob.ar/dataset/trayectoria-de-pozos). Unidades: petróleo y agua en m³, gas en miles de m³.

Francisco Tornello, 2026. Trabajé con Claude Code como asistente.

## Licencia

El código se publica bajo licencia [MIT](LICENSE). Los datos son públicos y pertenecen a la Secretaría de Energía de la Nación.
