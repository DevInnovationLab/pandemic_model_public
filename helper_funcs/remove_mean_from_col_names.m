function tbl_out = remove_mean_from_col_names(tbl)

	%remove "mean_" from each col name (if col name doesn't have "mean_", then it stays the same)

	tbl_out = tbl;
	colnames = tbl.Properties.VariableNames;
	for i=1:length(colnames)
		colname = colnames{i};
		colname_new = erase(colname,"mean_");
		tbl_out.Properties.VariableNames{i} = colname_new;
	end

end