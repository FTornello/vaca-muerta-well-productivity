# Vaca Muerta in data

*[Versión en español](README.md)*

A SQL analysis of the Vaca Muerta shale formation in Neuquén, Argentina, built from twenty-three open sources, most of them from Argentina's Energy Secretariat. Forty-two questions, from 2006 to August 2026, that add up to a single story.

- **[Vaca Muerta explained](https://ftornello.github.io/vaca-muerta-well-productivity/)** (in Spanish): the full story in five ideas, with diagrams, charts and a simulator. The best place to start.
- **[Tableau Public dashboard](https://public.tableau.com/views/vaca_muerta_tablero/QuhacequeunpozodeVacaMuertarindams)**: a view to explore the wells (production curve, design, operators, map and blocks). It shows the starting point of the analysis, not the whole story.
- **[Log](BITACORA.md)** (in Spanish): how I reasoned through each decision, including the times I had to correct something.

## The story in five acts

**1. They learned how to build the well.** Between 2016 and 2021, the first-year oil output of a typical well doubled, from 17,000 to 38,000 m³. Growth came from three things at once: more wells (52%), longer laterals (36%) and more output per kilometre (11%). Operators that arrived later started with twice YPF's 2012 productivity. *(Questions 1, 2, 35 and 50)*

**2. In 2021 the well stopped improving, and the core is getting crowded.** Since then laterals got 22% longer and sand use rose 43%, but each kilometre yields 22% less. Four independent measures point to the same cause: new wells drilled closer and closer to older ones that already drained the rock. Wells with a parent well less than 300 m away yield 15% less and lose pressure sooner (66% still flow naturally in year three, vs. 79%); the legacy blocks are declining while the new ones grow; and in those legacy blocks about 40% of new wells are now drilled less than 500 m from a parent, vs. 18% in 2019. Location, rock level and sand explain 39% of the differences between wells; the rest cannot be explained with public data. *(5, 6, 7, 41, 47 and 52)*

**3. Now it only grows because more is drilled.** Between 2021 and 2024, the larger number of wells explains more than 100% of the growth: productivity took away half. Existing wells lose 37% per year, so more than half of what is drilled only replaces that decline. Without new wells, output would fall 40% in a year. A well costs 50% more than in 2021, mostly because each metre drilled got more expensive, and the oil price needed to pay it back in two years went from 27 to 44 dollars. *(8, 12, 22, 24, 36, 37, 50 and 54)*

**4. That oil does not fit in the country.** Vaca Muerta is 63% of Argentina's oil, but refineries process the same volume as fifteen years ago: they took less than a third of what was added since 2017. The rest is exported, 53% of the total, with the pipeline as the bottleneck in 2022 and 2023. The country's energy trade balance went from −6.9 billion dollars in 2013 to +7.8 billion in 2025, and the local oil price, which used to move on its own, now follows the international one. *(10, 14, 26, 27, 31 and 33)*

**5. The gas is trapped.** It has the rock and the reserves, but not the market. Vaca Muerta is already 53% of the country's gas and total output barely grew: it replaced conventional gas. The price is fixed at 2.9 dollars whatever happens abroad, wells are shut every spring (20% idle vs. 10% in winter), the gas that comes with the oil grows faster than the oil, and companies themselves forecast +2% for gas vs. +24% for oil. *(9, 11, 13, 27, 32, 40, 42, 48 and 49)*

**What remains open.** The 2026 drilling pace is exactly what one million barrels per day in 2030 requires: about 555 wells per year. Companies declare less (754 thousand in 2029), and reality has been running above what they declare. It depends on keeping that pace with a well that no longer improves, and proved reserves outside existing wells cover less than three years of drilling. *(28, 36 and 44)*

### How solid each claim is

| What I say | How it is backed | 
|---|---|
| The typical well stalled in 2021 | Medians of 1,688 wells; changes less than 2% when outliers are removed (39). Matches FDC and Enverus |
| A well is 6 km: 3 down and 3 lateral | Two independent spreadsheets give the same result (30) |
| The base declines 37% per year | Two different methods (24 and 36); the projection missed by less than 10% against five real years |
| What cannot be refined is exported | The surplus left after refining (250 thousand barrels per day) matches what was shipped (233 thousand) (27) |
| The 2025 energy trade balance | My series gives USD 7,829 million; INDEC reported 7,815 (26) |
| A well costs about 14 million | Matches FDC for 2019 and 2020 and Aleph Energy for 2025 (12 and 37) |
| The core is getting crowded | Four independent signals and technical literature on the parent-child effect. The most interpretive conclusion: the data show the result, not the mechanism |
| Gas has no market | Volume, price, well status and company forecasts all say the same |

Well design data are solid from 2016 to 2024 (question 51). Each section of the log says what cannot be claimed.

## Checked against other sources

| My figure | External source |
|---|---|
| First-year output: 17,323 m³ (2016) and 27,125 (2018) | FDC: 17,000 and 27,800 |
| Cost per well: 9.6 and 9.1 million USD (2019 and 2020) | FDC: 10.5 and 9.5 |
| Lifetime output of a well: 115 and 146 thousand m³ (2018 and 2020) | FDC: 118 and 158 |
| Decline per km since 2021: about 6% per year | Enverus: 7% to 12% per year |
| Seasonal gas drop in 2025: 28 million m³ per day | Press: 29 withdrawn due to shut-ins |
| Pipeline in August 2026: 542 thousand barrels per day | Press: system limit, 530 thousand |
| Reserves: 14 years of oil and 17 of gas | IAE: horizons of 15 and 13 years |

Details and links are in sections 15, 20 and 77 of the [log](BITACORA.md).

## Limits

- **These are associations, not causes.**
- **A well's output beyond 10 years is a projection,** with three scenarios.
- **Only wells with 12 full months are compared.** 2026 is not included in the productivity questions.
- **Well trajectories cover 44% of 2024 wells and 25% of 2025 wells.**
- **Fracturing data run about three months behind** at the source.
- **Costs and reserves are company declarations, not audited.** Costs are only reliable in the largest blocks.
- **Pipelines and shipments cover the whole Neuquén basin,** not only Vaca Muerta.

## How it is built

PostgreSQL in two layers, with a Python step for the statistical fit: `raw` keeps each file exactly as published and `vm` is the clean model, rebuilt from scratch by a script. Eight checks verify that nothing is lost relative to the source. Impossible values are not deleted: they are flagged with the reason.

- [sql/](sql/): loading, clean model and checks. [sql/analisis/](sql/analisis/): one commented query per question.
- [DICCIONARIO.md](DICCIONARIO.md) (in Spanish): what each table and column means.
- [data/FUENTES.csv](data/FUENTES.csv): each downloaded file, with source, date and hash.

## How to reproduce it

Requires PostgreSQL 17 and Python 3 (`pip install -r requirements.txt`).

```bash
./scripts/descargar_datos.sh
createdb vaca_muerta
./scripts/reconstruir.sh
psql -d vaca_muerta -f sql/analisis/p1_curva_tipica.sql
```

Figures correspond to the downloads of October 9 and 10, 2026. The source is updated monthly.

## Sources

Argentina's Energy Secretariat, [datos.energia.gob.ar](http://datos.energia.gob.ar): production per well (Chapter IV), fracturing (Annex IV), well trajectories, natural gas prices, hydrocarbon transport, upstream investment (Res. 2057), reserves and royalties. Employment and wages: CEP XXI, Secretariat of Production.

Francisco Tornello, 2026. I worked with Claude Code as an assistant.

## License

Code is released under the [MIT](LICENSE) license. The data are public and belong to their sources.
