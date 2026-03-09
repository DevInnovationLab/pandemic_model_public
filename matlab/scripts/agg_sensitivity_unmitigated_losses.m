function agg_sensitivity_unmitigated_losses(sensitivity_dir)
    % Aggregate unmitigated loss outputs into processed/ for use by build_sensitivity_loss_tables.
    %
    % For baseline and each param/value, if value_dir/unmitigated_losses.mat exists,
    % loads it, computes annualized and total loss vectors (same as get_unmitigated_losses_for_dir),
    % and saves to sensitivity_dir/processed/baseline_unmitigated_losses_summary.mat and
    % processed/<param>_<value>_unmitigated_losses_summary.mat. Then build_sensitivity_loss_tables
    % and write_unmitigated_loss_figures can load from processed/.
    %
    % Args:
    %   sensitivity_dir (char or string): Path to sensitivity run directory.

    sensitivity_dir = char(sensitivity_dir);
    processed_dir = fullfile(sensitivity_dir, 'processed');
    create_folders_recursively(processed_dir);

    % Baseline
    baseline_dir = fullfile(sensitivity_dir, 'baseline');
    mat_path = fullfile(baseline_dir, 'unmitigated_losses.mat');
    if isfile(mat_path)
        job_config = yaml.loadFile(fullfile(baseline_dir, 'job_config.yaml'));
        r = job_config.r;
        periods = job_config.sim_periods;
        [annual_deaths, mortality_losses, economic_losses, learning_losses, total_losses] = ...
            load_unmitigated_vectors(mat_path, r, periods);
        out_path = fullfile(processed_dir, 'baseline_unmitigated_losses_summary.mat');
        save(out_path, 'annual_deaths', 'mortality_losses', 'economic_losses', ...
            'learning_losses', 'total_losses', 'job_config');
        fprintf('Processed baseline unmitigated losses -> %s\n', out_path);
    end

    % Param/value dirs (same layout as agg_sensitivity_benefits)
    param_dirs = dir(fullfile(sensitivity_dir, '*'));
    param_dirs = param_dirs([param_dirs.isdir]);
    param_dirs = param_dirs(~ismember({param_dirs.name}, {'.', '..', 'processed', 'baseline', 'figures'}));
    for i = 1:length(param_dirs)
        param_name = param_dirs(i).name;
        param_dir = fullfile(sensitivity_dir, param_name);
        value_dirs = dir(fullfile(param_dir, 'value_*'));
        value_dirs = value_dirs([value_dirs.isdir]);
        for j = 1:length(value_dirs)
            value_name = value_dirs(j).name;
            value_dir = fullfile(param_dir, value_name);
            mat_path = fullfile(value_dir, 'unmitigated_losses.mat');
            if ~isfile(mat_path)
                continue;
            end
            job_config = yaml.loadFile(fullfile(value_dir, 'job_config.yaml'));
            r = job_config.r;
            periods = job_config.sim_periods;
            [annual_deaths, mortality_losses, economic_losses, learning_losses, total_losses] = ...
                load_unmitigated_vectors(mat_path, r, periods);
            stem = sprintf('%s_%s_unmitigated_losses_summary', param_name, value_name);
            out_path = fullfile(processed_dir, [stem '.mat']);
            save(out_path, 'annual_deaths', 'mortality_losses', 'economic_losses', ...
                'learning_losses', 'total_losses', 'param_name', 'value_name', 'job_config');
            fprintf('Processed %s/%s unmitigated losses -> %s\n', param_name, value_name, out_path);
        end
    end
    fprintf('Unmitigated losses aggregated to %s\n', processed_dir);
end

function [annual_deaths, mortality_losses, economic_losses, learning_losses, total_losses] = ...
    load_unmitigated_vectors(mat_path, r, periods)
    annualization_factor = (r * (1 + r)^periods) / ((1 + r)^periods - 1);
    S = load(mat_path, 'deaths', 'mortality_losses', 'output_losses', 'learning_losses', 'total_losses');
    annual_deaths = sum(S.deaths, 2) ./ periods;
    mortality_losses = sum(S.mortality_losses, 2) .* annualization_factor;
    economic_losses = sum(S.output_losses, 2) .* annualization_factor;
    learning_losses = sum(S.learning_losses, 2) .* annualization_factor;
    total_losses = sum(S.total_losses, 2) .* annualization_factor;
end
