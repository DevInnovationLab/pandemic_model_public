function model = load_econ_loss_model(config_path)

    config = yaml.loadFile(config_path);
    model = EconLossModel(config.family, config.params.intercept, cell2mat(config.params.coefs(:)));
end