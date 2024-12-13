import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

vaccine_speedup_raw = pd.read_excel(
    "C:/Users/squaade/Box/CEPI Expert Survey (IRB coverage)/CEPI Expert Survey_May 21_2024_Sebastian_Updates.xlsx",
    sheet_name='Vaccine speedup and cost reduct',
    skiprows=1,
    header=None,
)

# Clean data
vaccine_speedup_raw = vaccine_speedup_raw.drop(columns=[0, 2, 3])
empty_cols = vaccine_speedup_raw.apply(lambda x: x.isna().all(), axis=0)
empty_col_idx = empty_cols[empty_cols == True].index
vaccine_speedup_raw = vaccine_speedup_raw[
    vaccine_speedup_raw.columns[~vaccine_speedup_raw.columns.isin(empty_col_idx)]
]

# Also remove empty rows
vaccine_speedup_raw = vaccine_speedup_raw[vaccine_speedup_raw.apply(lambda x: x.notna().any(), axis=1)]
vaccine_speedup_raw = vaccine_speedup_raw.rename(columns={1: 'disease'})
vaccine_speedup_raw['variable'] = vaccine_speedup_raw['disease'].apply(
    lambda x: "Time estimate" if  x.find("Time estimate") > 0 else "Funding estimate"
)

vaccine_speedup_raw['adv_RD'] = ~vaccine_speedup_raw['disease'].str.contains("\\(") 
# Rows not denoting furthest candidate are before adv R&D
vaccine_speedup_raw['disease'] = vaccine_speedup_raw['disease'] \
    .apply(lambda s: s.split("(")[0].strip()) \
    .apply(lambda s: s.split(".")[0].strip())


# Get vaccine speedup diff
vaccine_speedup = vaccine_speedup_raw[vaccine_speedup_raw['variable'] == "Time estimate"]

vaccine_speedup = vaccine_speedup.set_index(['disease', 'adv_RD']).drop(columns='variable')
vaccine_speedup.columns.name = 'respondent'
vaccine_speedup = pd.DataFrame(vaccine_speedup.stack()).rename(columns={0: 'time_range'})

vaccine_speedup['unit'] = vaccine_speedup['time_range'].apply(lambda x: x.split(" ")[1])
vaccine_speedup['unit'].value_counts()

# Only months and years
vaccine_speedup[['value_min', 'value_max']] = vaccine_speedup['time_range'] \
    .str.extract("(\\d+)-(\\d+)", expand=True)

vaccine_speedup['value_min'] = vaccine_speedup['value_min'].astype(float)
vaccine_speedup['value_max'] = vaccine_speedup['value_max'].astype(float)

vaccine_speedup[['value_min', 'value_max']] = vaccine_speedup.apply(
    lambda x: x[['value_min', 'value_max']] / 12 if x['unit'] == 'months' else x[['value_min', 'value_max']],
    axis=1
)

vaccine_speedup = vaccine_speedup \
    .rename(columns=lambda x: x.replace('value', 'years')) \
    .drop(columns=['unit', 'time_range'])
vaccine_speedup['years_mean'] = (vaccine_speedup['years_max'] + vaccine_speedup['years_min']) / 2

vaccine_speedup = vaccine_speedup.sort_index(level=['disease', 'adv_RD', 'respondent'])
vaccine_speedup_agg = vaccine_speedup[
    vaccine_speedup.groupby(['disease', 'respondent']).transform('size') == 2
]

vaccine_speedup_diffs = vaccine_speedup_agg \
    .sort_index(level=['disease', 'respondent', 'adv_RD'], ascending=[True, True, False]) \
    .groupby(level=['disease', 'respondent'])['years_mean'] \
    .diff()

vaccine_speedup_final = vaccine_speedup_diffs \
    .groupby('disease') \
    .apply(lambda x: x[x.notna()].mean())

vaccine_times_final = vaccine_speedup_agg \
    .groupby(['disease', 'adv_RD'])['years_mean'] \
    .mean()

plot_df = vaccine_times_final.rename('time_to_vaccine').reset_index()
plot_df['disease'] = plot_df['disease'].str.replace('Crimean-Congo haemerroghic fever', 'CCHF', case=False)

plt.figure()
sns.scatterplot(plot_df, x='disease', y='time_to_vaccine', hue='adv_RD')

plt.xlabel("Pathogen")
plt.xticks(rotation=45, rotation_mode='anchor', ha='right')
plt.ylabel("Time to vaccine (years)")
plt.title("Time to vaccine (expert survey averages)")
plt.legend(title='With Adv R&D', loc='center left', bbox_to_anchor=(1, 0.5))

plt.gca().spines['top'].set_visible(False)
plt.gca().spines['right'].set_visible(False)
plt.tight_layout()
plt.savefig("time_to_vaccine.jpg")

    
# Now do vaccine cost
vaccine_cost = vaccine_speedup_raw[vaccine_speedup_raw['variable'] == "Funding estimate"]

vaccine_cost = vaccine_cost.set_index(['disease', 'adv_RD']).drop(columns='variable')
vaccine_cost.columns.name = 'respondent'
vaccine_cost = pd.DataFrame(vaccine_cost.stack()).rename(columns={0: 'cost_range'})

vaccine_cost[['value_min', 'value_max']] = vaccine_cost['cost_range'] \
    .str.extract("(\\d+)-(\\d+)", expand=True)

vaccine_cost['value_min'] = vaccine_cost['value_min'].astype(float)
vaccine_cost['value_max'] = vaccine_cost['value_max'].astype(float)
vaccine_cost['cost_mean'] = (vaccine_cost['value_min'] + vaccine_cost['value_max']) / 2


vaccine_cost = vaccine_cost.sort_index(level=['disease', 'adv_RD', 'respondent'])
vaccine_cost_agg = vaccine_cost[
    vaccine_cost.groupby(['disease', 'respondent']).transform('size') == 2
]

vaccine_cost_diffs = vaccine_cost_agg \
    .sort_index(level=['disease', 'respondent', 'adv_RD']) \
    .groupby(level=['disease', 'respondent'])['cost_mean'] \
    .diff()

# Need to check this again
vaccine_cost_final = vaccine_cost_diffs \
    .groupby('disease') \
    .apply(lambda x: x[x.notna()].mean())

# Seem like some people think things would get more expensive?
# You need to find the text for these questions.
