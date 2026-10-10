#!/bin/bash
# Reconstruye la base completa desde los CSV de data/raw/ y corre los controles.
# Requiere PostgreSQL con una base llamada vaca_muerta (createdb vaca_muerta).
# El paso de trayectorias tarda unos dos minutos.
set -euo pipefail
cd "$(dirname "$0")/.."

for archivo in 01_raw_tablas 02_raw_carga 03_capa_limpia 04_controles 05_vistas_analisis 07_trayectorias; do
    echo "== sql/$archivo.sql"
    psql -q -d vaca_muerta -v ON_ERROR_STOP=1 -P pager=off -f "sql/$archivo.sql"
done
