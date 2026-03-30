"""Fit generalized Pareto arrival distributions for pandemic risk modeling.

Reads epidemic data from data/clean/novel_epidemics_*.csv and writes fitted
arrival distributions to output/arrival_distributions/.

Must be run from the repository root:
    cd python && poetry run python scripts/fit_arrival_distributions.py

Outputs are named using the convention:
    gpd_{scope}_filt_{filt_measure}_fit_{fit_measure}_{threshold}_{year_min}
    _poisson_sharp_upper_{upper}_n_{n_samples}_seed_{seed}

These match the naming convention that MATLAB reads via parse_arrival_dist_fp.
"""

import re
from pathlib import Path

import numpy as np
import pandas as pd

from pandemic_statistics.constants import PRESENT_YEAR
from pandemic_statistics.pareto import ArrivalGPD

DATA_DIR = Path("data/clean")
OUTPUT_DIR = Path("output/arrival_distributions")

# Matches: novel_epidemics_{scope}_{filt_measure}_{threshold}_{year_min}[_mod].csv
_FILENAME_RE = re.compile(
    r"novel_epidemics_(?P<scope>[a-z_]+)_(?P<filt_measure>[a-z]+)"
    r"_(?P<threshold>\d+d\d+)_(?P<year_min>\d{4})(?P<mod>_mod)?"
)

# Fits to run for every dataset
_BASE_CONFIG = [
    dict(fit_measure="severity", trunc_method="sharp", upper_bound=200.0),
]

# Additional upper-bound variants run only for the all-risk scope dataset
_ALL_SCOPE_EXTRA_UPPERS = [1000.0, 10000.0]

_BASE_SAMPLE_SIZES = (50_000, 1_000_000)

START_GRID = [
    (0.01, 0.1, 1.0),
    (0.05, 0.2, 2.0),
    (0.1, 0.3, 0.5),
]


def _parse_fp(fp: Path):
    m = _FILENAME_RE.fullmatch(fp.stem)
    if not m:
        raise ValueError(f"Filename does not match expected pattern: {fp.stem}")
    return (
        m.group("scope"),
        m.group("filt_measure"),
        float(m.group("threshold").replace("d", ".")),
        int(m.group("year_min")),
        bool(m.group("mod")),
    )


def fit_and_save(
    fp: Path,
    fit_measure: str,
    trunc_method: str,
    upper_bound: float,
    n_samples: int,
    seed: int,
    outdir: Path,
):
    scope, filt_measure, lower_threshold, year_min, is_mod = _parse_fp(fp)

    ds = pd.read_csv(fp)
    mortality_data = ds.set_index("year_start")[fit_measure].copy()
    all_years = pd.Index(range(year_min, PRESENT_YEAR + 1))
    mortality_annual = mortality_data.reindex(all_years, fill_value=0)

    model = ArrivalGPD(
        arrival_type="poisson",
        trunc_method=trunc_method,
        y_min=lower_threshold,
        y_max=upper_bound,
    )

    fit_results = model.get_fit(
        mortality_annual.values,
        start_grid=START_GRID,
        return_all=True,
    )
    best = min(fit_results, key=lambda r: r["opt"].fun)
    model.set_params(best)

    param_samples = model.sample_params(n_samples=n_samples, seed=seed)
    param_samples = pd.DataFrame(param_samples, columns=["lambda", "xi", "sigma"])

    run_outdir = outdir / "modified" if is_mod else outdir
    run_outdir.mkdir(parents=True, exist_ok=True)

    threshold_str = str(lower_threshold).replace(".", "d")
    id_string = (
        f"gpd_{scope}_filt_{filt_measure}_fit_{fit_measure}"
        f"_{threshold_str}_{year_min}_poisson_{trunc_method}"
        f"_upper_{int(upper_bound)}_n_{n_samples}_seed_{seed}"
    )
    outpath = run_outdir / id_string
    model.save(outpath, measure=fit_measure, param_samples=param_samples)
    print(f"  Saved: {outpath.relative_to(OUTPUT_DIR.parent)}")


def main():
    fps = sorted(DATA_DIR.glob("novel_epidemics_*.csv"))
    if not fps:
        raise FileNotFoundError(f"No epidemic data files found in {DATA_DIR}")

    print(f"Fitting arrival distributions for {len(fps)} dataset(s)...")

    for fp in fps:
        scope, *_ = _parse_fp(fp)
        print(f"\n{fp.name}")

        for cfg in _BASE_CONFIG:
            for n_samples in _BASE_SAMPLE_SIZES:
                fit_and_save(fp, seed=42, n_samples=n_samples, outdir=OUTPUT_DIR, **cfg)

        if scope == "all":
            for upper in _ALL_SCOPE_EXTRA_UPPERS:
                for n_samples in _BASE_SAMPLE_SIZES:
                    fit_and_save(
                        fp,
                        fit_measure="severity",
                        trunc_method="sharp",
                        upper_bound=upper,
                        n_samples=n_samples,
                        seed=42,
                        outdir=OUTPUT_DIR,
                    )

    print("\nDone.")


if __name__ == "__main__":
    main()
