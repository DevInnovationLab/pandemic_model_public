
import pandas as pd

from pandemic_model.utils import pathogen_group_map

if __name__ == "__main__":

    # ---- General speedup and cleaning data ------------
    speedup_and_cost_df = pd.read_excel(
        "C:/Users/squaade/Box/CEPI Expert Survey (IRB coverage)/CEPI Expert Survey_May 21_2024_Sebastian_Updates.xlsx",
        sheet_name='Vaccine speedup and cost reduct',
        skiprows=1,
        header=None,
    )

    speedup_and_cost_df = speedup_and_cost_df.drop(columns=[0, 2, 3])
    empty_cols = speedup_and_cost_df.apply(lambda x: x.isna().all(), axis=0)
    empty_col_idx = empty_cols[empty_cols == True].index
    speedup_and_cost_df = speedup_and_cost_df[
        speedup_and_cost_df.columns[~speedup_and_cost_df.columns.isin(empty_col_idx)]
    ]

    # Also remove empty rows
    speedup_and_cost_df = speedup_and_cost_df[speedup_and_cost_df.apply(lambda x: x.notna().any(), axis=1)]
    speedup_and_cost_df = speedup_and_cost_df.rename(columns={1: 'disease'})
    speedup_and_cost_df['variable'] = speedup_and_cost_df['disease'].apply(
        lambda x: "Time estimate" if  x.find("Time estimate") > 0 else "Funding estimate"
    )

    speedup_and_cost_df['has_prototype'] = ~speedup_and_cost_df['disease'].str.contains("\\(")
    speedup_and_cost_df['has_prototype'] = speedup_and_cost_df['has_prototype'].astype(int)
     
    # Rows not denoting furthest candidate are before adv R&D
    speedup_and_cost_df['disease'] = speedup_and_cost_df['disease'] \
        .apply(lambda s: s.split("(")[0].strip()) \
        .apply(lambda s: s.split(".")[0].strip()) \
        .str.lower() \
        .str.replace('crimean-congo haemerroghic fever', 'cchf') \
        .str.replace('mrna ', '') \
        .str.replace(' ', '_')

    # ----- Vaccine R&D timelines -------------------------

    vaccine_speedup = speedup_and_cost_df[speedup_and_cost_df['variable'] == "Time estimate"].copy().drop(columns='variable')

    vaccine_speedup = vaccine_speedup.set_index(['disease', 'has_prototype'])
    vaccine_speedup.columns.name = 'respondent'
    vaccine_speedup = pd.DataFrame(vaccine_speedup.stack()).rename(columns={0: 'time_range'})

    vaccine_speedup['unit'] = vaccine_speedup['time_range'].apply(lambda x: x.split(" ")[1])
    vaccine_speedup['unit'].value_counts()

    # Only months and years
    vaccine_speedup[['value_min', 'value_max']] = vaccine_speedup['time_range'] \
        .str.extract("(\\d+)-(\\d+)", expand=True)

    vaccine_speedup[['value_min', 'value_max']] = vaccine_speedup[['value_min', 'value_max']].astype(float)

    vaccine_speedup[['value_min', 'value_max']] = vaccine_speedup.apply(
        lambda x: x[['value_min', 'value_max']] / 12 if x['unit'] == 'months' else x[['value_min', 'value_max']],
        axis=1
    )   

    vaccine_speedup = vaccine_speedup \
		.rename(columns=lambda x: x.replace('value', 'years')) \
		.drop(columns=['unit', 'time_range'])

    vaccine_speedup = vaccine_speedup.sort_index(level=['disease', 'has_prototype', 'respondent'])

    vaccine_speedup['pathogen'] = vaccine_speedup.index.get_level_values('disease').map(pathogen_group_map)

    vaccine_speedup.to_csv("./data/clean/vaccine_rd_timelines.csv")
    
    # ---- Vaccine R&D costs --------------------------------

    vaccine_cost = speedup_and_cost_df[speedup_and_cost_df['variable'] == "Funding estimate"].copy().drop(columns='variable')

    vaccine_cost = vaccine_cost.set_index(['disease', 'has_prototype'])
    vaccine_cost.columns.name = 'respondent'
    vaccine_cost = pd.DataFrame(vaccine_cost.stack()).rename(columns={0: 'cost_range'})

    vaccine_cost[['value_min', 'value_max']] = vaccine_cost['cost_range'] \
        .str.extract("(\\d+)-(\\d+)", expand=True)

    vaccine_cost[['value_min', 'value_max']] = vaccine_cost[['value_min', 'value_max']].astype(float)

    vaccine_cost = vaccine_cost.sort_index(level=['disease', 'has_prototype', 'respondent'])
 
    vaccine_cost['pathogen'] = vaccine_cost.index.get_level_values('disease').map(pathogen_group_map)

    vaccine_cost.to_csv("./data/clean/vaccine_rd_costs.csv")
