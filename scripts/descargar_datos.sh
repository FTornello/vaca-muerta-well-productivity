#!/bin/bash
# Descarga todas las fuentes del proyecto de la Secretaría de Energía a data/raw/.
# La fuente se actualiza todos los meses: los números del análisis corresponden
# a la descarga del 9 de octubre de 2026 (producción hasta agosto de 2026).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/raw

API=http://datos.energia.gob.ar/api/3/action/resource_show

bajar() {
    local url
    url=$(curl -s "$API?id=$1" | python3 -c 'import sys, json; print(json.load(sys.stdin)["result"]["url"])')
    echo "Descargando $2"
    curl -L -sS --retry 3 -o "data/raw/$2" "$url"
}

bajar b5b58cdc-9e07-41f9-b392-fb9ec68b0725 produccion_no_convencional.csv
bajar 2280ad92-6ed3-403e-a095-50139863ab0d fractura_adjunto_iv.csv
bajar cb5c0f04-7835-45cd-b982-3e25ca7d7751 padron_pozos_capitulo_iv.csv
bajar 94741ac7-4f46-4efe-b112-d3f82a4ef7c5 trayectorias_vaca_muerta.csv
bajar d87ca6ab-2979-474b-994a-e4ba259bb217 precios_gas_natural.csv
bajar f1d13dac-fca5-4464-940d-ce86c16cbff3 transporte_ductos_planilla20.csv
bajar c0a6f94a-6052-48db-9dc8-4d6ce64ecf62 inversiones_upstream_mensual.csv
bajar 2144967c-07c5-4ec1-8659-21bd7c1ba89e terminales_maritimas_planilla21.csv

# Reservas: un ZIP con un Excel por año. scripts/preparar_reservas.py los
# convierte en data/reservas_no_convencional.csv (ese CSV ya viene en el repo).
RESERVAS=http://www.energia.gob.ar/contenidos/archivos/Reorganizacion/informacion_del_mercado/mercado_hidrocarburos/informacion_estadistica/reservas
mkdir -p data/raw/reservas
for zip in Reservas_HFVUY_31122017.zip reservas_hfvuy_31122018.zip reservas_cpcy_al_31_12_2019.zip \
           reservas_al_31-12-2020.zip reservas_al_31-12-2021.zip reservas_al_31-12-2022.zip \
           reservas_al_31-12-2023.zip reservas_al_31-12-2024.zip reservas_al_31-12-2025.zip; do
    echo "Descargando $zip"
    curl -L -sS --retry 3 -o "data/raw/reservas/$zip" "$RESERVAS/$zip"
done
python3 scripts/preparar_reservas.py

# Regalías de petróleo y de gas: un Excel dentro de cada ZIP.
# scripts/preparar_regalias.py los convierte en data/regalias_petroleo.csv y
# data/regalias_gas.csv (esos CSV ya vienen en el repo).
mkdir -p data/raw/regalias
REGALIAS=http://www.energia.gob.ar/contenidos/archivos/Reorganizacion/informacion_del_mercado/mercado_hidrocarburos/informacion_estadistica/regalias
for zip in Regalias_CRUDO.zip Regalias_GAS.zip; do
    echo "Descargando $zip"
    curl -L -sS --retry 3 -o "data/raw/regalias/$zip" "$REGALIAS/$zip"
done
python3 scripts/preparar_regalias.py

# Empleo y salarios por departamento y sector (CEP XXI, Secretaría de
# Producción). Los archivos nacionales pesan 95 MB cada uno: se guardan solo las
# filas de la provincia de Neuquén (código 58).
CEP=https://cdn.produccion.gob.ar/cdn-cep
echo "Descargando empleo y salarios de Neuquén"
curl -sS "$CEP/datos-por-departamento/puestos/puestos_depto_priv_por_clae2.csv" \
    | awk -F, 'NR==1 || $3==58' > data/raw/empleo_neuquen_por_depto_clae2.csv
curl -sS "$CEP/datos-por-departamento/salarios/w_median_depto_priv_clae2.csv" \
    | awk -F, 'NR==1 || $3==58' > data/raw/salario_mediano_neuquen_por_depto_clae2.csv
curl -sS -o data/raw/diccionario_departamentos.csv "$CEP/datos-por-departamento/diccionario_cod_depto.csv"
curl -sS -o data/raw/diccionario_clae.csv "$CEP/clae_agg.csv"

