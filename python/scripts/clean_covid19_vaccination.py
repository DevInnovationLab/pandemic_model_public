"""clean_covid19_vaccination.py — Clean global COVID-19 vaccination rollout data.

Reads cumulative vaccination share (Our World in Data), filters for the World
aggregate, and interpolates to mid-month values to produce a monthly vaccination
rollout series.

Inputs:
    data/raw/share-of-people-who-completed-the-initial-covid-19-vaccination-protocol
Outputs:
    data/clean/covid19_cum_vax_over_time.csv

Run from the repository root:
    python python/scripts/clean_covid19_vaccination.py
"""
from calendar import monthrange

import numpy as np
import pandas as pd

# --- 1. Load and normalise ---
df = pd.read_csv(
    "./data/raw/share-of-people-who-completed-the-initial-covid-19-vaccination-protocol.csv",
    names=["entity", "day", "cum_vax_share"],
    header=0,
)
df["day"] = pd.to_datetime(df["day"], format="%Y-%m-%d")
df["cum_vax_share"] = df["cum_vax_share"] / 100

# --- 2. Filter for World ---
world = df[df["entity"] == "World"].sort_values("day").copy()

# --- 3. Mid-month interpolation ---
# Match MATLAB: mid_date = start_of_month + floor((days_in_month - 1) / 2) days
def mid_month_date(year: int, month: int) -> pd.Timestamp:
    days_in_month = monthrange(year, month)[1]
    offset = (days_in_month - 1) // 2
    return pd.Timestamp(year, month, 1) + pd.Timedelta(days=offset)


rows = []
for (year, month), group in world.groupby([world["day"].dt.year, world["day"].dt.month]):
    mid = mid_month_date(year, month)
    group = group.sort_values("day")
    day_ord = group["day"].map(lambda d: d.toordinal()).to_numpy()
    vax = group["cum_vax_share"].to_numpy()
    interp_val = float(np.interp(mid.toordinal(), day_ord, vax))
    rows.append({"date": mid, "cum_vax_rate": interp_val})

mid_month_vax = pd.DataFrame(rows).sort_values("date").reset_index(drop=True)
mid_month_vax["rollout_month"] = range(1, len(mid_month_vax) + 1)

# --- 4. Check for contiguous months ---
# Encode as year*100 + month; consecutive differences are 1 (same year) or 89 (Dec -> Jan)
ym = mid_month_vax["date"].dt.year * 100 + mid_month_vax["date"].dt.month
diffs = ym.diff().dropna()
if diffs.isin([1, 89]).all():
    print("Year-months are contiguous.")
else:
    print("Year-months are not contiguous.")

# --- 5. Save ---
output_path = "./data/derived/covid19_cum_vax_over_time.csv"
mid_month_vax.to_csv(output_path, index=False)
print(f"Saved COVID-19 vaccination rollout to {output_path}")
