"""Baja tres planillas de la EIA (agencia de energía de Estados Unidos) y las deja en CSV.

  data/raw/brent_mensual.csv    precio del Brent, promedio mensual, USD por barril
  data/raw/henry_hub_mensual.csv  precio del gas en Estados Unidos (Henry Hub),
                                promedio mensual, USD por millón de BTU
  data/raw/eeuu_tight_oil.csv   producción de petróleo de cada cuenca de shale de
                                Estados Unidos, millones de barriles por día

La segunda planilla viene con una columna por cuenca: acá se pasa a una fila por
mes y cuenca, que es como se carga en la base.
"""
import io
import urllib.request
from pathlib import Path

import pandas as pd

RAW = Path(__file__).resolve().parent.parent / "data" / "raw"
BRENT = "https://www.eia.gov/dnav/pet/hist_xls/RBRTEm.xls"
HENRY_HUB = "https://www.eia.gov/dnav/ng/hist_xls/RNGWHHDm.xls"
TIGHT = "https://www.eia.gov/energyexplained/oil-and-petroleum-products/data/US-tight-oil-production.xlsx"


def bajar(url: str) -> bytes:
    pedido = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(pedido, timeout=120) as respuesta:
        return respuesta.read()


def main() -> None:
    # Brent: la hoja "Data 1" tiene dos filas de encabezado y después fecha y precio.
    brent = pd.read_excel(io.BytesIO(bajar(BRENT)), sheet_name="Data 1", skiprows=3, header=None,
                          names=["fecha", "usd_bbl"])
    brent = brent.dropna()
    brent["mes"] = pd.to_datetime(brent["fecha"]).dt.strftime("%Y-%m-01")
    brent[["mes", "usd_bbl"]].to_csv(RAW / "brent_mensual.csv", index=False)

    # Henry Hub: la misma forma de planilla que el Brent.
    gas = pd.read_excel(io.BytesIO(bajar(HENRY_HUB)), sheet_name="Data 1", skiprows=3, header=None,
                        names=["fecha", "usd_mmbtu"])
    gas = gas.dropna()
    gas["mes"] = pd.to_datetime(gas["fecha"]).dt.strftime("%Y-%m-01")
    gas[["mes", "usd_mmbtu"]].to_csv(RAW / "henry_hub_mensual.csv", index=False)

    # Tight oil: primera columna la fecha, después una columna por cuenca.
    tight = pd.read_excel(io.BytesIO(bajar(TIGHT)), sheet_name="data")
    tight = tight.loc[:, ~tight.columns.astype(str).str.startswith("Unnamed")]
    tight = tight.rename(columns={tight.columns[0]: "mes"}).dropna(subset=["mes"])
    largo = tight.melt(id_vars="mes", var_name="cuenca", value_name="millones_bbl_dia").dropna()
    largo["mes"] = pd.to_datetime(largo["mes"]).dt.strftime("%Y-%m-01")
    largo["cuenca"] = largo["cuenca"].str.strip()
    largo.to_csv(RAW / "eeuu_tight_oil.csv", index=False)

    print(f"brent: {len(brent)} meses hasta {brent['mes'].max()}")
    print(f"henry hub: {len(gas)} meses hasta {gas['mes'].max()}")
    print(f"tight oil: {largo['cuenca'].nunique()} cuencas hasta {largo['mes'].max()}")


if __name__ == "__main__":
    main()
