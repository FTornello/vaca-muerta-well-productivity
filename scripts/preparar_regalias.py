"""Convierte los informes de regalías de petróleo y de gas en CSV ordenados.

La Secretaría de Energía publica un Excel por producto con tres tablas
(regalías, precio y producción), una columna por provincia y una fila por mes.
Este script las pasa a formato largo, una fila por mes y provincia, y escribe:

  data/regalias_petroleo.csv   regalías en dólares, precio en USD/m3, producción en m3
  data/regalias_gas.csv        regalías en pesos, precio en pesos por mil m3, producción en miles de m3

El gas viene en pesos porque así lo publica la fuente; la conversión a dólares
se hace en la base con el tipo de cambio oficial de cada mes.
"""
import warnings
import zipfile
from pathlib import Path

import pandas as pd

warnings.filterwarnings("ignore", message="Slicer List extension")

RAIZ = Path(__file__).resolve().parent.parent
ORIGEN = RAIZ / "data" / "raw" / "regalias"

PRODUCTOS = {
    "petroleo": ("Regalias_CRUDO.zip", {"Tabla regalías": "regalias_usd",
                                        "Tabla precios": "precio_usd_m3",
                                        "Tabla producción": "produccion_m3"}),
    "gas": ("Regalias_GAS.zip", {"Tabla regalías": "regalias_ars",
                                 "Tabla precios": "precio_ars_mil_m3",
                                 "Tabla producción": "produccion_miles_m3"}),
}


def leer_tabla(libro, hoja, medida):
    crudo = libro.parse(hoja, header=None)
    fila_titulos = crudo.index[crudo[0].astype(str).str.strip().eq("AÑO")][0]
    tabla = crudo.iloc[fila_titulos + 1:].copy()
    tabla.columns = ["anio", "mes"] + [str(c).strip() for c in crudo.iloc[fila_titulos, 2:]]
    tabla["anio"] = tabla["anio"].ffill()          # el año solo figura en la fila de enero
    tabla = tabla[pd.to_numeric(tabla["mes"], errors="coerce").between(1, 12)]
    largo = tabla.melt(id_vars=["anio", "mes"], var_name="provincia", value_name=medida)
    largo = largo[~largo["provincia"].str.startswith("TOTAL")]
    largo[medida] = pd.to_numeric(largo[medida], errors="coerce")
    return largo.astype({"anio": int, "mes": int}).set_index(["anio", "mes", "provincia"])


for producto, (archivo, tablas) in PRODUCTOS.items():
    with zipfile.ZipFile(ORIGEN / archivo) as z, z.open(next(n for n in z.namelist() if n.endswith(".xlsx"))) as f:
        libro = pd.ExcelFile(f)
        regalias = pd.concat([leer_tabla(libro, hoja, medida) for hoja, medida in tablas.items()], axis=1)

    # Los meses todavía no informados vienen en cero.
    produccion = list(tablas.values())[2]
    regalias = regalias[regalias[produccion].fillna(0) > 0].reset_index()
    regalias["provincia"] = regalias["provincia"].str.title()
    salida = RAIZ / "data" / f"regalias_{producto}.csv"
    regalias.to_csv(salida, index=False)
    print(f"{producto}: {len(regalias)} filas, de {regalias.anio.min()} a {regalias.anio.max()} -> {salida.name}")
