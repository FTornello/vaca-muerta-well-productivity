"""Baja los precios de combustibles en estaciones de servicio, ya resumidos.

La Secretaría de Energía publica lo que informa cada estación cada mes
(Resolución 1104/04): unas 250.000 filas por año. En vez de bajar todo, este
script le pide a la API del portal el resumen que se necesita: para cada mes,
provincia y producto, la mediana del precio en surtidor y del precio sin
impuestos entre las estaciones que venden al público, y cuántas son.

Se usa la mediana y no un promedio ponderado por volumen porque las estaciones
no informan el volumen en la misma unidad.

Escribe data/raw/precios_surtidor_mensual.csv (2019 en adelante).
"""
import csv
import json
import urllib.parse
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "data" / "raw" / "precios_surtidor_mensual.csv"
API = "http://datos.energia.gob.ar/api/3/action"
DATASET = "precios-eess---resolucion-1104-04"
DESDE = 2019

FILTRO = """
    canal_de_comercializacion = 'Al público'
    AND precio_surtidor > 0
    AND precio_sin_impuestos > 0
    AND (producto LIKE 'Nafta (s%per)%' OR producto LIKE 'Nafta (premium)%' OR producto LIKE 'Gas Oil Grado%')
"""
MEDIDAS = """
    count(*) AS estaciones,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY precio_surtidor)::numeric, 2)      AS precio_surtidor,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY precio_sin_impuestos)::numeric, 2) AS precio_sin_impuestos
"""


def pedir(direccion):
    with urllib.request.urlopen(direccion, timeout=180) as respuesta:
        cuerpo = json.load(respuesta)
    if not cuerpo.get("success"):
        raise RuntimeError(cuerpo.get("error"))
    return cuerpo["result"]


def resumir(recurso, anio_mes):
    consulta = f"""
        SELECT {anio_mes}, provincia, producto, {MEDIDAS}
        FROM "{recurso}"
        WHERE {FILTRO}
        GROUP BY 1, 2, 3, 4
    """
    return pedir(f"{API}/datastore_search_sql?sql={urllib.parse.quote(consulta)}")["records"]


filas = []
for recurso in pedir(f"{API}/package_show?id={DATASET}")["resources"]:
    nombre = recurso["name"].strip()
    if nombre.startswith("Precios EESS desde"):
        # El archivo vigente trae el período como texto, 'AAAA/MM'.
        periodo = "split_part(periodo, '/', 1)::integer AS anio, split_part(periodo, '/', 2)::integer AS mes"
    elif nombre.startswith("Precios EESS ") and nombre[-4:].isdigit() and int(nombre[-4:]) >= DESDE:
        periodo = "anio::integer AS anio, mes::integer AS mes"
    else:
        continue
    nuevas = resumir(recurso["id"], periodo)
    print(f"{nombre}: {len(nuevas)} filas")
    filas += nuevas

# Diciembre de 2024 viene en dos archivos (el de 2024 y el vigente): se deja la
# versión que reúne más estaciones.
unicas = {}
for fila in filas:
    clave = (int(fila["anio"]), int(fila["mes"]), fila["provincia"], fila["producto"])
    if clave not in unicas or int(fila["estaciones"]) > int(unicas[clave]["estaciones"]):
        unicas[clave] = fila
filas = [unicas[clave] for clave in sorted(unicas)]

columnas = ["anio", "mes", "provincia", "producto", "estaciones", "precio_surtidor", "precio_sin_impuestos"]
with open(SALIDA, "w", newline="", encoding="utf-8") as archivo:
    escritor = csv.DictWriter(archivo, fieldnames=columnas, extrasaction="ignore")
    escritor.writeheader()
    escritor.writerows(filas)
print(f"{len(filas)} filas -> {SALIDA}")
