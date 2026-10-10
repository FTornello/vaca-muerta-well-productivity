"""Genera dashboard/boceto_resultados.png: los cuatro hallazgos en una imagen.

Lee los CSV de dashboard/datos/ (los produce sql/06_exportar_dashboard.sql).
Sirve de referencia para armar el tablero y de vista previa en el README.
"""
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

RAIZ = Path(__file__).resolve().parent.parent
DATOS = RAIZ / "dashboard" / "datos"

FONDO, TINTA, TINTA_2, GRILLA = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
AZULES = ["#86b6ef", "#5598e7", "#2a78d6", "#1c5cab", "#0d366b"]
AZUL, NARANJA, AQUA, AMARILLO = "#2a78d6", "#eb6834", "#1baf7a", "#eda100"

plt.rcParams.update({
    "font.family": "Helvetica Neue", "font.size": 10, "text.color": TINTA,
    "axes.edgecolor": GRILLA, "axes.labelcolor": TINTA_2,
    "xtick.color": TINTA_2, "ytick.color": TINTA_2,
    "axes.spines.top": False, "axes.spines.right": False,
    "figure.facecolor": FONDO, "axes.facecolor": FONDO,
})


def miles(valor, _pos=None):
    return f"{valor:,.0f}".replace(",", ".")


