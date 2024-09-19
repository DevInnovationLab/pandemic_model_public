// Set project directory
if "`c(username)'" == "Sebastian Quaade" {
    global project_dir "C:\Users\Sebastian Quaade\Documents\GitHub\pandemic_model"
} 

// Set project subdirectories
global scripts_dir "`project_dir'/scripts"
global output_dir "`project_dir'/output"
global config_dir "`project_dir'/config"
global data_dir "`project_dir'/data"
