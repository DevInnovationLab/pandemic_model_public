function rental_fractions = get_rental_fractions(params, z_m, z_o)

    rental_fractions = (params.theta .* params.x_avail) ./ (z_m + z_o);
    rental_fractions(z_m == 0 & z_o == 0) = 0;
    rental_fractions(rental_fractions > 1) = 1;

    assert(all(isbetween(rental_fractions, 0, 1)))

end
   