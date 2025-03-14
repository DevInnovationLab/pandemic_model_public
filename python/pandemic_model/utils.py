# Project-wide Python utilities.

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

viral_family_map = {
    'cchf': 'nairoviridae',
    'crimean_congo_haemorrhagic_fever': 'nairoviridae',
    'rift_valley_fever': 'phenuiviridae',
    'mers': 'coronaviridae',
    'ebola': 'filoviridae',
    'zika': 'flaviviridae',
    'nipah': 'paramyxoviridae',
    'flu': 'orthomyxoviridae',
    'chikungunya': 'togaviridae',
    'lassa': 'arenaviridae',
    'covid-19': 'coronaviridae'
}

def set_standard_plot_theme():
    # Set seaborn style for publication-quality figures
    sns.set_theme(style="whitegrid", context="paper")
    plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.sans-serif': ['Arial'],
    'font.size': 10,
    'axes.titlesize': 12,
    'axes.labelsize': 11,
    'xtick.labelsize': 10,
    'ytick.labelsize': 10,
    'legend.fontsize': 10,
    'legend.title_fontsize': 11
    })

    return


def get_annual_arrival_counts(df: pd.DataFrame, start_year: int, end_year: int) -> pd.Series:
    """Calculate annual counts of pandemic arrivals within a date range.

    Used to generate window counts for fitting Metastatistical Extreme Value Distributions (MEVD).
    Returns a pandas Series with years as index and counts of pandemic arrivals in each year.
    Years with no arrivals will have count 0.

    Args:
        df: DataFrame containing pandemic data with 'year_start' column
        start_year: First year to include in counts (inclusive)
        end_year: Last year to include in counts (inclusive)

    Returns:
        pd.Series with index of years and values of arrival counts
    """
    years = range(start_year, end_year + 1)
    arrival_counts = pd.Series(0, index=years, dtype=int)

    eval_df = df[df['year_start'].between(start_year, end_year)]
    df_counts = eval_df.groupby('year_start').size()
    arrival_counts.loc[df_counts.index] = df_counts

    return arrival_counts
