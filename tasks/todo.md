# build-indicator skill

## Run: river-flooding, built into this repo

`build_indicator.R <url> . --force`, then the four skill steps. `--force` was
needed only because `tasks/` already existed; there was no `narrative.qmd` to
discard, and `data-raw/` was left alone. The two figure CSVs already present
were reused, not re-downloaded.

- `R/build_data.R`: both `todo_reshape()` calls replaced. Neither figure needs a
  pivot; each source file is already one row per stream gauge station. The
  reshape names what `value` measures and in what unit, and adds the structural
  assertions (coordinate bounds, numeric parse, no duplicate stations, and for
  figure 1 the fact that Kendall's tau is bounded in [-1, 1]).
- Run twice: identical hashes. Both output CSVs are **byte-identical** to
  `indicators/river-flooding/data/`, which is the strongest available check that
  the new pipeline reproduces the established output. `meta.yml` differs by
  design: it now records the sniffed `source_encoding` and fuller column
  descriptions.
- `tests/test-data.R`: value snapshots written, 31 checks, all PASS, exit 0.
- The site repo already has `R/river-flooding.R` and
  `indicators/river-flooding.qmd`. Its data contract (`read_indicator`,
  `meta_for`, `figure_caption`) was exercised against the new files: all pass, no
  chart change needed.

### Open, from the script's report

- [ ] **The chart's colors contradict EPA's caption.** `narrative.qmd` carries
      EPA's wording verbatim: "Blue upward-pointing symbols show locations where
      floods have become larger; brown downward-pointing symbols show locations
      where floods have become smaller." The chart draws increase as
      `#FC4E07` (orange-red) and decrease as `#1d457f` (dark blue). The shapes
      match EPA, but blue means *increase* to EPA and *decrease* on the chart, so
      a reader following the caption reads the map backwards. Resolve by changing
      the page's caption wording (not EPA's prose in `narrative.qmd`), or by
      re-slotting the palette for this figure. This is a decision, not a defect
      to patch silently.
- [ ] **Cross-indicator links.** Three were flattened to plain text: Heavy
      Precipitation, Streamflow, Snowpack. Only `heavy-precipitation.qmd` exists
      on the site; there is no `streamflow.qmd` and no `snowpack.qmd`, so only
      one of the three can become a site-internal link today.

## Review

Built at `~/.claude/skills/build-indicator/`. The `new-indicator` skill is
untouched.

```
SKILL.md
scripts/build_indicator.R
assets/R/utils/epa_csv.R        copied, encoding now sniffed per file
assets/R/utils/write_stable.R   copied verbatim
assets/templates/               DESCRIPTION, gitignore, gitattributes,
                                NOTICE.md, README.md, CLAUDE.md
```

`Rscript build_indicator.R <epa-url> [outdir] [--force]` runs nine deterministic
steps and prints one report. Per-indicator model work is now the reshape blocks,
the value snapshots, and the chart.

### Verified

Run against all six reference pages: river-flooding, drought, sea-level,
ragweed-pollen-season, heat-related-deaths, heat-waves. All complete, exit 0.

| Check | Result |
| --- | --- |
| `narrative.qmd` vs `indicators/river-flooding/narrative.qmd` | only the expected differences; no EPA word differs |
| drought (4 figures, duplicate `slide1`, BOM file) | 4 figures, 11 references |
| sea-level (Figure 1 is a JS chart, no CSV) | reported as "no data file published by EPA" |
| ragweed (1 figure), heat-related-deaths (19 refs) | both correct |
| `drought_fig-3.csv` round-trip | `1900–2023`; the old hard-coded reader gives `1900â€"` |
| rerun without `--force` | refuses, exit 1 |
| rerun with `--force` | byte-identical across 12 generated files |
| non-indicator EPA URL | stops naming `div.slideshow-container`, exit 1, no stack trace |
| fresh `Rscript R/build_data.R` | fails at figure 1's `todo_reshape()` with a clear message, exit 1 |
| file hygiene, 72 generated files | UTF-8, LF, no BOM, no mojibake, no trailing whitespace, no blank-line runs |

### Corrections to the handoff plan, found while building

Four page facts in the plan did not hold as written. All are handled.

1. **Reference anchors have two nestings, not one.** river-flooding, ragweed,
   sea-level, heat-related-deaths use `<sup><a id="refN"></a>N</sup>`; drought
   and heat-waves use `<a id="refN"></a><sup>N </sup>`. The plan's single
   selector returned zero references on two of the six pages. Keyed on
   `a[id^='ref']` instead, and in-text markers on `a[href^='#ref']`, which also
   leaves `<sup>th</sup>` in "20th century" alone.
2. **A figure's CSV must key on its enclosing `div.slides`, not on caption
   order.** sea-level has `caption1` and `caption2` but one CSV, named
   `sea-level_fig-2.csv`. Mapping downloads to captions by position would have
   attached Figure 2's data to Figure 1.
3. **The BOM is not confined to `drought_fig-3.csv`.** `drought_fig-2.csv` is
   also UTF-8 with a BOM; `drought_fig-4.csv`, `sea-level_fig-2.csv`,
   `ragweed_fig-1.csv` and `heat-deaths_fig-1.csv` are UTF-8 without one. The
   reader sniffs bytes per file rather than special-casing a filename.
4. **Reference numbers are padded with U+00A0, not a plain space**, on drought,
   sea-level and heat-waves, and with a trailing period on sea-level 4 to 6.
   `trimws()` does not treat U+00A0 as whitespace, so the printed number was
   surviving into the list item and duplicating the list marker.

Also of note: drought figures 2 and 3 do have a data-source line, spelled
`Data sources:` plural. The only caption genuinely without one is sea-level
Figure 1.

## To do

- [ ] **Multi-unit `Units:` lines need a per-series decision.**
      `heat_waves_fig-1.csv` carries four semicolon-separated units for four
      series; `heat_waves_fig-2.csv` carries six. `meta.yml`'s `unit:` is
      single-valued. The stub now raises a note next to the affected figure, but
      the choice is still open: carry `unit` as a column of the output data and
      make `unit:` a summary, or split the figure into one file per series.
      Whichever is chosen should become the house rule.
- [ ] **Figures EPA labels `Example` are not on the published indicator page.**
      `heat-deaths_example.csv` is the known case. The script records it in
      `PROVENANCE.md` and pre-fills a `note:` in that dataset's `meta.yml` entry,
      but the `README.md` and `CLAUDE.md` TODO comments still have to be resolved
      by hand for that repo.
- [ ] **Only 6 of roughly 47 indicator pages have been checked.** Handle layout
      variants when they surface rather than pre-building fallbacks. The script
      stops and names the selector, which is the signal to look.
- [ ] **Site-repo wiring is out of scope for the script.** Chart code, the page
      in `indicators/<slug>.qmd`, and the sidebar entry stay manual.
- [ ] **The seven existing indicator repos are not migrated** to this pattern.
      They still carry `R/gen_narrative.R`, `R/utils/read_docx.R`, and the source
      `.docx` files in `data-raw/`. Decide whether to regenerate them from their
      published pages or leave them as they are.

### Closed by the build

- Captions with no `Data source:` line: tolerated and reported, not assumed from
  the last paragraph.
- Figures with no CSV: the narrative gets the caption, `PROVENANCE.md` says why
  there is nothing to build, and `build_data.R` gets no block for it.
