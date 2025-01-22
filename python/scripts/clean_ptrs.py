# Clean vaccine probability of success data for interval regression.

import re

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

from pandemic_model.utils import viral_family_map

# Helper functions -------------------
def question_num_to_platform(q: str) -> str:
  if not isinstance(q, str):
    return None
  elif q.find("B3.21") > -1:
    return "mRNA only"
  elif q.find("B3.23") > -1:
    return "Traditional only"
  elif q.find("B3.25") > -1:
    return "Both mRNA and traditional"
  else:
    return None


def extract_disease(text):
  # Match text after the "* This list combines..." section and before " - PTRS"
  if isinstance(text, str):
    return re.findall(r"- (.+?) - PTRS", text)[0]
  else:
    return None


# Run clean ------------------------

if __name__ == "__main__":

  ptrs_raw = pd.read_excel(
    "C:/Users/squaade/Box/CEPI Expert Survey (IRB coverage)/CEPI Expert Survey_May 21_2024_Sebastian_Updates.xlsx",
    sheet_name='PTRS By Disease',
    skiprows=1,
    header=None,
  )
  ptrs = ptrs_raw \
    .rename(columns={0: 'question_num', 1: 'question_text'}) \
    .drop(columns=[2, 3])

  # Remove empty rows and columns
  empty_cols = ptrs.apply(lambda x: x.isna().all(), axis=0)
  empty_col_idx = empty_cols[empty_cols == True].index
  ptrs = ptrs[ptrs.columns[~ptrs.columns.isin(empty_col_idx)]]
  ptrs = ptrs[ptrs.apply(lambda x: x.notna().any(), axis=1)]

  ptrs['platform'] = ptrs['question_num'].map(question_num_to_platform)
  ptrs['disease'] = ptrs['question_text'].map(extract_disease)
  ptrs['disease'] = ptrs['disease'] \
    .str.replace('Crimean-Congo haemorrhagic fever', 'CCHF') \
    .str.lower() \
    .str.replace(' ',  '_')

  ptrs = ptrs \
    .drop(columns=['question_num', 'question_text']) \
    .set_index(['disease', 'platform'])

  ptrs.columns.name = 'respondent'
  ptrs = ptrs.stack().to_frame().rename(columns={0: 'ptrs_range'})

  ptrs['ptrs_range'] = ptrs['ptrs_range'] \
    .str.replace('%', '') \
    .str.replace('+', '-100') \
    .str.replace(' or higher', '-100') \
    .str.strip()

  ptrs[['value_min', 'value_max']] = ptrs['ptrs_range'] \
    .str.extract("(\\d+)-(\\d+)", expand=True)

  # Handle cases with precise estimates.
  precise_idx = ptrs.apply(
    lambda x: x[['value_min', 'value_max']].isna().all() & x['ptrs_range'].isdigit(),
    axis=1
  )
  ptrs.loc[precise_idx, ['value_min', 'value_max']] = ptrs['ptrs_range']

  ptrs['value_min'] = ptrs['value_min'].astype(float) / 100
  ptrs['value_max'] = ptrs['value_max'].astype(float) / 100

  ptrs = ptrs.sort_index(level=['disease', 'respondent', 'platform'])
  ptrs['viral_family'] = ptrs.index.get_level_values('disease').map(viral_family_map)

  # Save df for interval regression
  out_df = ptrs.drop(columns='ptrs_range')
  out_df.to_csv("./data/clean/vaccine_ptrs.csv")

  # DEPRECATED ---------------------------------------------

  # # Should maybe do before 
  # ptrs['ptrs_mean'] = (ptrs['value_max'] + ptrs['value_min']) / 2
  # mean_ptrs_platform = ptrs \
  #   .groupby(['disease', 'platform'])['ptrs_mean'] \
  #   .mean() \
  #   .unstack()

  # mean_ptrs_platform = mean_ptrs_platform / 100
  # mean_ptrs_platform['Either independent'] = 1 - (1 - mean_ptrs_platform['Traditional only']) * (1 - mean_ptrs_platform['mRNA only'])

  # plot_df = mean_ptrs_platform.stack().reset_index().rename(columns={0: 'ptrs'})
  # plot_df['disease'] = plot_df['disease'].str.replace('Crimean-Congo haemorrhagic fever', 'CCHF')

  # plt.figure()
  # sns.scatterplot(plot_df, x='disease', y='ptrs', hue='platform')

  # plt.xlabel("Pathogen")
  # plt.xticks(rotation=45, rotation_mode='anchor', ha='right')
  # plt.ylabel("Vaccine probability of success")
  # plt.title("Expert survey vaccine PTRS")
  # plt.legend(title='Platform', loc='center left', bbox_to_anchor=(1, 0.5))

  # plt.gca().spines['top'].set_visible(False)
  # plt.gca().spines['right'].set_visible(False)
  # plt.ylim([0, 1])
  # plt.tight_layout()
  # plt.savefig("./output/ptrs.jpg")

  # plot_df['disease'] = plot_df['disease'] \
  #   .str.lower() \
  #   .str.replace(' ', '_')

  # # Remove COVID-19
  # plot_df = plot_df[plot_df['disease'] != 'covid-19']
  # plot_df['viral_family'] = plot_df['disease'].map(viral_family_map)
  # assert(plot_df['viral_family'].notna().all())

  # # Save PTRS
  # out_df = plot_df.copy()
  # out_df['platform'] = out_df['platform'].map({
  #   'Both mRNA and traditional': 'both_raw',
  #   'mRNA only': 'mrna_only',
  #   'Traditional only': 'trad_only',
  #   'Either independent': 'either_indep'
  # })

  # out_df = out_df.pivot(index='viral_family', columns='platform', values='ptrs')

  # # Make up unknown PTRS numbers.
  # unknown_ptrs = pd.Series({'viral_family': 'unknown',
  #                           'both_raw': 0.5,
  #                           'mrna_only': 0.4, 
  #                           'trad_only': 0.4,
  #                           'either_indep': 1 - 0.36})

  # out_df = pd.concat([out_df.reset_index(), unknown_ptrs.to_frame().T], axis=0).reset_index(drop=True)

  # out_df.to_csv("./data/clean/vaccine_ptrs.csv")
