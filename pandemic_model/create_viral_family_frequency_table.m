function viral_family_frequency_table = create_viral_family_frequency_table(num_families)
    % Create the first column with natural numbers from 1 to N
    families = (1:num_families)';
    probabilities = ones(num_families, 1) / num_families;
    
    % Combine the columns into an N by 2 matrix
    viral_family_frequency_table = [families, probabilities];
end