"""Genera dashboard/vida_del_pozo.png: cuánto lleva producido un pozo según su edad.

Lee data/curva_tipo.csv (lo observado, por año de arranque) y data/declinacion.csv
(la curva tipo extendida a 25 años, con tres escenarios).
"""
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

RAIZ = Path(__file__).resolve().parent.parent
FONDO, TINTA, TINTA_2, GRILLA = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
AZULES = {2016: "#86b6ef", 2018: "#5598e7", 2020: "#2a78d6", 2022: "#0d366b"}
NARANJA = "#eb6834"

plt.rcParams.update({
    "font.family": "Helvetica Neue", "font.size": 10, "text.color": TINTA,
    "axes.edgecolor": GRILLA, "axes.labelcolor": TINTA_2,
    "xtick.color": TINTA_2, "ytick.color": TINTA_2,
    "axes.spines.top": False, "axes.spines.right": False,
    "figure.facecolor": FONDO, "axes.facecolor": FONDO,
})

observado = pd.read_csv(RAIZ / "data" / "curva_tipo.csv")
proyeccion = pd.read_csv(RAIZ / "data" / "declinacion.csv")
proyeccion["anios"] = proyeccion.mes_de_vida / 12
ultimo = proyeccion[proyeccion.origen == "observado"].mes_de_vida.max()
futuro = proyeccion[proyeccion.mes_de_vida >= ultimo]

fig, ax = plt.subplots(figsize=(11, 6.2))
fig.subplots_adjust(left=0.08, right=0.80, top=0.80, bottom=0.12)
fig.suptitle("Un pozo produce en toda su vida unas 4,2 veces lo que da en el primer año",
             x=0.08, y=0.95, ha="left", fontsize=15, fontweight="bold")
fig.text(0.08, 0.885, "Petróleo acumulado de un pozo según su edad, en veces la producción de su primer año. "
                      "Pozos horizontales petrolíferos de Vaca Muerta.", fontsize=10, color=TINTA_2)

ax.fill_between(futuro.anios, futuro.acumulado_bajo, futuro.acumulado_alto, color=NARANJA, alpha=0.15, linewidth=0)
ax.plot(futuro.anios, futuro.acumulado_base, color=NARANJA, linewidth=2, linestyle=(0, (5, 3)))

# Lo observado por año de arranque, como contexto: líneas finas.
ETIQUETAS = {2016: (-78, 6), 2018: (-78, 6), 2020: (8, -12), 2022: (8, -10)}
for anio, color in AZULES.items():
    curva = observado[observado.anio_arranque == anio]
    ax.plot(curva.mes_de_vida / 12, curva.acumulado_sobre_primer_anio, color=color, linewidth=1.5)
    ax.annotate(f"Pozos de {anio}", (curva.mes_de_vida.iloc[-1] / 12, curva.acumulado_sobre_primer_anio.iloc[-1]),
                xytext=ETIQUETAS[anio], textcoords="offset points", fontsize=9, color=TINTA)

# La curva tipo (promedio de todos los años) es la que se proyecta.
pasado = proyeccion[proyeccion.mes_de_vida <= ultimo]
ax.plot(pasado.anios, pasado.acumulado_base, color=NARANJA, linewidth=2.5)
ax.annotate("Curva tipo", (5, pasado.loc[pasado.mes_de_vida == 60, "acumulado_base"].iloc[0]),
            xytext=(10, -16), textcoords="offset points", fontsize=9.5, color=TINTA)

final = proyeccion.iloc[-1]
ax.annotate(f"Proyección: {final.acumulado_base:.1f} veces".replace(".", ","), (25, final.acumulado_base),
            xytext=(8, 0), textcoords="offset points", va="center", fontsize=9.5, color=TINTA)
ax.annotate(f"entre {final.acumulado_bajo:.1f} y {final.acumulado_alto:.1f}".replace(".", ","), (25, final.acumulado_base),
            xytext=(8, -14), textcoords="offset points", va="center", fontsize=9, color=TINTA_2)
ax.axvline(ultimo / 12, color=TINTA_2, linewidth=0.8, linestyle=(0, (2, 3)))
ax.text(ultimo / 12 - 0.2, 0.25, "hasta acá, datos", ha="right", fontsize=9, color=TINTA_2)
ax.text(ultimo / 12 + 0.2, 0.25, "desde acá, proyección", ha="left", fontsize=9, color=TINTA_2)

ax.set_xlim(0, 25)
ax.set_ylim(0, 4.8)
ax.set_xticks(range(0, 26, 5))
ax.set_xlabel("Edad del pozo (años)")
ax.set_yticks(range(0, 5))
ax.set_yticklabels(["0", "1 vez", "2 veces", "3 veces", "4 veces"])
ax.grid(axis="y", color=GRILLA, linewidth=0.8)
ax.set_axisbelow(True)
ax.tick_params(length=0)
fig.text(0.08, 0.025, "Fuente: Secretaría de Energía, datos a agosto de 2026. Proyección con una curva de Arps; "
                      "la franja muestra los escenarios con piso de declinación de 6 % a 12 % anual.",
         fontsize=8.5, color=TINTA_2)

salida = RAIZ / "dashboard" / "vida_del_pozo.png"
fig.savefig(salida, dpi=160)
print(salida)
