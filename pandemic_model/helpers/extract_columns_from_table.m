function [yr_start_arr, severity_arr, natural_dur_arr, actual_dur_arr, is_false_arr, rd_state_arr, has_RD_benefit_arr, prep_start_month_arr, yr_end_arr] ...
        = extract_columns_from_table(sim_scens_s)

        yr_start_arr = sim_scens_s.yr_start;
        severity_arr = sim_scens_s.severity;
        natural_dur_arr = sim_scens_s.natural_dur;
        actual_dur_arr = sim_scens_s.actual_dur;
        is_false_arr = sim_scens_s.is_false;
        rd_state_arr = sim_scens_s.rd_state;
        has_RD_benefit_arr = sim_scens_s.has_RD_benefit;
        prep_start_month_arr = sim_scens_s.prep_start_month;
        yr_end_arr = sim_scens_s.yr_end;
end