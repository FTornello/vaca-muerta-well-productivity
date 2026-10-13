"""Convierte las planillas anuales de reservas en un solo CSV ordenado.

La Secretaría de Energía publica un Excel por año con las reservas de cada
yacimiento al 31 de diciembre. Este script lee la hoja "hasta el fin de la vida
útil" de cada uno (2017 a 2025), se queda con la cuenca Neuquina y las columnas
de recursos no convencionales, y escribe data/reservas_no_convencional.csv.

Unidades de la fuente: petróleo en miles de m3, gas en millones de m3.
"""
import zipfile
from pathlib import Path

import pandas as pd

RAIZ = Path(__file__).resolve().parent.parent
ORIGEN = RAIZ / "data" / "raw" / "reservas"
SALIDA = RAIZ / "data" / "reservas_no_convencional.csv"

IDENTIFICACION = ["operador", "cuenca", "provincia", "concesion", "yacimiento"]
# En todas las planillas el bloque NO CONVENCIONAL son 8 columnas seguidas.
MEDIDAS = ["petroleo_comprobadas", "gas_comprobadas", "petroleo_probables", "gas_probables",
           "petroleo_posibles", "gas_posibles", "petroleo_recursos", "gas_recursos"]


def leer_planilla(archivo_zip):
    with zipfile.ZipFile(archivo_zip) as z:
        nombre = next(n for n in z.namelist() if n.endswith(".xlsx"))
        with z.open(nombre) as f:
            libro = pd.ExcelFile(f)
            hoja = next(h for h in libro.sheet_names if "vida" in h.lower())
            crudo = libro.parse(hoja, header=None)

    anio = int(str(crudo.iloc[0].dropna().iloc[0]).split("/")[2][:4])

    # La fila de títulos es la que dice OPERADOR; dos filas más arriba, el
    # encabezado NO CONVENCIONAL marca dónde empieza ese bloque.
    fila_titulos = crudo.index[crudo[0].astype(str).str.strip().eq("OPERADOR")][0]
    grupos = crudo.iloc[:fila_titulos].astype(str).apply(lambda col: col.str.strip())
    inicio = next(c for c in crudo.columns if grupos[c].eq("NO CONVENCIONAL").any())

    datos = crudo.iloc[fila_titulos + 1:, list(range(5)) + list(range(inicio, inicio + 8))].copy()
    datos.columns = IDENTIFICACION + MEDIDAS
    datos = datos[datos["cuenca"].astype(str).str.strip().str.upper().eq("NEUQUINA")]
    for columna in IDENTIFICACION:
        datos[columna] = datos[columna].astype(str).str.strip().str.replace(r"\s+", " ", regex=True)
    datos[MEDIDAS] = datos[MEDIDAS].apply(pd.to_numeric, errors="coerce").fillna(0)
    datos = datos[datos[MEDIDAS].abs().sum(axis=1) > 0]
    datos.insert(0, "anio", anio)
    return datos


planillas = [leer_planilla(z) for z in sorted(ORIGEN.glob("*.zip")) if "2016" not in z.name]
reservas = pd.concat(planillas).sort_values(["anio", "concesion", "yacimiento"])
reservas.to_csv(SALIDA, index=False)
print(f"{len(reservas)} filas, años {reservas.anio.min()} a {reservas.anio.max()} -> {SALIDA}")
