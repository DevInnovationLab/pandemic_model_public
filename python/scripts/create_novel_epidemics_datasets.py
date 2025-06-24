"""Create datasets used for statistical pandemic modeling."""
import io
from collections import defaultdict
from pathlib import Path

import click
import matplotlib.pyplot as plt
import pandas as pd
import plotly.graph_objects as go
import plotly.io as pio
import yaml


def get_inclusion_path(row, thresh):
    """
    Returns a list of node labels from column 0 through 5, 
    stopping at the first 'fail' (exclusion).
    
    0: "Epidemics since 1900"
    1: "Below detectability threshold" or "Above detectability threshold"
    2: "Non-viral" or "Viral"
    3: "Unidentified" or "Identified"
    4: "Not contagious" or "Contagious"
    5: "Not novel" or "Novel"
    """
    path = []
    
    # Column 0
    path.append("Epidemics since 1900")
    
    # Column 1
    if row['intensity'] < thresh:
        path.append("Below detectability threshold")
        return path
    else:
        path.append("Above detectability threshold")
    
    # Column 2
    if 'vira' not in row['type']:
        path.append("Non-viral")
        return path
    else:
        path.append("Viral")
    
    # Column 3
    if not row['contagious']:
        path.append("Not contagious")
        return path
    else:
        path.append("Contagious")
        
    # Column 4
    if row['unidentified']:
        path.append("Unidentified")
        return path
    else:
        path.append("Identified")
    
    # Column 5
    if row['recurrent']:
        path.append("Recurrent")
    else:
        path.append("Novel")
    
    return path


