function [yr_start_arr, intensity_arr, natural_dur_arr, is_false_arr, state_arr, has_RD_benefit_arr] = extract_columns_from_table(sim_scens_s)

        yr_start_arr       = sim_scens_s.yr_start;
        intensity_arr      = sim_scens_s.intensity;
        natural_dur_arr    = sim_scens_s.natural_dur;
        is_false_arr       = sim_scens_s.is_false;
        state_arr          = sim_scens_s.state;
        has_RD_benefit_arr = sim_scens_s.has_RD_benefit;
end