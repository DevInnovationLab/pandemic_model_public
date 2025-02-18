function ts_with_zeros = agg_by_yr(series, dur, yr_start, periods)
	% aggregate by year and pad with zeros
	
	a = reshape(series, [12, dur]); % each col is for a year
    ts = sum(a, 1)'; % sum for each year

    if yr_start + dur - 1 > periods % cut off at yr 200
    	remain = periods - yr_start;
    	ts = ts(1:remain+1);
    	ts_with_zeros = [zeros(yr_start-1, 1); ts]; % pad front and back of time series with zero, to get to vector of length=periods
    else
		ts_with_zeros = [zeros(yr_start-1, 1); ts; zeros(periods - yr_start - dur + 1, 1)]; % pad front and back of time series with zero, to get to vector of length=periods
	end
	
end