function write_exceedance_table(allrisk_csv_path, airborne_csv_path, outpath)
%GET_EXCEEDANCE_TABLE Create LaTeX table of recurrence rates by severity.
%   GET_EXCEEDANCE_TABLE() reads the selected mean annual recurrence rate
%   CSV files produced by sensitivity runs (and subsequently by
%   compare_exceedances.m) for the allrisk and airborne baseline vaccine
%   programs, and writes a LaTeX table summarising expected recurrence
%   rates by severity.
%
%   GET_EXCEEDANCE_TABLE(ALLRISK_CSV_PATH, AIRBORNE_CSV_PATH, OUTPATH)
%   instead reads the CSV files from the provided paths and writes the
%   LaTeX table to OUTPATH.
%
%   The LaTeX table uses only base LaTeX table environments and avoids
%   non-standard packages. Columns are:
%       - Severity (deaths / 10,000)
%       - Expected recurrence rate (years), split into:
%           * Novel viral: no mitigation, realized mitigation, vaccines always work
%           * Novel airborne viral: no mitigation, realized mitigation, vaccines always work
%
%   The function overwrites OUTPATH if it already exists.

    % Handle default paths if not provided. These point to the
    % compare_exceedances outputs for the allrisk and airborne
    % baseline vaccine sensitivity runs.
    if nargin < 1 || isempty(allrisk_csv_path)
        allrisk_csv_path = fullfile('output', 'sensitivity', ...
            'baseline_vaccine_program', ...
            'mean_annual_recurrence_rates_selected.csv');
    end
    if nargin < 2 || isempty(airborne_csv_path)
        airborne_csv_path = fullfile('output', 'sensitivity', ...
            'baseline_vaccine_program_airborne', ...
            'mean_annual_recurrence_rates_selected.csv');
    end
    if nargin < 3 || isempty(outpath)
        outpath = fullfile('output', 'exceedance_recurrence_table.tex');
    end

    % Load data from CSV files.
    allrisk_tbl = readtable(allrisk_csv_path);
    airborne_tbl = readtable(airborne_csv_path);

    % Expect columns: severity, mean_no_mitigation_recurrence, mean_realized_recurrence,
    % mean_always_work_recurrence. Rename to clarify scenario and response status.
    if width(allrisk_tbl) ~= 4 || width(airborne_tbl) ~= 4
        error(['Expected four columns in each CSV: severity, ', ...
               'mean_no_mitigation_recurrence, mean_realized_recurrence, ', ...
               'mean_always_work_recurrence.']);
    end

    allrisk_tbl.Properties.VariableNames = { ...
        'severity', ...
        'allrisk_no_mitigation', ...
        'allrisk_realized_mitigation', ...
        'allrisk_vaccines_always_work' ...
    };
    airborne_tbl.Properties.VariableNames = { ...
        'severity', ...
        'airborne_no_mitigation', ...
        'airborne_realized_mitigation', ...
        'airborne_vaccines_always_work' ...
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
    fprintf(fileID, ['\\caption{\\textbf{Expected recurrence rates for novel viral and novel airborne viral pandemics.} ', ...
                     'Entries show the expected recurrence interval in years at different severity levels.}\n']);
    fprintf(fileID, '\\footnotesize\n');
    fprintf(fileID, '\\begin{tabular}{ccccccc}\n');
    fprintf(fileID, '\\hline\n');

    % First header row: severity and overall label.
    fprintf(fileID, ['\\multicolumn{1}{c}{Severity} & \\multicolumn{6}{c}{Expected recurrence rate (years)} \\\\\n']);
    fprintf(fileID, '\\cline{2-7}\n');

    % Second header row: units for severity and scenario groupings.
    fprintf(fileID, ['\\multicolumn{1}{c}{(deaths / 10,000)} & \\multicolumn{3}{c}{Novel viral} & ', ...
                     '\\multicolumn{3}{c}{Novel airborne viral} \\\\\n']);

    % Third header row: response status (stacked using \\shortstack for compact labels).
    fprintf(fileID, ['& \\shortstack{No\\\\mitigation} & \\shortstack{Status quo\\\\response} & \\shortstack{Vaccines\\\\always work} & ', ...
                     '\\shortstack{No\\\\mitigation} & \\shortstack{Status quo\\\\response} & \\shortstack{Vaccines\\\\always work} \\\\\n']);
    fprintf(fileID, '\\hline\n');

    % Data rows.
    for i = 1:height(combined)
        % Base severity cell text.
        sev_val = combined.severity(i);
        sev_cell = char(severity_str(i));

        % Format recurrence values: always round to nearest whole year.
        allrisk_no_str = format_whole_years(combined.allrisk_no_mitigation(i));
        allrisk_realized_str = format_whole_years(combined.allrisk_realized_mitigation(i));
        allrisk_always_str = format_whole_years(combined.allrisk_vaccines_always_work(i));
        airborne_no_str = format_whole_years(combined.airborne_no_mitigation(i));
        airborne_realized_str = format_whole_years(combined.airborne_realized_mitigation(i));
        airborne_always_str = format_whole_years(combined.airborne_vaccines_always_work(i));

        % Add small-text labels and match spacing/alignment for selected severities.
        if abs(sev_val - 4.46) < 1e-6
            sev_cell = sprintf(['\\begin{tabular}[m]{@{}c@{}}%s\\\\[-0.4em] ', ...
                                '\\scriptsize ($\\underline{\\zeta}$)\\end{tabular}'], sev_cell);
        end
        if abs(sev_val - 9.17) < 1e-6
            sev_cell = sprintf(['\\begin{tabular}[m]{@{}c@{}}%s\\\\[-0.4em] ', ...
                                '\\scriptsize (realized COVID-19)\\end{tabular}'], sev_cell);
        elseif abs(sev_val - 171) < 1e-6
            sev_cell = sprintf(['\\begin{tabular}[m]{@{}c@{}}%s\\\\[-0.4em] ', ...
                                '\\scriptsize (1918--20 flu)\\end{tabular}'], sev_cell);
        end

        fprintf(fileID, '%s & %s & %s & %s & %s & %s & %s \\\\\n', ...
            sev_cell, ...
            allrisk_no_str, ...
            allrisk_realized_str, ...
            allrisk_always_str, ...
            airborne_no_str, ...
            airborne_realized_str, ...
            airborne_always_str);
    end

    fprintf(fileID, '\\hline\n');
    fprintf(fileID, '\\end{tabular}\n');
    fprintf(fileID, '\\label{tab:recurrence_rates}\n');
    fprintf(fileID, '\\end{table}\n');

    fprintf('Wrote recurrence rate table to %s\n', outpath);
end
