function load_project()
    % Opens the project from anywhere, assuming .prj is defined one folder up.
    project_path = fileparts(fileparts(mfilename('fullpath')));
    matlab.project.loadProject(project_path);
end