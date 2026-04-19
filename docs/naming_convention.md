# Epidemic pipeline filepath convention

Artifacts from the Marani cleaning → filtering → distributional fits use **`__` (double underscore)** as the **only** separator between pipeline stages. Single `_` may appear **inside** a stage token (e.g. `0d01`, `incl_unid`). Parameter names are **glued** to their values where noted (`u200`, `n1000000`, `trunc10`).

## Stages

1. **Lineage** — Short id for the source epidemic table, including how COVID-19 severity was handled. Built from the clean sheet stem `epidemics_{YYMMDD}_...`: e.g. `epidemics_241210_clean` → `e241210c`, and `epidemics_241210_clean_upcov` (inverted COVID severity applied) → **`e241210c_upcov`**. COVID adjustment is **only** recorded in lineage, not in the filter slug.
2. **Filter** — Segment tag `filt`, then a **filter slug**: `scope_measure_thresh_year_min` with optional `_yearthreshonly`, `_incl_unid`. Scope is `all` or `airborne`.
3. **Downstream** — Tag `arr` (GPD arrival fit) or `dur` (duration MLE), each with a compact parameter tail.

## Patterns

| Artifact | Stem pattern |
|----------|----------------|
| Filtered CSV | `{lineage}__filt__{filter_slug}.csv` |
| GPD model directory | `{lineage}__filt__{filter_slug}__arr__gpd_{fit}_{arrival}_{trunc}_u{upper}_n{n}_s{seed}` |
| Duration sample CSV | `{lineage}__filt__{filter_slug}__dur__trunc{T}_n{n}_s{seed}.csv` |

- `{fit}` is the mortality measure used in the GPD (`intensity` or `severity`).
- `{arrival}` names the arrival / counting model in the fit (e.g. `poisson`); it is **not** assumed by the path parser—future models get a distinct token.
- `{trunc}` is the upper-tail truncation method (`sharp`, `smooth`, `taleb`).
- Inverted–COVID-severity epidemic tables are indicated only in **lineage** (e.g. `e241210c_upcov`); arrival GPD folders sit next to other lineages under `data/clean/arrival_distributions/`, not in a separate subfolder.

The substring `{lineage}__filt__{filter_slug}` is **shared** across filtered data, arrival, and duration outputs for the same filtering run.

## Measure abbreviations in filter slug

Filter and screening use 3-letter measure slugs: `int` → intensity, `sev` → severity. Threshold decimals use `d` instead of `.` (e.g. `0d01`).

## Python modules

- **pandemic-statistics** (`pandemic_statistics.pipeline_names`): lineage, filter slug, filtered CSV, GPD arrival stem helpers.
- **pandemic-model** (`pandemic_model.pipeline_names`): duration stem helpers only (`build_duration_csv_stem`, `parse_duration_csv_stem`).
