# Guía para armar el tablero en Tableau Public

El objetivo es un tablero de una pantalla con cuatro gráficos y un mapa. La imagen [boceto_resultados.png](boceto_resultados.png) muestra los cuatro gráficos con los datos reales: usala para comparar lo que te va quedando.

Los nombres de menús están en español; si tu Tableau está en inglés, el equivalente va entre paréntesis.

## 0. Conectar los datos

Los tres archivos están en `dashboard/datos/`.

1. Abrí Tableau Public. En **Conectar** (Connect) elegí **Archivo de texto** (Text file) y abrí `pozos.csv`.
2. Arriba, en **Datos > Nueva fuente de datos** (Data > New Data Source), agregá `curva_por_edad.csv` y después `produccion_por_area.csv`. Quedan tres fuentes separadas; no las unas.
3. **Revisá los decimales.** Los archivos usan punto decimal. En la fuente `pozos`, mirá la columna `latitud`: tiene que verse como `-38,35` o `-38.35`, no como `-3835160`. Si se ve mal, hacé clic derecho en el archivo dentro del lienzo, **Propiedades del archivo de texto** (Text File Properties) y poné **Configuración regional: Inglés (Estados Unidos)**.
4. En la fuente `pozos`, convertí a **dimensión** estos campos (arrastrándolos arriba de la línea, o clic derecho > Convertir a dimensión): `pozo_id`, `anio_arranque`.
5. En `curva_por_edad`, convertí a dimensión: `pozo_id`, `anio_arranque`, `mes_de_vida`.

## 1. Hoja "Curva típica" (fuente `curva_por_edad`)

Responde: ¿cómo produce un pozo típico y cambió con los años?

1. `mes_de_vida` a **Columnas**. Clic derecho sobre la pastilla > **Continuo**.
2. `petroleo_m3` a **Filas**. Clic derecho > **Medida > Promedio**.
3. `anio_arranque` a **Color**.
4. Arrastrá `anio_arranque` a **Filtros** y dejá marcados 2016, 2018, 2020, 2022 y 2024.
5. Arrastrá `mes_de_vida` a **Filtros** y elegí del 1 al 12.
6. En **Color > Editar colores**, elegí una paleta de un solo tono (por ejemplo "Azul") para que los años se lean de más claro a más oscuro.

Qué tenés que ver: cinco curvas con pico en el mes 3 o 4. La de 2016 es la más baja; las de 2020, 2022 y 2024 quedan casi encimadas.

## 2. Hoja "Diseño y rendimiento" (fuente `pozos`)

Responde: ¿los pozos más grandes rinden más?

1. Arrastrá `diseno_confiable` a **Filtros** y dejá solo `t`.
2. Arrastrá `anio_arranque` a **Filtros** y elegí de 2018 a 2025.
3. `anio_arranque` a **Columnas**.
4. A **Filas**, uno debajo del otro: `rama_m`, `arena_tn`, `petroleo_12m_m3`, `petroleo_por_km_m3`. En cada uno, clic derecho > **Medida > Mediana**.
5. En **Marcas** (Marks) elegí **Línea**.

Quedan cuatro gráficos chicos apilados, cada uno con su propia escala. No los combines en un eje doble: dos escalas en un mismo gráfico confunden.

Qué tenés que ver: rama y arena suben todos los años; el petróleo del primer año se aplana desde 2021; el petróleo por kilómetro baja desde 2021.

## 3. Hoja "Operadoras" (fuente `pozos`)

Responde: ¿qué operadora saca más por pozo?

1. Arrastrá `anio_arranque` a **Filtros** y elegí de 2021 a 2025.
2. `operadora` a **Filas**.
3. `petroleo_12m_m3` a **Columnas**, con **Medida > Mediana**.
4. Para dejar solo las que tienen 15 pozos o más: arrastrá `pozo_id` a **Filtros**, elegí **Recuento (definido)** (Count Distinct) y poné mínimo 15.
5. Ordená de mayor a menor con el botón de orden de la barra de herramientas.
6. Arrastrá `pozo_id` a **Etiqueta** (Label) con **Recuento (definido)**, para que cada barra muestre cuántos pozos tiene.

Qué tenés que ver: ocho barras. Vista primera con 43.792; Tecpetrol última con 21.467.

## 4. Hoja "Áreas" (fuente `produccion_por_area`)

Responde: ¿de dónde sale el petróleo?

1. `mes` a **Columnas**. Clic derecho > **Año** (la opción continua, la de abajo).
2. `petroleo_m3` a **Filas** (queda como Suma).
3. En **Marcas** elegí **Área**.
4. Para no tener 93 colores, creá un grupo: clic derecho en `area` > **Crear > Conjunto** (Create > Set), pestaña **Superior** (Top), **Por campo**, los 4 primeros por `petroleo_m3` Suma. Llamalo "Top 4".
5. Creá un campo calculado (**Análisis > Crear campo calculado**) llamado `Área agrupada`:

   ```
   IF [Top 4] THEN [area] ELSE "Resto" END
   ```

6. Arrastrá `Área agrupada` a **Color**.

Qué tenés que ver: un área que crece fuerte desde 2019. Loma Campana es la franja más grande al principio y "Resto" va ganando lugar hacia 2025 y 2026.

## 5. Hoja "Mapa" (fuente `pozos`)

1. Clic derecho en `latitud` > **Rol geográfico > Latitud**. Lo mismo con `longitud` > **Longitud**.
2. Doble clic en `latitud` y después en `longitud`. Aparece un mapa con un solo punto.
3. Arrastrá `pozo_id` a **Detalle** (Detail). Ahora hay un punto por pozo.
4. Arrastrá `petroleo_12m_m3` a **Color**.
5. Arrastrá `sigla`, `area` y `operadora` a **Descripción emergente** (Tooltip).
6. En **Tamaño** (Size) achicá un poco los puntos.

Qué tenés que ver: una nube de pozos al noroeste de la ciudad de Neuquén, con los más oscuros concentrados en la zona de Loma Campana y Bajada del Palo.

## 6. Armar el tablero

1. Abajo, clic en el ícono **Nuevo dashboard**.
2. En **Tamaño** (Size) elegí **Automático**.
3. Arrastrá las hojas: arriba "Curva típica" y "Diseño y rendimiento"; abajo "Operadoras", "Áreas" y "Mapa".
4. Agregá un objeto de **Texto** arriba de todo con el título: *¿Qué hace que un pozo de Vaca Muerta rinda más?*
5. En cada hoja, cambiá el título por la conclusión, no por la descripción. Por ejemplo "Pozos cada vez más grandes, sin rendir más" en vez de "Diseño por año".
6. Abajo, un texto chico con la fuente: *Secretaría de Energía de la Nación, datos a agosto de 2026. Pozos horizontales petrolíferos.*

## 7. Publicar

**Archivo > Guardar en Tableau Public** (File > Save to Tableau Public). Te pide iniciar sesión con tu cuenta. Al terminar se abre el tablero en el navegador: copiá ese enlace, que va en el README.
