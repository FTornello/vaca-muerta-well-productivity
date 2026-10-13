#!/bin/bash
# Reconstruye la base completa desde los CSV de data/raw/ y corre los controles.
# Requiere PostgreSQL con una base llamada vaca_muerta (createdb vaca_muerta).
# El paso de trayectorias tarda unos dos minutos.
set -euo pipefail
cd "$(dirname "$0")/.."

correr() {
    echo "== sql/$1.sql"
    psql -q -d vaca_muerta -v ON_ERROR_STOP=1 -P pager=off -f "sql/$1.sql"
}

for archivo in 01_raw_tablas 02_raw_carga 03_capa_limpia 04_controles 05_vistas_analisis \
               07_trayectorias 08_datos_complementarios 09_regalias_y_empleo 11_curva_tipo \
               13_comercio_exterior 14_contexto_pais \
               15_pronosticos_venteo_perforacion 16_refinacion_gas_y_declarados \
               17_referencias_externas; do
    correr "$archivo"
done

# El ajuste de la curva de declinación se hace en Python: lee la curva tipo que
# acaba de exportar la base y deja el resultado para el paso siguiente.
echo "== scripts/ajustar_declinacion.py"
python3 scripts/ajustar_declinacion.py

correr 12_declinacion
correr 10_controles_complementarios
