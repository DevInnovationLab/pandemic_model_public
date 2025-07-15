
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns


if __name__ == "__main__":

    # Load viral family data with indicator for whether viral families truly have prototype vaccines
    vf_data = pd.read_csv("../../data/clean/vf_data_arrival_all.csv")
    vf_data['has_prototype'] = vf_data['has_prototype'].astype(bool)

    # Load vaccine timeline predictions
    rd_timelines = pd.read_csv("../../output/rd_timelines/vf_model_preds.csv")
    rd_timelines['has_prototype'] = rd_timelines['has_prototype'].map({'has_prototype': True, 'no_prototype': False})

    # Merge timeline with viral family indicators
    rd_timelines = rd_timelines.merge(
        vf_data[['viral_family', 'has_prototype']],
        on=['viral_family', 'has_prototype'],
        how='left',
        indicator=True
    )
    rd_timelines.rename(columns={'has_prototype': 'has_prototype_true'}, inplace=True)

    # For each viral family, determine which points are the "default" (i.e., matches true prototype status)
    # and which are the "with prototype R&D" (i.e., estimate for prototype for those that don't have one)
    # We'll label the default as "Baseline" and the other as "With prototype R&D"
    # Only viral families that do not already have a prototype will have both points

    # Get the true prototype status for each viral family
    vf_prototype_map = vf_data.set_index('viral_family')['has_prototype'].to_dict()

    def label_point(row):
        if row['has_prototype_true'] == vf_prototype_map[row['viral_family']]:
            return "Baseline"
        elif not vf_prototype_map[row['viral_family']] and row['has_prototype_true']:
            return "With prototype R&D"
        else:
            return None

    rd_timelines['label'] = rd_timelines.apply(label_point, axis=1)
    plot_timelines = rd_timelines[rd_timelines['label'].notnull()].copy()

    # Capitalize viral families and sort alphabetically for plotting
    plot_timelines['viral_family_cap'] = plot_timelines['viral_family'].str.capitalize()
    viral_families = sorted(plot_timelines['viral_family_cap'].unique())

    # Set up the plot
    plt.figure(figsize=(10, 6))
    palette = {"Baseline": "#1f77b4", "With prototype R&D": "#ff7f0e"}

    for label, marker in zip(["Baseline", "With prototype R&D"], ["o", "D"]):
        subset = plot_timelines[plot_timelines['label'] == label]
        # Map viral_family to capitalized version for plotting
        plt.scatter(
            subset['viral_family_cap'],
            subset['preds'],
            marker=marker,
            label=label,
            color=palette[label]
        )

    plt.xticks(ticks=np.arange(len(viral_families)), labels=viral_families, rotation=45, rotation_mode='anchor', ha='right')
    plt.ylabel("Predicted years to vaccine approval")
    plt.ylim([0, np.ceil(plot_timelines['preds'].max())])
    plt.xlabel("Viral family")
    plt.title("Predicted vaccine development timelines by viral family")
    plt.legend(loc='lower right', frameon=False)
    plt.tight_layout()
    plt.gca().spines[['top', 'right']].set_visible(False)
    plt.savefig("./output/rd_timelines/timeline_preds.png")

    # Now let's do the same for the PTRS

    # Now let's do