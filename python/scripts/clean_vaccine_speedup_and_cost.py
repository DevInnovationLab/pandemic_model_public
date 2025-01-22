
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

from pandemic_model.utils import viral_family_map

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
    .apply(lambda s: s.split(".")[0].strip()) \
    .str.replace('Crimean-Congo haemerroghic fever', 'CCHF', case=False)

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

plot_df = vaccine_times_final.reset_index()

plt.figure()
sns.scatterplot(plot_df, x='disease', y='years_mean', hue='adv_RD')

plt.xlabel("Pathogen")
plt.xticks(rotation=45, rotation_mode='anchor', ha='right')
plt.ylabel("Time to vaccine (years)")
plt.title("Time to vaccine (expert survey averages)")
plt.legend(title='With Adv R&D', loc='center left', bbox_to_anchor=(1, 0.5))

plt.gca().spines['top'].set_visible(False)
plt.gca().spines['right'].set_visible(False)
plt.tight_layout()
plt.savefig("time_to_vaccine.jpg")

# Do second plot that provides the underlying data points
color_mapping = {
    ('vaccine_speedup_agg', False): 'blue',
    ('vaccine_speedup_agg', True): 'orange',
    ('plot_df', False): 'blue',
    ('plot_df', True): 'orange'
}

# Add a 'source' column to distinguish between the two datasets
vaccine_speedup_agg['source'] = 'vaccine_speedup_agg'
plot_df['source'] = 'plot_df'

# Concatenate both datasets to make plotting easier
combined_df = pd.concat([vaccine_speedup_agg.reset_index(), plot_df])

# Create a column to represent the combination of source and adv_RD
combined_df['source_adv_RD'] = list(zip(combined_df['source'], combined_df['adv_RD']))

# Create the figure and axis
fig, ax = plt.subplots(figsize=(10, 6))

# Plot all points at once using the custom color mapping
sns.scatterplot(
    data=combined_df,
    x='disease',
    y='years_mean',
    hue='source_adv_RD',  # Use the combined column for unique combinations
    style='source',       # Different markers for means vs. distribution
    markers={'vaccine_speedup_agg': 'o', 'plot_df': 'D'},  # Circle for distribution, diamond for means
    size='source',        # Larger size for means
    sizes={'vaccine_speedup_agg': 50, 'plot_df': 100},
    palette=color_mapping,  # Apply the custom color mapping
    ax=ax
)
ax.set_xlabel("Disease")
ax.set_ylabel("Time to vaccine (years)")

handles, labels = ax.get_legend_handles_labels()
ax.legend(
    handles=[handles[1], handles[2]],  # Select the handles for blue and orange
    labels=['Baseline', 'Adv R&D'],        # Legend labels
    fontsize=12,
    title_fontsize=14,
    loc='upper right'  # Position the legend in the upper right
)

ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

fig.tight_layout()
fig.savefig("time_to_vaccine_dist.jpg", dpi=450)

## Write to put into simulation model

plot_df['disease'] = plot_df['disease'] \
    .str.lower() \
    .str.replace(' ', '_') \
    .str.replace('-', '_') \
    .str.replace('mrna_', '')

plot_df['viral_family'] = plot_df['disease'].map(viral_family_map)
assert(plot_df['viral_family'].notna().all()) # Ensure all diseases have viral families

plot_df.to_csv("./pandemic-loss-modeling/output/times_to_vaccine.csv")
    
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

vaccine_cost_final['viral_family'] = vaccine_cost_final.index.map(viral_family_map)

# Seem like some people think things would get more expensive?
# You need to find the text for these questions.
