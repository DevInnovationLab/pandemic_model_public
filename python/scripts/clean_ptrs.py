# Clean vaccine probability of success data for interval regression.

import re

import pandas as pd

from pandemic_model.utils import pathogen_group_map

# Helper functions -------------------
def question_num_to_platform(q: str) -> str:
  if not isinstance(q, str):
    return None
  elif q.find("B3.21") > -1:
    return "mrna_only"
  elif q.find("B3.23") > -1:
    return "traditional_only"
  elif q.find("B3.25") > -1:
    return "both"
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

  # Load data -----------------------------
  ptrs_raw = pd.read_excel(
    "C:/Users/squaade/Box/CEPI Expert Survey (IRB coverage)/CEPI Expert Survey_May 21_2024_Sebastian_Updates.xlsx",
    sheet_name='PTRS By Disease',
    skiprows=1,
    header=None,
  )

  pathogen_info = pd.read_csv("./data/raw/pathogen_info.csv")

  # Clean PTRS data -------------------------------------
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
  ptrs['pathogen'] = ptrs.index.get_level_values('disease').map(pathogen_group_map)

  # Merge adv RD status onto PTRS data ----------------
  pathogen_info = pathogen_info.set_index('pathogen')
  ptrs['has_prototype'] = ptrs['pathogen'].map(pathogen_info['has_prototype'])

  # Save df for interval regression
  out_df = ptrs.drop(columns='ptrs_range')
  out_df.to_csv("./data/clean/vaccine_ptrs.csv")
