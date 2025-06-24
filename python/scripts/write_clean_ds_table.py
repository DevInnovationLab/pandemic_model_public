"""Write presentable table of final datasets."""
from pathlib import Path

import click
import pandas as pd

@click.command()
@click.argument('fp', type=click.Path(exists=True, file_okay=True, dir_okay=False))
@click.option('--measure', default='intensity', type=click.Choice(['intensity', 'severity']))
def write_clean_ds_table(fp: Path, measure: str):

    # Consider moving toward reading measure from the filepath.
    ds = pd.read_csv(fp)

    # Create a publication-quality LaTeX table of diseases
    table_data = ds[['disease', 'transmission', measure, 'duration', 'year_start', 'year_end']].copy()
    table_data['disease'] = table_data['disease'].str.title()
    table_data.loc[table_data['disease'] == 'Hiv/Aids', 'disease'] = "HIV/AIDS"
    table_data.loc[table_data['disease'] == 'Covid-19', 'disease'] = "COVID-19"

    # Sort by start year ascending
    table_data = table_data.sort_values('year_start', ascending=True)

    # Clean measure strings
    measure_lab = measure.title()
    measure_units = 'deaths per 10,000 individuals per year' if measure == 'intensity' else 'deaths per 10,000 individuals'

    # Create LaTeX table string
    latex_table = "\\begin{table}[t!]\n\\centering\n"
    latex_table += "\\caption{Final all risks dataset}\n"
    latex_table += "\\small\n"
    latex_table += "\\begin{tabularx}{\\textwidth}{l>{\\centering\\arraybackslash}Xccc>{\\centering\\arraybackslash}X}\n"  # Two centered X columns
    latex_table += "\\toprule\n"
    latex_table += f"Disease & Transmission mode & {measure_lab} (SU) & Start year & End year & Duration (years) \\\\\n"
    latex_table += "\\midrule\n"

    hiv_start_year = table_data.loc[table_data['disease'] == 'HIV/AIDS', 'year_start'].astype(int).iloc[0]
    # Add rows
    for _, row in table_data.iterrows():
        intensity_print = f"{row[measure]:.2f}" if row[measure] < 1 else f"{row[measure]:.1f}" if row[measure] < 10 else str(round(row[measure]))
        latex_table += f"{row['disease']} & "
        # The transmission column will now automatically wrap
        latex_table += f"{row['transmission'].replace('/', ' / ').title().replace('/ D', '/ d')} & "
        latex_table += f"{intensity_print} & "
        latex_table += f"{int(row['year_start'])} & "
        latex_table += f"{int(row['year_end'])} & "
        latex_table += f"{int(row['duration'])} \\\\\n"

    latex_table += "\\bottomrule\n"
    latex_table += "\\end{tabularx}\n"  # Changed to end tabularx
    latex_table += "\\label{tab:disease_events}\n"
    latex_table += f"""\\caption*{{\\footnotesize{{{measure_lab} is given in our standard units (SU), which are {measure_units} 
    using the population from the year of the epidemic's emergence. The duration of HIV/AIDS is set by doubling the time to its 
    peak mortality since its emergence in {hiv_start_year}.}}}}\n"""
    latex_table += "\\end{table}"

    # Optionally save to file
    outpath = Path("./output") /  (Path(fp).stem + ".tex")
    with open(outpath, "w") as f:
        f.write(latex_table)

if __name__ == "__main__":
    write_clean_ds_table()