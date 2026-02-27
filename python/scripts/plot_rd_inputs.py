
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns


if __name__ == "__main__":

    # Load pathogen data with indicator for whether pathogens truly have prototype vaccines
    pathogen_data = pd.read_csv("../../data/clean/pathogen_arrival_all.csv")
    pathogen_data['has_prototype'] = pathogen_data['has_prototype'].astype(bool)

    # Load vaccine timeline predictions
    rd_timelines = pd.read_csv("../../output/rd_timelines/pathogen_model_preds.csv")
    rd_timelines['has_prototype'] = rd_timelines['has_prototype'].map({'has_prototype': True, 'no_prototype': False})

    # Merge timeline with pathogen indicators
    rd_timelines = rd_timelines.merge(
        pathogen_data[['pathogen', 'has_prototype']],
        on=['pathogen', 'has_prototype'],
        how='left',
        indicator=True
    )
    rd_timelines.rename(columns={'has_prototype': 'has_prototype_true'}, inplace=True)

    # For each pathogen, determine which points are the "default" (i.e., matches true prototype status)
    # and which are the "with prototype R&D" (i.e., estimate for prototype for those that don't have one)
    # We'll label the default as "Baseline" and the other as "With prototype R&D"
    # Only path that do not already have a prototype will have both points

    # Get the true prototype status for each pathogen
    patthogen_prototype_map = pathogen_data.set_index('pathogen')['has_prototype'].to_dict()

    def label_point(row):
        if row['has_prototype_true'] == patthogen_prototype_map[row['pathogen']]:
            return "Baseline"
        elif not patthogen_prototype_map[row['pathogen']] and row['has_prototype_true']:
            return "With prototype R&D"
        else:
            return None

    rd_timelines['label'] = rd_timelines.apply(label_point, axis=1)
    plot_timelines = rd_timelines[rd_timelines['label'].notnull()].copy()

    # Capitalize pathogens and sort alphabetically for plotting
    plot_timelines['pathogen_cap'] = plot_timelines['pathogen'].str.capitalize()
    pathogens = sorted(plot_timelines['pathogen_cap'].unique())

    # Set up the plot
    plt.figure(figsize=(10, 6))
    palette = {"Baseline": "#1f77b4", "With prototype R&D": "#ff7f0e"}

    for label, marker in zip(["Baseline", "With prototype R&D"], ["o", "D"]):
        subset = plot_timelines[plot_timelines['label'] == label]
        # Map pathogen to capitalized version for plotting
        plt.scatter(
            subset['pathogen_cap'],
            subset['preds'],
            marker=marker,
            label=label,
            color=palette[label]
        )

    plt.xticks(ticks=np.arange(len(pathogens)), labels=pathogens, rotation=45, rotation_mode='anchor', ha='right')
    plt.ylabel("Predicted years to vaccine approval")
    plt.ylim([0, np.ceil(plot_timelines['preds'].max())])
    plt.xlabel("Pathogen")
    plt.title("Predicted vaccine development timelines by pathogen")
    plt.legend(loc='lower right', frameon=False)
    plt.tight_layout()
    plt.gca().spines[['top', 'right']].set_visible(False)
    plt.savefig("./output/rd_timelines/timeline_preds.png", dpi=600)

    # Now let's do the same for the PTRS