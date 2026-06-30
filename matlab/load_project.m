function load_project()
    % Load the MATLAB project and add all source directories to the path.
    %
    % Call this before any other project script:
    %   run('./matlab/load_project')
    %
    % The .prj file is intentionally minimal. All path management is done
    % here so the project can be used from any working directory.

    project_path = fileparts(fileparts(mfilename('fullpath')));
    matlab_path = fullfile(project_path, 'matlab');

    % Core simulation engine and helpers
    addpath(fullfile(matlab_path, 'pandemic_model'));
    addpath(fullfile(matlab_path, 'pandemic_model', 'helpers'));
    addpath(fullfile(matlab_path, 'pandemic_model', 'arrival_distributions'));
    addpath(fullfile(matlab_path, 'pandemic_model', 'duration_distributions'));
    addpath(fullfile(matlab_path, 'pandemic_model', 'econ_loss'));

    % Scripts: workflow, analysis, and figures
    addpath(fullfile(matlab_path, 'scripts', 'workflow'));
    addpath(fullfile(matlab_path, 'scripts', 'analysis'));
    addpath(fullfile(matlab_path, 'scripts', 'figures'));

    % External YAML library
    addpath(fullfile(matlab_path, 'yaml'));

    % Tests
    addpath(fullfile(matlab_path, 'tests'));

    % Load the project file for IDE integration
    matlab.project.loadProject(project_path);
end