def preparar(ax, titulo, subtitulo):
    ax.set_title(titulo, loc="left", fontsize=12, fontweight="bold", pad=22)
    ax.text(0, 1.03, subtitulo, transform=ax.transAxes, fontsize=9, color=TINTA_2)
    ax.grid(axis="y", color=GRILLA, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(length=0)


pozos = pd.read_csv(DATOS / "pozos.csv")
curva = pd.read_csv(DATOS / "curva_por_edad.csv")
areas = pd.read_csv(DATOS / "produccion_por_area.csv", parse_dates=["mes"])
confiables = pozos[pozos.diseno_confiable == "t"]

fig, ejes = plt.subplots(2, 2, figsize=(14, 9.5))
fig.subplots_adjust(left=0.115, right=0.96, top=0.86, bottom=0.07, hspace=0.42, wspace=0.34)
fig.suptitle("¿Qué hace que un pozo de Vaca Muerta rinda más?",
             x=0.115, y=0.965, ha="left", fontsize=17, fontweight="bold")
fig.text(0.115, 0.925, "Pozos horizontales petrolíferos. Fuente: Secretaría de Energía, datos a agosto de 2026.",
         fontsize=10, color=TINTA_2)

# 1. Curva típica por año de arranque
ax = ejes[0, 0]
preparar(ax, "1. El pozo típico se duplicó y después se estancó",
         "Petróleo promedio por mes de vida (m³), según el año en que arrancó el pozo")
anios = [2016, 2018, 2020, 2022, 2024]
tabla = (curva[curva.mes_de_vida <= 12]
         .groupby(["anio_arranque", "mes_de_vida"]).petroleo_m3.mean().unstack(0))
for anio, color in zip(anios, AZULES):
    ax.plot(tabla.index, tabla[anio], color=color, linewidth=2, label=str(anio))
ax.set_xticks(range(1, 13))
ax.set_xlabel("Mes de vida del pozo")
ax.yaxis.set_major_formatter(miles)
ax.set_ylim(0, 6200)
ax.legend(title="Año de arranque", frameon=False, ncol=5, loc="upper right",
          fontsize=9, title_fontsize=9, handlelength=1.4, columnspacing=1.2)

# 2. Diseño contra rendimiento, base 2021 = 100
ax = ejes[0, 1]
preparar(ax, "2. Pozos cada vez más grandes, sin rendir más",
         "Medianas por año de arranque, índice 2021 = 100")
por_anio = (confiables[confiables.anio_arranque >= 2018]
            .groupby("anio_arranque")[["arena_tn", "rama_m", "petroleo_12m_m3", "petroleo_por_km_m3"]]
            .median())
indice = por_anio / por_anio.loc[2021] * 100
series = [("arena_tn", "Arena inyectada", AMARILLO),
          ("rama_m", "Largo de rama", AZUL),
          ("petroleo_12m_m3", "Petróleo del primer año", AQUA),
          ("petroleo_por_km_m3", "Petróleo por km de rama", NARANJA)]
for columna, nombre, color in series:
    ax.plot(indice.index, indice[columna], color=color, linewidth=2, marker="o", markersize=4)
    final = indice[columna].iloc[-1]
    ax.annotate(f"{nombre}  {final:.0f}", (indice.index[-1], final), xytext=(8, 0),
                textcoords="offset points", va="center", fontsize=9, color=TINTA)
ax.axhline(100, color=TINTA_2, linewidth=0.8, linestyle=(0, (3, 3)))
ax.set_xlim(2018, 2025)
ax.set_xticks(range(2018, 2026))
ax.spines["right"].set_visible(False)
fig.canvas.draw()
caja = ax.get_position()
ax.set_position([caja.x0, caja.y0, caja.width * 0.74, caja.height])

# 3. Operadoras
ax = ejes[1, 0]
preparar(ax, "3. Vista lidera, pero cada operadora tiene su propio lugar",
         "Petróleo del primer año por pozo, mediana (m³). Pozos desde 2021, operadoras con 15 o más")
recientes = pozos[pozos.anio_arranque >= 2021]
ops = recientes.groupby("operadora").petroleo_12m_m3.agg(["median", "count"])
ops = ops[ops["count"] >= 15].sort_values("median")
barras = ax.barh(ops.index, ops["median"], color=AZUL, height=0.62)
for barra, (_, fila) in zip(barras, ops.iterrows()):
    ax.text(fila["median"] + 600, barra.get_y() + barra.get_height() / 2,
            f"{miles(fila['median'])}   ({int(fila['count'])} pozos)", va="center", fontsize=9, color=TINTA)
ax.grid(False)
ax.set_xlim(0, ops["median"].max() * 1.32)
ax.set_xticks([])
ax.spines["bottom"].set_visible(False)

# 4. Concentración por área
ax = ejes[1, 1]
preparar(ax, "4. Cuatro áreas dieron el 62 % del petróleo, y pierden peso",
         "Participación de cada área en el petróleo de Vaca Muerta (%)")
total = areas.groupby("area").petroleo_m3.sum()
ultimo = areas[areas.mes > areas.mes.max() - pd.DateOffset(months=12)].groupby("area").petroleo_m3.sum()
part = pd.DataFrame({"historico": total / total.sum() * 100, "ultimos": ultimo / ultimo.sum() * 100}).fillna(0)
part = part.sort_values("historico", ascending=False).head(6).iloc[::-1]
pos = range(len(part))
alto = 0.36
ax.barh([p + alto / 2 + 0.02 for p in pos], part.historico, height=alto, color=AZUL, label="Desde 2012")
ax.barh([p - alto / 2 - 0.02 for p in pos], part.ultimos, height=alto, color=NARANJA, label="Últimos 12 meses")
for p, (_, fila) in zip(pos, part.iterrows()):
    ax.text(fila.historico + 0.4, p + alto / 2 + 0.02, f"{fila.historico:.0f}", va="center", fontsize=9)
    ax.text(fila.ultimos + 0.4, p - alto / 2 - 0.02, f"{fila.ultimos:.0f}", va="center", fontsize=9)
ax.set_yticks(list(pos))
ax.set_yticklabels([nombre.title() for nombre in part.index])
ax.grid(False)
ax.set_xticks([])
ax.spines["bottom"].set_visible(False)
ax.legend(frameon=False, loc="lower right", fontsize=9)

salida = RAIZ / "dashboard" / "boceto_resultados.png"
fig.savefig(salida, dpi=160)
print(salida)
