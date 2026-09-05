# Build tidy long-format data for the River Flooding indicator.
#
#   Rscript R/build_data.R
#
# Reads EPA's published figure CSVs in data-raw/ and writes data/*.csv plus
# data/meta.yml. Rerunning with unchanged inputs produces byte-identical output.
# Nothing here touches the network.
#
# Both source files are already tidy: one row per stream gauge station, with
# columns latitude, longitude, value. There is no wide-to-long pivot and no
# multi-series lookup table, unlike most other indicators in this project.
#
# TO UPDATE THE DATA: drop replacement CSVs into data-raw/ and rerun. Headers
# are asserted, not assumed, so a renamed or reordered column stops the build.

suppressPackageStartupMessages({
  library(dplyr)
})

root <- here::here()
source(file.path(root, "R/utils/epa_csv.R"))
source(file.path(root, "R/utils/write_stable.R"))

raw_dir <- file.path(root, "data-raw")
out_dir <- file.path(root, "data")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Indicator constants -----------------------------------------------------

INDICATOR <- list(
  name                    = "River Flooding",
  slug                    = "river-flooding",
  publisher               = "U.S. Environmental Protection Agency",
  source_page             = "https://19january2025snapshot.epa.gov/climate-indicators/climate-change-indicators-river-flooding/index.html",
  technical_documentation = "https://19january2025snapshot.epa.gov/sites/default/files/2021-03/documents/river-flooding_tech-doc.pdf",
  rights                  = "Public domain, work of the U.S. Government (17 U.S.C. 105)"
)

# ---- Figure 1: Change in the Magnitude of River Flooding in the United States, 1965–2015 ----

f1_path <- file.path(raw_dir, "river-flooding_fig-1.csv")
f1_meta <- read_epa_preamble(f1_path)
f1_raw  <- read_epa_csv(f1_path)

assert_headers(
  f1_raw,
  id_cols          = c("latitude", "longitude"),
  expected_headers = "value",
  what             = "river-flooding_fig-1.csv"
)

# This source file is already tidy: one row per stream gauge station, carrying
# the station's coordinates and its trend statistic. There is no wide-to-long
# pivot, so the reshape only names what the bare `value` column measures and in
# what unit, which the file states in its preamble but not in its header.
stopifnot(
  "figure 1: no blank latitude, longitude, or value cells" =
    all(trimws(f1_raw$latitude) != "") && all(trimws(f1_raw$longitude) != "") &&
    all(trimws(f1_raw$value) != ""),
  "figure 1: latitude/longitude/value must all parse as numeric" =
    !anyNA(suppressWarnings(as.numeric(f1_raw$latitude))) &&
    !anyNA(suppressWarnings(as.numeric(f1_raw$longitude))) &&
    !anyNA(suppressWarnings(as.numeric(f1_raw$value))),
  "figure 1: latitude within [-90, 90], longitude within [-180, 180]" =
    all(dplyr::between(as.numeric(f1_raw$latitude), -90, 90)) &&
    all(dplyr::between(as.numeric(f1_raw$longitude), -180, 180)),
  # Kendall's tau is mathematically bounded in [-1, 1]. That is a property of
  # the statistic, not a fact about this particular data update, so it belongs
  # here rather than in the value snapshots.
  "figure 1: Mann-Kendall tau values must fall within [-1, 1]" =
    all(dplyr::between(as.numeric(f1_raw$value), -1, 1)),
  "figure 1: one row per station, no duplicate coordinates" =
    !any(duplicated(paste(f1_raw$latitude, f1_raw$longitude)))
)

f1 <- f1_raw |>
  dplyr::transmute(
    latitude  = latitude,
    longitude = longitude,
    measure   = "magnitude_trend",
    unit      = f1_meta$units,
    value     = value
  )

write_csv_stable(f1, file.path(out_dir, "river_flooding_magnitude.csv"))

# ---- Figure 2: Change in the Frequency of River Flooding in the United States, 1965–2015 ----

f2_path <- file.path(raw_dir, "river-flooding_fig-2.csv")
f2_meta <- read_epa_preamble(f2_path)
f2_raw  <- read_epa_csv(f2_path)

assert_headers(
  f2_raw,
  id_cols          = c("latitude", "longitude"),
  expected_headers = "value",
  what             = "river-flooding_fig-2.csv"
)

