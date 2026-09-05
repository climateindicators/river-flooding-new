# Provenance

Every file in this directory is reproduced unmodified from EPA's published
indicator page and its per-figure data downloads. To update the data, replace the
file and rerun `Rscript R/build_data.R`.

## Indicator page

- `source-page.html`  \
  <https://19january2025snapshot.epa.gov/climate-indicators/climate-change-indicators-river-flooding/index.html>  \
  sha256 `19095fba5f0d27ae7eee5cda6999d09f05d42cb5f94a1a1a77ad0b066b735070`

Technical documentation: <https://19january2025snapshot.epa.gov/sites/default/files/2021-03/documents/river-flooding_tech-doc.pdf>

## Figure data

- `river-flooding_fig-1.csv`  \
  <https://19january2025snapshot.epa.gov/sites/default/files/2016-08/river-flooding_fig-1.csv>  \
  sha256 `c19a41a55ac761d096e2fe9f61673ab22a5142bbcf250073e106204912f056cc`  \
  encoding windows-1252, 526 data rows, columns: `latitude`, `longitude`, `value`  \
  title: Figure 1. Change in the Magnitude of River Flooding in the United States, 1965–2015  \
  data source: Slater and Villarini, 2016; web update: August 2016; units: tau value

- `river-flooding_fig-2.csv`  \
  <https://19january2025snapshot.epa.gov/sites/default/files/2016-08/river-flooding_fig-2.csv>  \
  sha256 `00dc47b17bb4af9963e7548420bb1670d7e07097560c59d972d0b0cb3f476827`  \
  encoding windows-1252, 481 data rows, columns: `latitude`, `longitude`, `value`  \
  title: Figure 2. Change in the Frequency of River Flooding in the United States, 1965–2015  \
  data source: Slater and Villarini, 2016; web update: August 2016; units: slope value
