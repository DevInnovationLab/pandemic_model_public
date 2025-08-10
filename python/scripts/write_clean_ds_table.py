"""Write presentable table of final datasets."""
from pathlib import Path

import click
import pandas as pd

@click.command()
@click.argument('fp', type=click.Path(exists=True, file_okay=True, dir_okay=False))
@click.option('--measure', default='severity', type=click.Choice(['intensity', 'severity']))
def write_clean_ds_table(fp: Path, measure: str):
    """
    Write a LaTeX table of the final dataset using only standard tabular and formatting packages.
    """
    ds = pd.read_csv(fp)

    # Prepare and clean data
    table_data = ds[['disease', 'transmission', measure, 'duration', 'year_start', 'year_end']].copy()
    table_data['disease'] = table_data['disease'].str.title()
    table_data.loc[table_data['disease'] == 'Hiv/Aids', 'disease'] = "HIV/AIDS"
    table_data.loc[table_data['disease'] == 'Covid-19', 'disease'] = "COVID-19"
    table_data = table_data.sort_values('year_start', ascending=True)

    # Clean measure strings
    measure_lab = measure.title()
    measure_units = 'deaths per 10,000 individuals per year' if measure == 'intensity' else 'deaths per 10,000 individuals'

    # Formatting for measure column
    def format_measure(val):
        if val < 1:
            return f"{val:.2f}"
        elif val < 10:
            return f"{val:.1f}"
        else:
            return str(int(round(val)))

    # Build LaTeX table string using only tabular, hline, etc.
    latex_table = []
    latex_table.append("\\begin{table}[t!]")
    latex_table.append("\\centering")
    latex_table.append("\\caption{\\textbf{Major pandemic and epidemic outbreaks in the final dataset}}")
    latex_table.append("\\small")
    latex_table.append("\\begin{tabular}{l l c c c c}")
    latex_table.append("\\hline \\hline")
    latex_table.append(f"Disease & Transmission & {measure_lab} (SU) & Start & End & Duration \\\\")
    latex_table.append("        & mode          &               & year  & year & (years) \\\\")
    latex_table.append("\\hline")

    # Write each row
    for _, row in table_data.iterrows():
        disease = row['disease']
        transmission = row['transmission'].replace('/', ' / ').replace('/ D', ' d')
        # Capitalize transmission mode for consistency, but keep slashes
        transmission = transmission[0].upper() + transmission[1:] if transmission else transmission
        measure_val = format_measure(row[measure])
        start = int(row['year_start'])
        end = int(row['year_end'])
        duration = int(row['duration'])
        latex_table.append(f"{disease} & {transmission} & {measure_val} & {start} & {end} & {duration} \\\\")

    latex_table.append("\\hline")
    latex_table.append("\\end{tabular}")
    latex_table.append("\\begin{center}")
    latex_table.append(f"""\\parbox{{5in}}{{\\footnotesize \\textit{{Note:}} {measure_lab} is reported in standard units (SU), defined as {measure_units} using the population in the year of epidemic emergence. HIV/AIDS duration is set to twice the number of years until peak mortality.}}""")
    latex_table.append("\\end{center}")
    latex_table.append("\\label{tab:disease_events}")
    latex_table.append("\\end{table}")

    # Save to file
    outpath = Path("./output") / (Path(fp).stem + ".tex")
    with open(outpath, "w") as f:
        f.write('\n'.join(latex_table))

if __name__ == "__main__":
    write_clean_ds_table()