function model = load_econ_loss_model(config_path)
    % Load an economic loss model from a YAML config file.
    %
    % Reads the model family, regression coefficients, and intercept from YAML.
    % The optional meta.input_variable field names the predictor (default: "unknown").
    %
    % Args:
    %   config_path  Path to a YAML economic loss model config file.
    %
    % Returns:
    %   model  EconLossModel instance ready for .predict() calls.

    config = yaml.loadFile(config_path);
    if isfield(config, 'meta') && isfield(config.meta, 'input_variable')
        input_variable = string(config.meta.input_variable);
    else
        input_variable = "unknown";
    end
    model = EconLossModel(config.family, config.params.intercept, cell2mat(config.params.coefs(:)), input_variable);
end