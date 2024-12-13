import re

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

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
ptrs = ptrs[
    ptrs.columns[~ptrs.columns.isin(empty_col_idx)]
]
ptrs = ptrs[ptrs.apply(lambda x: x.notna().any(), axis=1)]

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
    
def extract_diseases(text):
    # Match text after the "* This list combines..." section and before " - PTRS"
    if isinstance(text, str):
        return re.findall(r"- (.+?) - PTRS", text)[0]
    else:
        return None

ptrs['platform'] = ptrs['question_num'].map(question_num_to_platform)
ptrs['disease'] = ptrs['question_text'].map(extract_diseases)
ptrs = ptrs \
    .drop(columns=['question_num', 'question_text']) \
    .set_index(['disease', 'platform'])

ptrs.columns.name = 'respondent'
ptrs = pd.DataFrame(ptrs.stack()).rename(columns={0: 'ptrs_range'})

ptrs['ptrs_range'] = ptrs['ptrs_range'] \
    .str.replace('%', '') \
    .str.replace('+', '-100') \
    .str.replace(' or higher', '-100')
# Should maybe not be interpreting + as 100%. Hard to decide though.

ptrs[['value_min', 'value_max']] = ptrs['ptrs_range'] \
    .str.extract("(\\d+)-(\\d+)", expand=True)

nan_idx = ptrs.apply(
    lambda x: x[['value_min', 'value_max']].isna().all() & x['ptrs_range'].isdigit(),
    axis=1
)
ptrs.loc[nan_idx, ['value_min', 'value_max']] = ptrs['ptrs_range']

ptrs['value_min'] = ptrs['value_min'].astype(float)
ptrs['value_max'] = ptrs['value_max'].astype(float)

ptrs = ptrs.sort_index(level=['disease', 'respondent', 'platform'])


ptrs['ptrs_mean'] = (ptrs['value_max'] + ptrs['value_min']) / 2
mean_ptrs_platform = ptrs \
    .groupby(['disease', 'platform'])['ptrs_mean'] \
    .mean() \
    .unstack()

mean_ptrs_platform = mean_ptrs_platform / 100
mean_ptrs_platform['Either independent'] = 1 - (1 - mean_ptrs_platform['Traditional only']) * (1 - mean_ptrs_platform['mRNA only'])

plot_df = mean_ptrs_platform.stack().reset_index().rename(columns={0: 'ptrs'})
plot_df['disease'] = plot_df['disease'].str.replace('Crimean-Congo haemorrhagic fever', 'CCHF')

plt.figure()
sns.scatterplot(plot_df, x='disease', y='ptrs', hue='platform')

plt.xlabel("Pathogen")
plt.xticks(rotation=45, rotation_mode='anchor', ha='right')
plt.ylabel("Vaccine probability of success")
plt.title("Expert survey vaccine PTRS")
plt.legend(title='Platform', loc='center left', bbox_to_anchor=(1, 0.5))

plt.gca().spines['top'].set_visible(False)
plt.gca().spines['right'].set_visible(False)
plt.tight_layout()
plt.savefig("ptrs.jpg")