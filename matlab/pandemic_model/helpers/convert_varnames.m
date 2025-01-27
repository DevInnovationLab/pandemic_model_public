function nice_names = convert_varnames(varnames)
    % Check for nominal or present value indicators and modify names accordingly
    is_nominal = endsWith(varnames, "_n");
    is_present = endsWith(varnames, "_p");
    
    % Remove the _n and _p suffixes before dictionary lookup
    varnames_clean = varnames;
    varnames_clean(is_nominal) = extractBefore(varnames(is_nominal), "_n");
    varnames_clean(is_present) = extractBefore(varnames(is_present), "_p");

    converter = dictionary( ...
        ["adv_cap", "adv_RD", "benefits", "inp_cap", "inp_marg", "inp_RD", "inp_tail", ...
         "m_learning_losses", "m_deaths", "m_mortality_losses", "m_output_losses", "surveil", "u_deaths"], ...
        ["Advance capacity", "Advance R&D", "Benefits (present value)", "Response capacity", "Vaccination unit costs", ...
         "Response R&D", "Tailoring costs", "Learning losses (present value)", "Deaths", "Mortality losses", ...
         "Economic losses", "Enhanced surveillance costs", "Unmitigated deaths"] ...
    );

    % Add nominal/present value indicators to names after dictionary lookup
    nice_names = converter(varnames_clean);
    nice_names(is_nominal) = nice_names(is_nominal) + " (nominal value)";
    nice_names(is_present) = nice_names(is_present) + " (present value)";
end