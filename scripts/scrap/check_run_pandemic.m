function check_run_pandemic

    addpath(genpath("./pandemic_model"));
    addpath(genpath("./yaml"));
    job_config = clean_job_config(yaml.loadFile("./config/job_configs/job_template.yaml"));
    rng(job_config.seed);

    econ_loss_model = load_econ_loss_model(job_config.econ_loss_model_config);
    tau_A = job_config.tau_A;
    RD_benefit = 0;
    yr_start = 10;
    pandemic_natural_dur = 3;
    actual_dur = 2;
    rd_state = 1;
    severity = 100;
    cap_avail_m = 2.25e9;
    cap_avail_o = 2.25e9;

    [vax_fraction_cum_end, vax_benefits_PV, vax_benefits_nom, inp_marg_costs_m_PV, inp_marg_costs_o_PV, inp_marg_costs_m_nom, inp_marg_costs_o_nom] = ...
        run_pandemic(job_config, econ_loss_model, tau_A, RD_benefit, yr_start, pandemic_natural_dur, actual_dur, rd_state, severity, cap_avail_m, cap_avail_o);   


end