def plot_tidy_binary_sankey(df, thresh, year_min, title="Epidemic Exclusion Flow"):
    """
    Creates a tidy Sankey with exactly 6 columns:
      0: ["All data"]
      1: ["Below detectability threshold", "Above detectability threshold"]
      2: ["Non-viral", "Viral"]
      3: ["Unidentified", "Identified"]
      4: ["Not contagious", "Contagious"]
      5: ["Recurrent", "Novel"]
    
    We truncate each row's path at the first failure, 
    so no self-loops are produced.
    
    Flows to excluded nodes are colored gray; 
    pass flows are colored by the source node's color.
    """
    # A) Define columns
    min_year_label = f"Epidemics since {year_min}"
    columns = [
        [min_year_label], 
        ["Below detectability threshold", "Above detectability threshold"],
        ["Non-viral", "Viral"],
        ["Not contagious", "Contagious"],
        ["Unidentified", "Identified"],
        ["Recurrent", "Novel"]
    ]
    
    node_list = []
    for col in columns:
        node_list.extend(col)
    
    node_index = {lbl: i for i, lbl in enumerate(node_list)}
    
    # "excluded" nodes for coloring flows gray
    excluded_nodes = {
        "Below detectability threshold",
        "Non-viral",
        "Not contagious",
        "Unidentified",
        "Recurrent"
    }
    
    # B) Gather flows and counts
    flows = defaultdict(int)
    node_counts = defaultdict(int)
    
    for _, row in df.iterrows():
        path = get_inclusion_path(row, thresh)
        # Count nodes
        for node in path:
            node_counts[node] += 1
        # Add edges from path[i] -> path[i+1]
        for i in range(len(path) - 1):
            src, tgt = path[i], path[i+1]
            flows[(src, tgt)] += 1
    
    # Add counts to labels
    node_list_with_counts = [
        f"{lbl}<br>[n={node_counts[lbl]}]" for lbl in node_list
    ]
    
    # Build Sankey lists
    source_list = []
    target_list = []
    value_list = []
    for (s_lbl, t_lbl), count in flows.items():
        source_list.append(node_index[s_lbl])
        target_list.append(node_index[t_lbl])
        value_list.append(count)
    
    # C) Position each node in columns uniformly
    node_x = [0]*len(node_list)
    node_y = [0]*len(node_list)
    
    for col_i, col_nodes in enumerate(columns):
        if len(col_nodes) == 1:
            # e.g. column 0 has just "All data"
            n_lbl = col_nodes[0]
            idx = node_index[n_lbl]
            node_x[idx] = float(col_i)
            node_y[idx] = 0.5
        else:
            # 2 outcomes
            upper_lbl, lower_lbl = col_nodes[0], col_nodes[1]
            upper_idx = node_index[upper_lbl]
            lower_idx = node_index[lower_lbl]

            node_x[lower_idx] = float(col_i)
            node_y[lower_idx] = 0.5 

            node_x[upper_idx] = float(col_i)
            node_y[upper_idx] = 0.52
    
    # Normalize to [0,1]
    min_x, max_x = min(node_x), max(node_x)
    min_y, max_y = min(node_y), max(node_y)
    dx = max_x - min_x if max_x != min_x else 1
    dy = max_y - min_y if max_y != min_y else 1
    pad = 0.05
    node_x_norm = [pad + (x - min_x)/dx*(1-2*pad) for x in node_x]
    node_y_norm = [pad + (y - min_y)/dy*(1-2*pad) for y in node_y]
    
    # D) Colors
    color_map = {
        min_year_label: "rgba(76,114,176,0.8)",
        "Above detectability threshold": "rgba(221,132,82,0.8)",
        "Below detectability threshold": "rgba(221,132,82,0.4)",
        "Viral": "rgba(85,168,104,0.8)",
        "Non-viral": "rgba(85,168,104,0.4)",
        "Contagious": "rgba(129,114,179,0.8)",
        "Not contagious": "rgba(129,114,179,0.4)",
        "Identified": "rgba(196,78,82,0.8)",
        "Unidentified": "rgba(196,78,82,0.4)",
        "Novel": "rgba(147,120,96,0.8)",
        "Recurrent": "rgba(147,120,96,0.4)",
    }
    
    node_colors = [
        "rgba(150,150,150,0.8)" if lbl in excluded_nodes else color_map.get(lbl, "rgba(180,180,180,0.8)")
        for lbl in node_list
    ]
    
    # Link color: if target is an "excluded" node, grey; else color by source
    link_colors = []
    for s_i, t_i in zip(source_list, target_list):
        s_lbl = node_list[s_i]
        t_lbl = node_list[t_i]
        if t_lbl in excluded_nodes:
            link_colors.append("rgba(150,150,150,0.7)")
        else:
            link_colors.append(color_map.get(s_lbl, "rgba(180,180,180,0.8)"))
    
    # E) Build Plotly Sankey
    fig = go.Figure(data=[
        go.Sankey(
            arrangement="fixed",
            node=dict(
                pad=15,
                thickness=15,
                line=dict(color="black", width=0.3),
                x=node_x_norm,
                y=node_y_norm,
                color=node_colors,
                hovertemplate="%{label}",
            ),
            link=dict(
                source=source_list,
                target=target_list,
                value=value_list,
                color=link_colors
            )
        )
    ])
    
    fig.update_layout(
        font=dict(family="Arial", size=12, color='black'),
        title_font_size=12,
        paper_bgcolor='white',
        plot_bgcolor='white',
        margin=dict(l=40, r=40, t=160, b=100),
        width=1200,
        height=600
    )
    
    for i, lbl in enumerate(node_list_with_counts):
        if min_year_label in lbl:
            offset = -1.3  # bigger offset for the first column
        elif "Below detectability threshold" in lbl:
            offset = -0.3
        else:
            # Decrease offset as i increases (make it smaller in absolute terms)
            offset = -0.15 + ((i-1) * 0.012)  # offset gets closer to zero as i increases
            
        # Create index that pairs nodes with same integer division by 2
        if i == 0:
            index = 0
        elif i % 2 == 0:
            index = i - 1
        else:
            index = i + 1
            
        fig.add_annotation(
            x=node_x_norm[index],
            y=node_y_norm[index] - offset,  # shift label above the node
            text=lbl,
            showarrow=False,
            xanchor="center",  # center the text horizontally over the node
            yanchor="bottom",  # the annotation's bottom edge is at (y-offset)
            font=dict(size=14.5, color="black")
        )
    
    img_bytes = pio.to_image(fig, format="png", scale=4)
    mpl_fig, ax = plt.subplots(figsize=(10, 5), dpi=600)
    ax.imshow(plt.imread(io.BytesIO(img_bytes)))
    ax.axis("off")
    mpl_fig.tight_layout()

    return mpl_fig, ax


