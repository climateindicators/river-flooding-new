# Regression checks on the generated data for the River Flooding indicator.
#
#   Rscript tests/test-data.R
#
# Two kinds of check live here. The dictionary and hygiene checks are
# shape-independent and hold whatever R/build_data.R turns each figure into. The
# value snapshots below them pin the actual numbers, so a legitimate data update
# fails loudly here and says exactly what changed, rather than passing silently.
#
# When the data is legitimately updated, expect failures in the snapshots and
# update each expectation only after checking it against the new source file.

setwd(here::here())
source("R/utils/write_stable.R")

# Keeps the dictionary check readable when a meta.yml field is absent altogether.
`%||%` <- function(a, b) if (is.null(a)) b else a

failures <- character()
check <- function(label, ok) {
  ok <- isTRUE(ok)
  cat(sprintf("  [%s] %s\n", if (ok) "PASS" else "FAIL", label))
  if (!ok) failures <<- c(failures, label)
  invisible(ok)
}

rd <- function(f) {
  readr::read_csv(file.path("data", f),
                  col_types = readr::cols(.default = readr::col_character()),
                  na = character(), progress = FALSE)
}

meta <- yaml::read_yaml("data/meta.yml")

cat("\nData dictionary\n")
check("meta.yml documents 2 dataset(s)", length(meta$datasets) == 2L)
check("meta.yml has no timestamp",
      !any(grepl("\\d{4}-\\d{2}-\\d{2}T|Sys\\.time|generated_at",
                 readLines("data/meta.yml", warn = FALSE))))

for (ds in meta$datasets) {
  df   <- rd(ds$file)
  cols <- vapply(ds$columns, function(x) x$name, character(1))
  check(sprintf("%s: meta.yml lists the columns the file actually has", ds$file),
        identical(cols, names(df)))
  check(sprintf("%s: meta.yml row count matches the file", ds$file),
        identical(as.integer(ds$rows), nrow(df)))
  check(sprintf("%s: every column has a type and a description", ds$file),
        all(vapply(ds$columns, function(x) nzchar(x$type %||% "") && nzchar(x$description %||% ""), logical(1))))
  check(sprintf("%s: source file is still present and unchanged", ds$file),
        identical(file_sha256(file.path("data-raw", ds$source_file)), ds$source_sha256))
  check(sprintf("%s: no blank rows", ds$file), nrow(df) > 0L)
}

cat("\nFile hygiene\n")
for (f in list.files("data", pattern = "[.](csv|yml)$", full.names = TRUE)) {
  check(sprintf("%s is UTF-8, LF, no BOM, no mojibake", basename(f)),
        tryCatch({ assert_clean_output(f); TRUE },
                 error = function(e) { cat("      ", conditionMessage(e), "\n"); FALSE }))
}

# Values are compared as strings, not as numbers. The source carries up to 10
# significant digits and R/build_data.R never coerces them, so a change in the
# printed precision is itself a change worth failing on.

f1 <- rd("river_flooding_magnitude.csv")
f2 <- rd("river_flooding_frequency.csv")

cat("\nFigure 1 value snapshots (river_flooding_magnitude.csv)\n")
check("526 stations", nrow(f1) == 526L)
check("every row is magnitude_trend, in tau value",
      all(f1$measure == "magnitude_trend") && all(f1$unit == "tau value"))
check("first row in source order: 39.98500557, -100.560148, -0.456762284",
      identical(f1$latitude[1], "39.98500557") &&
        identical(f1$longitude[1], "-100.560148") &&
        identical(f1$value[1], "-0.456762284"))
check("last row in source order: 55.3951944, -132.4086268, 0.325296551",
      identical(f1$latitude[nrow(f1)], "55.3951944") &&
        identical(f1$longitude[nrow(f1)], "-132.4086268") &&
        identical(f1$value[nrow(f1)], "0.325296551"))
check("tau range [-0.456762284, 0.325296551]", {
  v <- as.numeric(f1$value)
  identical(f1$value[which.min(v)], "-0.456762284") &&
    identical(f1$value[which.max(v)], "0.325296551")
})
check("310 stations trending smaller, 216 trending larger", {
  v <- as.numeric(f1$value)
  sum(v < 0) == 310L && sum(v > 0) == 216L
})

cat("\nFigure 2 value snapshots (river_flooding_frequency.csv)\n")
check("481 stations", nrow(f2) == 481L)
check("every row is frequency_trend, in slope value",
      all(f2$measure == "frequency_trend") && all(f2$unit == "slope value"))
check("first row in source order: 38.88743023, -117.2453673, -0.477550834",
      identical(f2$latitude[1], "38.88743023") &&
        identical(f2$longitude[1], "-117.2453673") &&
        identical(f2$value[1], "-0.477550834"))
check("last row in source order: 47.80555344, -98.71621718, 0.039615746",
      identical(f2$latitude[nrow(f2)], "47.80555344") &&
        identical(f2$longitude[nrow(f2)], "-98.71621718") &&
        identical(f2$value[nrow(f2)], "0.039615746"))
check("slope range [-0.477550834, 0.039615746]", {
  v <- as.numeric(f2$value)
  identical(f2$value[which.min(v)], "-0.477550834") &&
    identical(f2$value[which.max(v)], "0.039615746")
})
check("295 stations trending less frequent, 186 trending more frequent", {
  v <- as.numeric(f2$value)
  sum(v < 0) == 295L && sum(v > 0) == 186L
})

cat("\nCross-figure\n")
# Both figures screen the same HCDN-2009 reference gauge network, so they share
# their geographic extremes: Puerto Rico to Alaska, Hawaii to Puerto Rico.
for (nm in c("magnitude", "frequency")) {
  d <- if (nm == "magnitude") f1 else f2
  check(sprintf("%s: coordinate extremes span Puerto Rico to Alaska to Hawaii", nm), {
    la <- as.numeric(d$latitude); lo <- as.numeric(d$longitude)
    identical(d$latitude[which.min(la)], "18.03246444") &&
      identical(d$latitude[which.max(la)], "64.9023739") &&
      identical(d$longitude[which.min(lo)], "-159.61998") &&
      identical(d$longitude[which.max(lo)], "-66.0323866")
  })
}
check("figure 1 screens in more stations than figure 2 (526 vs 481)",
      nrow(f1) > nrow(f2))

cat("\n")
if (length(failures)) {
  cat(sprintf("%d FAILED:\n", length(failures)))
  for (f in failures) cat("  -", f, "\n")
  quit(status = 1L)
}
cat("All data checks passed.\n")
