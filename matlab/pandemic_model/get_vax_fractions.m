function vax_fractions_cum = get_vax_fractions(params, arg1, arg2)
    % Get vaccination and damage mitigation over time.
    % Can be called in two ways:
    %   get_vax_fractions(params, actual_dur_months) - For exogenous vaccination path
    %   get_vax_fractions(params, cap_m_arr, cap_o_arr) - For endogenous vaccination
    %
    % Args:
    %   params: Parameter struct containing model parameters
    %   arg1: Either actual_dur_months or cap_m_arr
    %   arg2: Optional cap_o_arr array
    
    if nargin == 2 && isfield(params, 'monthly_cum_vax')
        % Exogenous vaccination path case
        monthly_cum_vax = params.monthly_cum_vax;
        exog_vax_length = size(monthly_cum_vax, 1);
        actual_dur_months = arg1;
        
        if exog_vax_length >= actual_dur_months
            vax_fractions_cum = exog_vax_length(1:actual_dur_months);
        else
            vax_fractions_cum =  ...
                [monthly_cum_vax; monthly_cum_vax(end) .* ones(actual_dur_months - exog_vax_length, 1)];
        end
    elseif nargin == 3
        % Endogenous vaccination case
        cap_m_arr = arg1;
        cap_o_arr = arg2;
        
        vax_fractions_per_period = (cap_m_arr + cap_o_arr) / params.P0;
        vax_fractions_cum = cumsum(vax_fractions_per_period);
        vax_fractions_cum(vax_fractions_cum > 1) = 1; % Can't vaccinate more than population

        if params.conservative == 1 % Use beginning of period vaccinations (rather than end of period)
            vax_fractions_cum = [0; vax_fractions_cum(1:end-1)];
        end
    else
        error('Invalid number of arguments or params configuration');
    end
end