"""Junta los tres CSV del tablero en un solo Excel con tres hojas.

Tableau lee los CSV según el idioma de la computadora: con la configuración
regional de Argentina espera coma decimal y puede leer mal las coordenadas y
los decimales, que vienen con punto. En un Excel los números ya van guardados
como números, así que ese problema desaparece.

Lee dashboard/datos/*.csv (los genera sql/06_exportar_dashboard.sql) y escribe
dashboard/datos/vaca_muerta_tablero.xlsx.
"""
from pathlib import Path

import pandas as pd

DATOS = Path(__file__).resolve().parent.parent / "dashboard" / "datos"
SALIDA = DATOS / "vaca_muerta_tablero.xlsx"

pozos = pd.read_csv(DATOS / "pozos.csv")
pozos["diseno_confiable"] = pozos["diseno_confiable"].map({"t": "sí", "f": "no"})
curva = pd.read_csv(DATOS / "curva_por_edad.csv")
areas = pd.read_csv(DATOS / "produccion_por_area.csv", parse_dates=["mes"])
areas["mes"] = areas["mes"].dt.date

with pd.ExcelWriter(SALIDA, engine="openpyxl") as libro:
    pozos.to_excel(libro, sheet_name="pozos", index=False)
    curva.to_excel(libro, sheet_name="curva_por_edad", index=False)
    areas.to_excel(libro, sheet_name="produccion_por_area", index=False)

print(f"{len(pozos)} pozos, {len(curva)} filas de curva, {len(areas)} filas por área -> {SALIDA.name}")
