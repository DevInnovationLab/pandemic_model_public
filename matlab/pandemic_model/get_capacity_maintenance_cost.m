function maintenance_cost = get_capacity_maintenance_cost(capacity_value, params)

    maintenance_cost = params.delta .* capacity_value; % params delta is depreciation rate.

end