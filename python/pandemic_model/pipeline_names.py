"""Duration pipeline path stems (``__dur__`` segment)"""

from __future__ import annotations

import re


def build_duration_csv_stem(
    lineage: str,
    filter_slug: str,
    n_samples: int,
    seed: int,
) -> str:
    """
    Basename (without ``.csv``) for a saved duration parameter sample file.

    Pattern: ``{lineage}__filt__{filter_slug}__dur__n{N}_s{S}``
    """
    return (
        f"{lineage}__filt__{filter_slug}__dur__"
        f"n{n_samples}_s{seed}"
    )


def parse_duration_csv_stem(stem: str) -> dict:
    """Parse a duration CSV stem (path stem without ``.csv``)."""
    if "__dur__" not in stem:
        raise ValueError(f"Missing __dur__ in duration stem: {stem!r}")
    head, _, dur_tail = stem.partition("__dur__")
    lineage, _, filter_slug = head.partition("__filt__")
    if not lineage or not filter_slug:
        raise ValueError(f"Bad duration stem structure: {stem!r}")
    if re.match(r"^trunc\d+_", dur_tail):
        raise ValueError(
            f"Obsolete duration stem (trunc prefix removed): {stem!r}"
        )
    mo = re.match(r"^n(?P<n>\d+)_s(?P<s>\d+)$", dur_tail)
    if not mo:
        raise ValueError(f"Bad duration tail: {dur_tail!r}")
    return {
        "lineage": lineage,
        "filter_slug": filter_slug,
        "n_samples": int(mo.group("n")),
        "seed": int(mo.group("s")),
    }
