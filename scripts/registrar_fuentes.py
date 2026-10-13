"""Deja constancia de qué archivos se descargaron y cuándo.

Las fuentes se actualizan todos los meses y los archivos originales no se suben
al repositorio por su tamaño. Este script recorre data/raw/ y escribe
data/FUENTES.csv con, para cada archivo: de dónde salió, fecha de descarga,
tamaño, cantidad de filas y una huella (SHA-256) que cambia si cambia el
contenido. Así se puede saber si una descarga nueva es igual a la del análisis.

Correr después de scripts/descargar_datos.sh.
"""
import csv
import hashlib
from datetime import datetime
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CRUDOS = RAIZ / "data" / "raw"
SALIDA = RAIZ / "data" / "FUENTES.csv"

ENERGIA = "Secretaría de Energía"
ORIGEN = {
    "produccion_no_convencional.csv": (ENERGIA, "Producción de petróleo y gas por pozo (Capítulo IV), no convencional"),
    "fractura_adjunto_iv.csv": (ENERGIA, "Datos de fractura de pozos (Adjunto IV)"),
    "padron_pozos_capitulo_iv.csv": (ENERGIA, "Capítulo IV - Pozos"),
    "trayectorias_vaca_muerta.csv": (ENERGIA, "Trayectorias de Pozo Vaca Muerta"),
    "precios_gas_natural.csv": (ENERGIA, "Precios de Gas Natural - Res. 1/2018"),
    "transporte_ductos_planilla20.csv": (ENERGIA, "Volúmenes de Transporte de Hidrocarburos - Planilla 20"),
    "terminales_maritimas_planilla21.csv": (ENERGIA, "Volúmenes operados por Terminales Marítimas - Planilla 21"),
    "inversiones_upstream_mensual.csv": (ENERGIA, "Resolución 2057 - Inversiones realizadas mensual"),
    "empleo_neuquen_por_depto_clae2.csv": ("CEP XXI, Secretaría de Producción", "Puestos privados por departamento y sector (solo Neuquén)"),
    "salario_mediano_neuquen_por_depto_clae2.csv": ("CEP XXI, Secretaría de Producción", "Salario mediano por departamento y sector (solo Neuquén)"),
    "diccionario_departamentos.csv": ("CEP XXI, Secretaría de Producción", "Diccionario de departamentos"),
    "diccionario_clae.csv": ("CEP XXI, Secretaría de Producción", "Diccionario de sectores (CLAE)"),
    "Regalias_CRUDO.zip": (ENERGIA, "Informe de regalías de petróleo crudo"),
    "Regalias_GAS.zip": (ENERGIA, "Informe de regalías de gas natural"),
    "tipo_de_cambio_bna.csv": ("datos.gob.ar, series de tiempo", "Tipo de cambio BNA vendedor, promedio mensual"),
    "comercio_energia_indec.csv": ("datos.gob.ar, series de tiempo (INDEC)", "Exportaciones e importaciones de energía y saldo comercial, mensual"),
    "pais_petroleo_gas_refinacion.csv": ("datos.gob.ar, series de tiempo (Secretaría de Energía)", "Producción de petróleo y gas del país y crudo procesado, mensual"),
    "pronostico_petroleo.csv": (ENERGIA, "Pronósticos de Producción de Petróleo y Gas - petróleo"),
    "venteos_detectados.csv": (ENERGIA, "Detección Satelital de Venteos - Sensores Remotos"),
    "metros_perforados_por_provincia.csv": (ENERGIA, "Perforación de pozos de petróleo y gas - Metros perforados por provincia"),
    "productos_procesados.csv": (ENERGIA, "Refinación y Comercialización - Productos procesados"),
    "pronostico_gas.csv": (ENERGIA, "Pronósticos de Producción de Petróleo y Gas - gas natural"),
    "venteo_puntos_declarados.csv": (ENERGIA, "Producción de hidrocarburos - Puntos de Venteo Declarados"),
    "pozos_terminados_por_provincia.csv": (ENERGIA, "Perforación de pozos - Pozos terminados por concepto y provincia"),
    "brent_mensual.csv": ("EIA (Estados Unidos)", "Europe Brent Spot Price FOB, mensual"),
    "henry_hub_mensual.csv": ("EIA (Estados Unidos)", "Henry Hub Natural Gas Spot Price, mensual"),
    "eeuu_tight_oil.csv": ("EIA (Estados Unidos)", "U.S. tight oil production by play, mensual"),
    "precios_surtidor_mensual.csv": (ENERGIA, "Precios y volúmenes EESS - Res. 1104/04, resumido por mes, provincia y producto"),
}


def describir(archivo):
    contenido = archivo.read_bytes()
    organismo, nombre = ORIGEN.get(archivo.name, (ENERGIA, "Reservas de Petróleo y Gas (planilla anual)"))
    filas = contenido.count(b"\n") - 1 if archivo.suffix == ".csv" else ""
    return {
        "archivo": str(archivo.relative_to(CRUDOS)),
        "organismo": organismo,
        "dataset": nombre,
        "descargado": datetime.fromtimestamp(archivo.stat().st_mtime).strftime("%Y-%m-%d"),
        "tamano_mb": round(len(contenido) / 1_048_576, 2),
        "filas": filas,
        "sha256": hashlib.sha256(contenido).hexdigest(),
    }


archivos = sorted(a for a in CRUDOS.rglob("*") if a.suffix in (".csv", ".zip"))
registro = [describir(a) for a in archivos]
with open(SALIDA, "w", newline="", encoding="utf-8") as salida:
    escritor = csv.DictWriter(salida, fieldnames=list(registro[0]))
    escritor.writeheader()
    escritor.writerows(registro)
print(f"{len(registro)} archivos registrados -> {SALIDA}")