# Same shape as figure 1, a different statistic. No bound is asserted on the
# value: a Poisson regression slope is not bounded the way Kendall's tau is.
stopifnot(
  "figure 2: no blank latitude, longitude, or value cells" =
    all(trimws(f2_raw$latitude) != "") && all(trimws(f2_raw$longitude) != "") &&
    all(trimws(f2_raw$value) != ""),
  "figure 2: latitude/longitude/value must all parse as numeric" =
    !anyNA(suppressWarnings(as.numeric(f2_raw$latitude))) &&
    !anyNA(suppressWarnings(as.numeric(f2_raw$longitude))) &&
    !anyNA(suppressWarnings(as.numeric(f2_raw$value))),
  "figure 2: latitude within [-90, 90], longitude within [-180, 180]" =
    all(dplyr::between(as.numeric(f2_raw$latitude), -90, 90)) &&
    all(dplyr::between(as.numeric(f2_raw$longitude), -180, 180)),
  "figure 2: one row per station, no duplicate coordinates" =
    !any(duplicated(paste(f2_raw$latitude, f2_raw$longitude)))
)

f2 <- f2_raw |>
  dplyr::transmute(
    latitude  = latitude,
    longitude = longitude,
    measure   = "frequency_trend",
    unit      = f2_meta$units,
    value     = value
  )

write_csv_stable(f2, file.path(out_dir, "river_flooding_frequency.csv"))

# ---- Data dictionary ---------------------------------------------------------

col <- function(name, type, description) {
  list(name = name, type = type, description = description)
}

# Both captions describe EPA's own figure as distinguishing statistically
# significant stations by symbol size and fill. That classification is not a
# column of either source file, only the trend value is, so a chart drawn from
# `data/` cannot reproduce it without re-running EPA's significance test.
trend_value_note <- paste(
  "EPA's published figure distinguishes statistically significant stations",
  "(larger, solid-color symbols) from non-significant ones (smaller, outlined",
  "symbols). That classification is not present in this source file, only the",
  "trend value itself, so it cannot be reconstructed here without re-running",
  "EPA's own significance test."
)

station_cols <- function(value_description) {
  list(
    col("latitude", "number", "Stream gauge station latitude, decimal degrees. Verbatim from the source file."),
    col("longitude", "number", "Stream gauge station longitude, decimal degrees. Verbatim from the source file."),
    col("measure", "string", "What the `value` column measures."),
    col("unit", "string", "Unit of `value`, taken from the source file's own Units line."),
    col("value", "number", value_description)
  )
}

meta <- list(
  indicator = INDICATOR,
  datasets = list(
    list(
      file            = "river_flooding_magnitude.csv",
      figure          = "Figure 1",
      figure_title    = f1_meta$title,
      source_file     = "river-flooding_fig-1.csv",
      source_sha256   = file_sha256(f1_path),
      source_encoding = f1_meta$encoding,
      data_source     = f1_meta$data_source,
      web_update      = f1_meta$web_update,
      unit            = f1_meta$units,
      rows            = nrow(f1),
      columns = station_cols(paste(
        "Mann-Kendall tau statistic for the trend in the station's annual",
        "maximum discharge. Positive means floods have become larger.",
        "Verbatim from the source file."
      )),
      note = trend_value_note
    ),
    list(
      file            = "river_flooding_frequency.csv",
      figure          = "Figure 2",
      figure_title    = f2_meta$title,
      source_file     = "river-flooding_fig-2.csv",
      source_sha256   = file_sha256(f2_path),
      source_encoding = f2_meta$encoding,
      data_source     = f2_meta$data_source,
      web_update      = f2_meta$web_update,
      unit            = f2_meta$units,
      rows            = nrow(f2),
      columns = station_cols(paste(
        "Poisson regression slope for the trend in the station's count of",
        "peaks-over-threshold flood events. Positive means floods have become",
        "more frequent. Verbatim from the source file."
      )),
      note = trend_value_note
    )
  )
)

write_yaml_stable(meta, file.path(out_dir, "meta.yml"))

# ---- Verify what was written -------------------------------------------------

written <- list.files(out_dir, pattern = "[.](csv|yml)$", full.names = TRUE)
invisible(lapply(written, assert_clean_output))

cat("\nWrote:\n")
for (p in written) {
  cat(sprintf("  %-34s %8d bytes  %s\n", basename(p), file.size(p), substr(file_sha256(p), 1, 12)))
}
