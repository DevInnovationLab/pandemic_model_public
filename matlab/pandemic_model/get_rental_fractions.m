function rental_fractions = get_rental_fractions(rentable_cap, max_rental)

    rental_fractions = max_rental ./ rentable_cap;
    rental_fractions(rentable_cap == 0) = 0;
    rental_fractions(rental_fractions > 1) = 1;

    assert(all(isbetween(rental_fractions, 0, 1), "all"))
end
   