# Tipo de cambio oficial (Banco Nación, vendedor), promedio mensual.
echo "Descargando tipo de cambio"
curl -sS -o data/raw/tipo_de_cambio_bna.csv \
    "https://apis.datos.gob.ar/series/api/series/?ids=168.1_T_CAMBIOR_D_0_0_26&collapse=month&collapse_aggregation=avg&start_date=2010-01-01&limit=500&format=csv"

# Comercio exterior de energía del país (INDEC): exportaciones de combustibles y
# energía, importaciones de combustibles y lubricantes, y saldo comercial total.
echo "Descargando comercio exterior de energía"
curl -sS -o data/raw/comercio_energia_indec.csv \
    "https://apis.datos.gob.ar/series/api/series/?ids=74.3_IECE_0_M_35,74.3_IICL_0_M_42,74.3_ISC_0_M_19&start_date=2010-01-01&limit=500&format=csv"

# Producción de petróleo y gas de todo el país y crudo procesado en refinerías
# (Secretaría de Energía, publicadas como series de tiempo).
echo "Descargando producción y refinación del país"
curl -sS -o data/raw/pais_petroleo_gas_refinacion.csv \
    "https://apis.datos.gob.ar/series/api/series/?ids=363.3_PRODUCCIONUDO__28,363.3_PETROLEO_CADO__24,364.3_PRODUCCIoNRAL__25&start_date=2010-01-01&limit=500&format=csv"

# Pronósticos de producción que declaran las empresas, anomalías térmicas
# detectadas por satélite (venteo) y metros perforados por provincia.
PORTAL=http://datos.energia.gob.ar/dataset
echo "Descargando pronósticos, venteos detectados y metros perforados"
curl -sS -o data/raw/pronostico_petroleo.csv \
    "$PORTAL/dbb36686-fb66-4364-bded-d55ff4de516c/resource/9817510c-e50b-4650-bc22-01018f108579/download/pronstico-de-produccin-de-petrleo.csv"
curl -sS -o data/raw/venteos_detectados.csv \
    "$PORTAL/7ef45681-a7de-440c-a343-b7d989261b58/resource/a094f5c6-3ba9-4faf-88f3-726e4ef03a98/download/sensores-remotos-venteos-detectados.csv"
curl -sS -o data/raw/metros_perforados_por_provincia.csv \
    "$PORTAL/7ea2ac77-d7a0-4129-9fbf-6f1a25d94e21/resource/aadbd15a-324c-4cfc-a223-d5ac3f9dfbf2/download/metros-perforados-por-provincia.csv"

# Crudo procesado por refinería y origen, pronósticos de gas, puntos de venteo
# declarados y pozos terminados por provincia.
echo "Descargando refinación, pronósticos de gas, puntos de venteo y pozos terminados"
curl -sS -o data/raw/productos_procesados.csv \
    "$(curl -sS "$API?id=23e6d79d-0cf3-4b4c-bb5a-d776bece8ffd" | python3 -c "import sys, json; print(json.load(sys.stdin)['result']['url'])")"
curl -sS -o data/raw/pronostico_gas.csv \
    "$PORTAL/dbb36686-fb66-4364-bded-d55ff4de516c/resource/1f9412c3-e265-4d65-a3c0-6e4b10ed9af4/download/pronstico-de-produccin-de-gas-natural.csv"
curl -sS -o data/raw/venteo_puntos_declarados.csv \
    "$PORTAL/530bb019-32f4-4eaf-b550-1fc05f8b129f/resource/c3812323-0c38-43b7-8bc6-f05fb5113626/download/produccin-hidrocarburos-puntos-de-venteo-declarados.csv"
curl -sS -o data/raw/pozos_terminados_por_provincia.csv \
    "$PORTAL/7ea2ac77-d7a0-4129-9fbf-6f1a25d94e21/resource/dcdae9c2-c233-46e5-a1fc-19bdfca7d99c/download/pozos-terminados-por-concepto-y-provincia-desde-2009.csv"

# Referencias de afuera (EIA de Estados Unidos): precio del Brent y producción
# de las cuencas de shale de ese país.
python3 scripts/preparar_eia.py

# Precios en estaciones de servicio: se le pide a la API del portal el resumen
# mensual por provincia y producto, en vez de bajar dos millones de filas.
python3 scripts/descargar_precios_surtidor.py

# Deja constancia de qué se bajó y cuándo.
python3 scripts/registrar_fuentes.py
