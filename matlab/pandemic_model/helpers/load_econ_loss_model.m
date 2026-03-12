function model = load_econ_loss_model(config_path)

    config = yaml.loadFile(config_path);
    if isfield(config, 'meta') && isfield(config.meta, 'input_variable')
        input_variable = string(config.meta.input_variable);
    else
        input_variable = "unknown";
    end
    model = EconLossModel(config.family, config.params.intercept, cell2mat(config.params.coefs(:)), input_variable);
end