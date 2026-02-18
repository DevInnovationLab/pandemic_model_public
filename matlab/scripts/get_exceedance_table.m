function get_exceedance_table(allrisk_csv_path, airborne_csv_path, outpath)
%GET_EXCEEDANCE_TABLE Create LaTeX table of recurrence rates by severity.
%   GET_EXCEEDANCE_TABLE() reads the selected mean annual recurrence rate
%   CSV files for the allrisk base and airborne base scenarios from the
%   default locations under the repository output directory, and writes a
%   LaTeX table summarising expected recurrence rates by severity.
%
%   GET_EXCEEDANCE_TABLE(ALLRISK_CSV_PATH, AIRBORNE_CSV_PATH, OUTPATH)
%   instead reads the CSV files from the provided paths and writes the
%   LaTeX table to OUTPATH.
%
%   The LaTeX table uses only base LaTeX table environments and avoids
%   non-standard packages. Columns are:
%       - Severity (deaths / 10,000)
%       - Expected recurrence rate (years), split into:
%           * Novel viral: with and without vaccine response
%           * Novel airborne viral: with and without vaccine response
%
%   The function overwrites OUTPATH if it already exists.

    % Handle default paths if not provided.
    if nargin < 1 || isempty(allrisk_csv_path)
        allrisk_csv_path = fullfile('output', 'jobs', 'allrisk_base', ...
            'mean_annual_recurrence_rates_selected.csv');
    end
    if nargin < 2 || isempty(airborne_csv_path)
        airborne_csv_path = fullfile('output', 'jobs', 'airborne_base', ...
            'mean_annual_recurrence_rates_selected.csv');
    end
    if nargin < 3 || isempty(outpath)
        outpath = fullfile('output', 'exceedance_recurrence_table.tex');
    end

    % Load data from CSV files.
    allrisk_tbl = readtable(allrisk_csv_path);
    airborne_tbl = readtable(airborne_csv_path);

    % Expect columns: severity, mean_ante_recurrence, mean_post_recurrence.
    % Rename to clarify scenario and response status.
    if width(allrisk_tbl) ~= 3 || width(airborne_tbl) ~= 3
        error('Expected three columns in each CSV: severity, mean_ante_recurrence, mean_post_recurrence.');
    end

    allrisk_tbl.Properties.VariableNames = { ...
        'severity', ...
        'allrisk_without_vaccine', ...
        'allrisk_with_vaccine' ...
    };
    airborne_tbl.Properties.VariableNames = { ...
        'severity', ...
        'airborne_without_vaccine', ...
        'airborne_with_vaccine' ...
    };

    % Join on severity to align the scenarios.
    combined = innerjoin(allrisk_tbl, airborne_tbl, 'Keys', 'severity');
    combined = sortrows(combined, 'severity');

    % Helper to format severities nicely for LaTeX.
    function s = format_years(x)
        if isnan(x)
            s = "";
        elseif abs(x - round(x)) < 1e-6
            % Display whole-number severities (e.g. 1, 10, 50, 177) with no decimals.
            s = sprintf('%.0f', round(x));
        elseif x >= 10
            s = sprintf('%.1f', x);
        else
            s = sprintf('%.2f', x);
        end
        s = string(s);
    end

    % Helper to format values rounded to the nearest whole number.
    function s = format_whole_years(x)
        if isnan(x)
            s = "";
        else
            s = sprintf('%.0f', round(x));
        end
        s = string(s);
    end

    severity_str = arrayfun(@(x) format_years(x), combined.severity);

    % Open LaTeX file for writing.
    out_dir = fileparts(outpath);
    if ~isempty(out_dir) && ~isfolder(out_dir)
        mkdir(out_dir);
    end
    fileID = fopen(outpath, 'w');
    if fileID == -1
        error('Could not open output file for writing: %s', outpath);
    end

    cleaner = onCleanup(@() fclose(fileID));

    % Write LaTeX table using only base environments.
    fprintf(fileID, '\\begin{table}[htbp]\n');
    fprintf(fileID, '\\centering\n');
    fprintf(fileID, ['\\caption{\\textbf{Expected recurrence rates for novel viral and novel airborne viral pandemics with intensity $\\underline{\\zeta} \\geq 4.46$ deaths per 10,000} ', ...
                     'Entries show the expected recurrence interval in years at different severity levels.}\n']);
    fprintf(fileID, '\\footnotesize\n');
    fprintf(fileID, '\\begin{tabular}{ccccc}\n');
    fprintf(fileID, '\\hline\n');

    % First header row: severity and overall label.
    fprintf(fileID, ['\\multicolumn{1}{c}{Severity} & \\multicolumn{4}{c}{Expected recurrence rate (years)} \\\\\n']);
    fprintf(fileID, '\\cline{2-5}\n');

    % Second header row: units for severity and scenario groupings.
    fprintf(fileID, ['\\multicolumn{1}{c}{(deaths / 10,000)} & \\multicolumn{2}{c}{Novel viral} & ', ...
                     '\\multicolumn{2}{c}{Novel airborne viral} \\\\\n']);

    % Third header row: response status.
    fprintf(fileID, ['& No vaccine response & With vaccine response & ', ...
                     'No vaccine response & With vaccine response \\\\\n']);
    fprintf(fileID, '\\hline\n');

    % Data rows.
    for i = 1:height(combined)
        % Base severity cell text.
        sev_val = combined.severity(i);
        sev_cell = char(severity_str(i));

        % Format recurrence values: always round to nearest whole year.
        allrisk_without_str = format_whole_years(combined.allrisk_without_vaccine(i));
        allrisk_with_str = format_whole_years(combined.allrisk_with_vaccine(i));
        airborne_without_str = format_whole_years(combined.airborne_without_vaccine(i));
        airborne_with_str = format_whole_years(combined.airborne_with_vaccine(i));

        % Add small-text labels and match spacing/alignment for selected severities.
        if abs(sev_val - 4.46) < 1e-6
            sev_cell = sprintf(['\\begin{tabular}[m]{@{}c@{}}%s\\\\[-0.4em] ', ...
                                '\\scriptsize ($\\underline{\\zeta}$)\\end{tabular}'], sev_cell);
        end
        if abs(sev_val - 9.17) < 1e-6
            sev_cell = sprintf(['\\begin{tabular}[m]{@{}c@{}}%s\\\\[-0.4em] ', ...
                                '\\scriptsize (realized COVID-19)\\end{tabular}'], sev_cell);
        elseif abs(sev_val - 177) < 1e-6
            sev_cell = sprintf(['\\begin{tabular}[m]{@{}c@{}}%s\\\\[-0.4em] ', ...
                                '\\scriptsize (1918--20 flu)\\end{tabular}'], sev_cell);
        end

        fprintf(fileID, '%s & %s & %s & %s & %s \\\\\n', ...
            sev_cell, ...
            allrisk_without_str, ...
            allrisk_with_str, ...
            airborne_without_str, ...
            airborne_with_str);
    end

    fprintf(fileID, '\\hline\n');
    fprintf(fileID, '\\end{tabular}\n');
    fprintf(fileID, '\\label{tab:recurrence_rates}\n');
    fprintf(fileID, '\\end{table}\n');

    fprintf('Wrote recurrence rate table to %s\n', outpath);
end
