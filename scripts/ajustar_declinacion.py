"""Estima cuánto produce un pozo en toda su vida a partir de la curva tipo.

Lee data/curva_tipo.csv (lo genera sql/11_curva_tipo.sql): para cada año de
arranque, la producción de cada mes de vida expresada como fracción de lo que el
pozo produce en su primer año.

Pasos:
  1. Promedia las curvas de todos los años (pesando por cantidad de pozos) para
     tener una sola curva tipo. Se puede porque la forma casi no cambia de un
     año a otro: es lo que muestra la consulta 22a.
  2. Le ajusta una curva de declinación hiperbólica de Arps, la forma estándar
     de la industria:  q(t) = qi / (1 + b * Di * t) ^ (1 / b)
  3. La extiende hasta 25 años. Una hiperbólica declina cada vez más despacio y
     si se la deja sola sobreestima; por eso, cuando la declinación baja de un
     piso anual, se la reemplaza por una caída constante a ese ritmo. El piso es
     un supuesto: se calculan tres escenarios (6 %, 8 % y 12 % anual).

Hasta donde hay datos observados se usan los datos; el ajuste solo se usa para
los meses que todavía no ocurrieron.

Escribe data/declinacion.csv (una fila por mes de vida) y
data/declinacion_parametros.csv (los parámetros del ajuste).
"""
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.optimize import curve_fit

RAIZ = Path(__file__).resolve().parent.parent
HORIZONTE_MESES = 300
PISOS_ANUALES = {"bajo": 0.12, "base": 0.08, "alto": 0.06}   # escenario -> declinación mínima anual


def arps(t, qi, b, di):
    return qi / np.power(1 + b * di * t, 1 / b)


curvas = pd.read_csv(RAIZ / "data" / "curva_tipo.csv")
caudal = curvas.pivot(index="mes_de_vida", columns="anio_arranque", values="caudal_sobre_primer_anio")
pozos = curvas.pivot(index="mes_de_vida", columns="anio_arranque", values="pozos")
tipo = (caudal * pozos).sum(axis=1) / pozos.where(caudal.notna()).sum(axis=1)

mes_pico = int(tipo.idxmax())
ultimo_observado = int(tipo.index.max())
desde_pico = tipo.loc[mes_pico:]
t = (desde_pico.index - mes_pico).to_numpy(dtype=float)

# Se ajusta sobre el logaritmo para que los meses de poco caudal pesen igual que el pico.
(qi, b, di), _ = curve_fit(lambda t, qi, b, di: np.log(arps(t, qi, b, di)),
                           t, np.log(desde_pico.to_numpy()),
                           p0=[desde_pico.iloc[0], 1.0, 0.15],
                           bounds=([0, 0.01, 0.001], [1, 2.5, 2]))
ajustado = np.log(arps(t, qi, b, di))
observado = np.log(desde_pico.to_numpy())
r2 = 1 - ((observado - ajustado) ** 2).sum() / ((observado - observado.mean()) ** 2).sum()

meses = np.arange(1, HORIZONTE_MESES + 1)
salida = pd.DataFrame({"mes_de_vida": meses})
salida["origen"] = np.where(meses <= ultimo_observado, "observado", "ajustado")

for escenario, piso_anual in PISOS_ANUALES.items():
    piso_mensual = 1 - (1 - piso_anual) ** (1 / 12)
    tiempo = (meses - mes_pico).astype(float)
    curva = arps(np.clip(tiempo, 0, None), qi, b, di)
    declinacion = di / (1 + b * di * np.clip(tiempo, 0, None))
    cambio = int(np.argmax(declinacion < piso_mensual))
    curva[cambio:] = curva[cambio] * np.exp(-piso_mensual * (tiempo[cambio:] - tiempo[cambio]))
    curva[:ultimo_observado] = tipo.reindex(meses[:ultimo_observado]).to_numpy()   # datos reales donde existen
    salida[f"caudal_{escenario}"] = curva.round(6)
    salida[f"acumulado_{escenario}"] = curva.cumsum().round(4)

salida.to_csv(RAIZ / "data" / "declinacion.csv", index=False)

parametros = pd.DataFrame([
    ("mes_pico", mes_pico), ("ultimo_mes_observado", ultimo_observado),
    ("qi", round(qi, 5)), ("b", round(b, 3)), ("di_mensual", round(di, 4)), ("r2_log", round(r2, 4)),
] + [(f"piso_anual_{e}", p) for e, p in PISOS_ANUALES.items()], columns=["parametro", "valor"])
parametros.to_csv(RAIZ / "data" / "declinacion_parametros.csv", index=False)

print(f"Ajuste: b = {b:.2f}, Di = {di:.3f} por mes, R2 = {r2:.3f}; datos observados hasta el mes {ultimo_observado}")
for años in (1, 2, 5, 10, 25):
    fila = salida.loc[salida.mes_de_vida == años * 12].iloc[0]
    print(f"  a {años:2d} años: {fila.acumulado_bajo:.2f} / {fila.acumulado_base:.2f} / {fila.acumulado_alto:.2f} veces el primer año")