@click.command()
@click.option('--measure', default='intensity', type=click.Choice(['intensity', 'severity']))
@click.option('--thresh', default=0.01, type=float)
@click.option('--year-min', default=1900, type=int)
def create_pandemic_datasets(measure, thresh, year_min):

    all_epidemics_ds = pd.read_excel("./data/raw/epidemics_marani_240816.xlsx")
    all_epidemics_ds.rename(columns={'severity_smu': 'severity'}, inplace=True)

    """
    Although the HIV pandemic has not ended, we set its duration to
    twice the time it took for it to achieve its peak in terms of annual deaths per 10,000.
    This peak was achieved in 2003.
    With an arrival year of 1980, we set the duration to 46 years.
    We set COVID-19 to terminate in 2024.
    """

    all_epidemics_ds.loc[all_epidemics_ds['disease'] == 'hiv/aids', 'duration'] = 46
    
    # Define airborne, unidentified and contagious epidemics
    all_epidemics_ds['unidentified'] = (all_epidemics_ds['type'].str.contains("/")) | (all_epidemics_ds['type'] == 'unknown')
    all_epidemics_ds['airborne'] = all_epidemics_ds['transmission'].str.contains('airborne|droplet')
    all_epidemics_ds['contagious'] = ~all_epidemics_ds['transmission'].isin(['bite', 'animalcontact/bite'])
    all_epidemics_ds['recurrent'] = all_epidemics_ds.groupby('disease')['year_start'].transform(lambda x: any(x < year_min))

    # Clean up for unidentified diseases
    unid_idx = all_epidemics_ds['unidentified']
    all_epidemics_ds.loc[unid_idx, 'transmission'] = 'unknown'
    all_epidemics_ds.loc[unid_idx, 'recurrent'] = False
    all_epidemics_ds.loc[all_epidemics_ds['disease'] == 'influenza', 'recurrent'] = False # Due to flu antigenic drift

    # We probably want to move this.
    with open("./data/clean/inverted_covid_severity.yaml", 'rb') as f:
        inverted_covid_severity_dict = yaml.safe_load(f)
        inverted_covid_severity = inverted_covid_severity_dict['ex_ante_severity']

    # Should calculate intensity earlier
    all_epidemics_ds.loc[all_epidemics_ds['disease'] == 'covid-19', 'severity'] = inverted_covid_severity
    all_epidemics_ds['intensity'] = all_epidemics_ds['severity'] / all_epidemics_ds['duration']

    """
    Now we begin filtering the dataset. See get_inclusion_path() for filtering steps.
    """
    # We do min year screening outside of inclusion path function so as not to include in the figure.
    all_modern_ds = all_epidemics_ds[all_epidemics_ds['year_start'] >= year_min].copy()

    # Get epidemics that survive all filtering stages
    all_modern_ds['final_inclusion_node'] = all_modern_ds.apply(lambda x: get_inclusion_path(x, thresh)[-1], axis=1)
    final_allrisk_ds = all_modern_ds[all_modern_ds['final_inclusion_node'] == 'Novel']
    final_airborne_ds = final_allrisk_ds[final_allrisk_ds['airborne']]
    
    # Create filtering plot
    fig, ax = plot_tidy_binary_sankey(all_modern_ds, thresh, year_min)
    
    id_string = f"{measure}_{str(thresh).replace('.', 'd')}_{year_min}"

    final_allrisk_ds.to_csv(f"./data/clean/novel_epidemics_all_{id_string}.csv", index=False)
    final_airborne_ds.to_csv(f"./data/clean/novel_epidemics_airborne_{id_string}.csv", index=False)
    fig.savefig(f"./output/ds_sankey_{id_string}.png", dpi=600)


if __name__ == "__main__":
    create_pandemic_datasets()