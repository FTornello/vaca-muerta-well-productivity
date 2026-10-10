#!/bin/bash
# Descarga los tres CSV de la Secretaría de Energía a data/raw/.
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
