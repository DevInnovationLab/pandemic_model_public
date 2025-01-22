
pause off

set more off
local scenarios `" "100dm" "moderate" "cap_heavy" "rd_heavy" "'
local root "C:/Users/Sebastian Quaade/Documents/GitHub/pandemic_model/output/CEPI_phase_2_exogenous_rental"
local cleandir "`root'/clean"
local figuredir "`root'/figures"
local cum_bene_ymin 0 // Y axis range min for cumulative benefits
local cum_bene_ymax 1500 // Y axis range max for cumulative benefits
local n_flow_costs_ymin -.5
local n_flow_costs_ymax 5
local p_flow_costs_ymin 0 // Y axis range min for flow costs
local p_flow_costs_ymax 5000 // Y axis range max for flow costs
local stats mean lower upper


local is_diff = 1 // if to run for outright or diff relative to status quo

if `is_diff' == 1 {
	local rel_moniker " relative to business as usual"
}
else {
	local rel_moniker ""
}

local c_bene "purple"
local c_inp_all "midblue"
local c_adv_all "green"

local c_adv_RD "green"
local c_surveil "purple"
local c_adv_cap "cranberry"

local c_inp_resp "gold"
local c_inp_unit "gray"


foreach scenario of local scenarios {
	
	*** NOTE THAT DEFAULT UNIT IS MN
	if `is_diff' == 1 {
		use "`cleandir'/`scenario'_agg_diff.dta", clear
		local outsuffix "_diff"	
	}
	else {
		use "`cleandir'/`scenario'_agg.dta", clear
		local outsuffix ""
	}

	sort yr
	foreach var of varlist *_cum {
		replace `var' = `var' / 1000 // all cum are in bn, by default
	}

	// Output summary stats for technical document
	foreach stat in mean lower upper {
		list `stat'_benefits_p_cum if yr == 30 | yr == 200
		list `stat'_net_benefits_p_cum if yr == 30 | yr == 200
		list `stat'_total_costs_p_cum if yr == 30 | yr == 200
		list `stat'_inp_cap_p_cum if yr == 30 | yr == 200
		list `stat'_inp_costs_all_p_cum if yr == 30 | yr == 200
	}
	 
	foreach type in "n" "p" { // benefits and the two aggregated cost categories are in bn
		foreach stat of local stats {
			gen `stat'_benefits_bn_`type' = `stat'_benefits_`type'/1000
			gen `stat'_adv_costs_all_bn_`type' = `stat'_adv_costs_all_`type'/1000
			gen `stat'_inp_costs_all_bn_`type' = `stat'_inp_costs_all_`type'/1000
		}
	}

	foreach type in "n" { 
		foreach stat of local stats {
			*** nominal benfits and the two aggregated costs are in tn for cumulative
			gen `stat'_benefits_tn_`type'_cum = `stat'_benefits_`type'_cum /1000
			gen `stat'_adv_costs_all_tn_`type'_cum = `stat'_adv_costs_all_`type'_cum/1000
			gen `stat'_inp_costs_all_tn_`type'_cum = `stat'_inp_costs_all_`type'_cum/1000

			*** nominal costs in bn
			gen `stat'_adv_RD_bn_`type' = `stat'_adv_RD_`type' / 1000
			gen `stat'_surveil_bn_`type' = `stat'_surveil_`type' / 1000
			gen `stat'_adv_cap_bn_`type' = `stat'_adv_cap_`type' / 1000
			gen `stat'_inp_RD_bn_`type' = `stat'_inp_RD_`type' / 1000
			gen `stat'_inp_cap_bn_`type' = `stat'_inp_cap_`type' / 1000
			gen `stat'_inp_costs_invest_bn_`type' = `stat'_inp_costs_invest_`type' / 1000
			gen `stat'_inp_costs_unit_bn_`type' = `stat'_inp_costs_unit_`type' / 1000
		}
	}
	

	*** TIME SERIES -- COST BREAKDOWN
	foreach type in "n" "p" {

		if "`type'" == "n" {
			local ytitle_txt = "Costs`rel_moniker' ({c $|}bn, nom)"
			local unit_modifier = "bn_"
			local ymin `n_flow_costs_ymin'
			local ymax `n_flow_costs_ymax'
		}
		else {
			local ytitle_txt = "Costs`rel_moniker' ({c $|}mn, pv)"
			local unit_modifier = ""
			local ymin `p_flow_costs_ymin'
			local ymax `p_flow_costs_ymax'
		}
	
		// scatter inp_costs_all_`type' yr, msymbol(X) mcolor("`c_inp_all'") msize(medlarge) ||
		qui twoway line mean_adv_RD_`unit_modifier'`type' yr, lcolor("`c_adv_RD'") lpattern(solid) || ///
			rarea upper_adv_RD_`unit_modifier'`type' lower_adv_RD_`unit_modifier'`type' yr, color("`c_adv_RD'%20")  || ///
			line mean_adv_cap_`unit_modifier'`type' yr, lcolor("`c_adv_cap'") lpattern(solid) || ///
			rarea upper_adv_cap_`unit_modifier'`type' lower_adv_cap_`unit_modifier'`type' yr, color("`c_adv_cap'%20")  || ///
			line mean_surveil_`unit_modifier'`type' yr, lcolor("`c_surveil'") lpattern(solid) || ///
			rarea upper_surveil_`unit_modifier'`type' lower_surveil_`unit_modifier'`type' yr, color("`c_surveil'%20")  || ///
			line mean_inp_costs_invest_`unit_modifier'`type' yr, lcolor("`c_inp_resp'") lpattern(longdash) || ///
			rarea upper_inp_costs_invest_`unit_modifier'`type' lower_inp_costs_invest_`unit_modifier'`type' yr, color("`c_inp_resp'%20")  || ///
			line mean_inp_costs_unit_`unit_modifier'`type' yr, lcolor("`c_inp_unit'") lpattern(longdash) || ///
			rarea upper_inp_costs_unit_`unit_modifier'`type' lower_inp_costs_unit_`unit_modifier'`type' yr, color("`c_inp_unit'%20")  || ///
			line mean_inp_costs_all_`unit_modifier'`type' yr, lcolor("`c_inp_all'") lpattern(longdash) || ///
			rarea upper_inp_costs_all_`unit_modifier'`type' lower_inp_costs_all_`unit_modifier'`type' yr, color("`c_inp_all'%20") ||, ///
			ylabel(0(1)5, grid gstyle(major) glwidth(thin)) ///
			yscale(range(`ymin' `ymax') titlegap(*1)) ///
			yscale( titlegap(*1)) ///
			xscale(range(0 200) titlegap(*1)) ///
			xlabel(0(20)200) ///
			ytitle(`ytitle_txt', size(medsmall) margin(medium)) ///
			xtitle("Year", size(medium) margin(medium)) ///
			graphregion(color(white))  ///
			legend(order(1 "Advance R&D" ///
						 3 "Advance capacity" ///
						 5 "Enhanced surveillance" ///
						 7 "Response investments" ///
						 9 "Response unit costs" ///
						 11 "Tot. response costs") ///
						 position(12) cols(3) region(lstyle(none)) size(small))
		
		local outname = "`figuredir'/`scenario'_costs_`type'"
		graph export "`outname'`outsuffix'.png", replace 
		
	}

	*** TIME SERIES -- COST vs BENEFIT
	foreach type in "n" "p" {

		if "`type'" == "n" {
			local ytitle_txt = `" "Costs and benefits" "`rel_moniker' ({c $|}bn, nom)" "'
		}
		else {
			local ytitle_txt = `" "Costs and benefits" "`rel_moniker' ({c $|}bn, pv)" "'
		}
		
/* 				capture confirm var surveil_bn_`type'
		if _rc {
			gen surveil_bn_`type' = surveil_`type' / 1000	
		} */

		qui twoway line mean_benefits_bn_`type' yr, lcolor("`c_bene'") lpattern(solid) || ///
			line mean_adv_costs_all_bn_`type' yr, lcolor("`c_adv_all'") lpattern(solid) || ///
			line mean_inp_costs_all_bn_`type' yr, lcolor("`c_inp_all'") lpattern(longdash) || ///
			rarea upper_benefits_bn_`type' lower_benefits_bn_`type' yr, color("`c_bene'%20") || ///
			rarea upper_adv_costs_all_bn_`type' lower_adv_costs_all_bn_`type' yr, color("`c_adv_all'%20") || ///
			rarea upper_inp_costs_all_bn_`type' lower_inp_costs_all_bn_`type' yr, color("`c_inp_all'%20") ||, ///
			ylabel(, grid gstyle(major) glwidth(thin)) ///
			yscale( titlegap(*1)) ///
			xscale(range(0 200) titlegap(*1)) ///
			xlabel(0(20)200) ///
			ytitle(`ytitle_txt', size(medsmall) margin(medium)) ///
			xtitle("Year", size(medium) margin(medium)) ///
			graphregion(color(white)) ///
			legend(order(1 "Benefits" ///
					     2 "Advance costs" ///
					     3 "Response costs") ///
					position(12) cols(3) region(lstyle(none)) size(small))

		local outname = "`figuredir'/`scenario'_bene_costs_`type'"
		graph export "`outname'`outsuffix'.png", replace 
	}

	*** CUM TIME SERIES -- COST BREAKDOWN
	foreach type in "n" "p" {

		if "`type'" == "n" {
			local ytitle_txt = "Cum. costs`rel_moniker' ({c $|}bn, nom)"
		}
		else {
			local ytitle_txt = "Cum. costs`rel_moniker' ({c $|}bn, pv)"
		}

		// scatter inp_costs_all_`type'_cum yr, msymbol(X) mcolor("`c_inp_all'") msize(medium) ///
		qui twoway line mean_adv_RD_`type'_cum yr, lcolor("`c_adv_RD'") lpattern(solid) ///
		|| line mean_adv_cap_`type'_cum yr, lcolor("`c_adv_cap'") lpattern(solid) ///
		|| line mean_surveil_`type'_cum yr, lcolor("`c_surveil'") lpattern(solid) ///
		|| line mean_inp_costs_invest_`type'_cum yr, lcolor("`c_inp_resp'") lpattern(longdash) ///
		|| line mean_inp_costs_unit_`type'_cum yr, lcolor("`c_inp_unit'") lpattern(longdash) ///
		|| line mean_inp_costs_all_`type'_cum yr, lcolor("`c_inp_all'") lpattern(longdash) ///
		|| rarea upper_adv_RD_`type'_cum lower_adv_RD_`type'_cum yr, color("`c_adv_RD'%20") ///
		|| rarea upper_adv_cap_`type'_cum lower_adv_cap_`type'_cum yr, color("`c_adv_cap'%20") ///
		|| rarea upper_surveil_`type'_cum lower_surveil_`type'_cum yr, color("`c_surveil'%20") ///
		|| rarea upper_inp_costs_invest_`type'_cum lower_inp_costs_invest_`type'_cum yr, color("`c_inp_resp'%20") ///
		|| rarea upper_inp_costs_unit_`type'_cum lower_inp_costs_unit_`type'_cum yr, color("`c_inp_unit'%20") ///
		|| rarea upper_inp_costs_all_`type'_cum lower_inp_costs_all_`type'_cum yr, color("`c_inp_all'%20") ///
		, ylabel(, grid gstyle(major) glwidth(thin)) ///
			yscale( titlegap(*1)) ///
			xscale(range(0 200) titlegap(*1)) ///
			xlabel(0(20)200, labsize(small)) ///
			ytitle("`ytitle_txt'", size(medsmall) margin(medium)) ///
			xtitle("Year", size(medium) margin(medium)) ///
			graphregion(color(white)) ///
			legend(order(1 "Advance R&D" ///
					     2 "Advance capacity" ///
					     3 "Enhanced surveillance" ///
					     4 "Response investments" ///
					     5 "Response unit costs" ///
					     6 "Tot. response costs") ///
					position(12) cols(3) size(small) region(lstyle(none)))

		local outname = "`figuredir'/`scenario'_costs_`type'_cum"
		graph export "`outname'`outsuffix'.png", replace 
	}

	*** CUM TIME SERIES -- COST vs BENEFIT
	
	// Identify the year where var1 becomes greater than var2
	gen diff = mean_benefits_n_cum - mean_adv_costs_all_n_cum - mean_inp_costs_all_n_cum
	gen crossover_year = yr if diff > 0 & diff[_n-1] <= 0
	levelsof crossover_year if !missing(crossover_year), local(crossover_year)
	local line_label_year = `crossover_year' + 1
	
	foreach type in "n" "p" {

		if "`type'" == "n" {
			local ytitle_txt = `" "Cum. costs and benefits" "`rel_moniker' ({c $|}tn, nom)" "'
			local unit_modifier = "tn_"
		}
		else {
			local ytitle_txt = `" "Cum. costs and benefits" "`rel_moniker' ({c $|}bn, pv)" "'
			local unit_modifier = ""
		}
		
		qui twoway line mean_benefits_`unit_modifier'`type'_cum yr, lcolor("`c_bene'") lpattern(solid) || ///
			line mean_adv_costs_all_`unit_modifier'`type'_cum yr, lcolor("`c_adv_all'") lpattern(solid) || ///
			line mean_inp_costs_all_`unit_modifier'`type'_cum yr, lcolor("`c_inp_all'") lpattern(longdash) || ///
			rarea upper_benefits_`unit_modifier'`type'_cum lower_benefits_`unit_modifier'`type'_cum yr, color("`c_bene'%20") || ///
			rarea upper_adv_costs_all_`unit_modifier'`type'_cum lower_adv_costs_all_`unit_modifier'`type'_cum yr, color("`c_adv_all'%20") || ///
			rarea upper_inp_costs_all_`unit_modifier'`type'_cum lower_inp_costs_all_`unit_modifier'`type'_cum yr, color("`c_inp_all'%20") ||, ///
			xline(`crossover_year', lcolor(black) lwidth(medthin) lpattern(dash)) ///
			text(800 `line_label_year' "Year `crossover_year'", place(e) size(small)) ///
			ylabel(`cum_bene_ymin'(500)`cum_bene_ymax', grid gstyle(major) glwidth(thin)) ///
			yscale(range(`cum_bene_ymin' `cum_bene_ymax') titlegap(*1)) ///
			xscale(range(0 200) titlegap(*1)) ///
			xlabel(0(20)200) ///
			ytitle(`ytitle_txt', size(medsmall) margin(medium)) ///
			xtitle("Year", size(medium) margin(medium)) ///
			graphregion(color(white)) ///
			legend(order(1 "Benefits" ///
					     2 "Advance costs" ///
					     3 "Response costs") ///
					position(12) cols(3) region(lstyle(none)) size(small))

		local outname = "`figuredir'/`scenario'_bene_costs_`type'_cum"
		graph export "`outname'`outsuffix'.png", replace
	}
	pause 
	** Alternate flow cost plot
	/*
	foreach type in "n" "p" {

		if "`type'" == "n" {
			local ytitle_txt = "Costs`rel_moniker' ({c $|}bn, nom)"
			local unit_modifier = "bn_"
			local ymin `n_flow_costs_ymin'
			local ymax `n_flow_costs_ymax'
		}
		else {
			local ytitle_txt = "Costs`rel_moniker' ({c $|}mn, pv)"
			local unit_modifier = ""
			local ymin `p_flow_costs_ymin'
			local ymax `p_flow_costs_ymax'
		}
		
		// scatter inp_costs_all_`type' yr, msymbol(X) mcolor("`c_inp_all'") msize(medlarge) ||
		qui line adv_RD_`unit_modifier'`type' yr, lcolor("`c_adv_RD'") lpattern(solid) || ///
			line adv_cap_`unit_modifier'`type' yr, lcolor("`c_adv_cap'") lpattern(solid) || ///
			line surveil_`unit_modifier'`type' yr, lcolor("`c_surveil'") lpattern(solid) || ///
			line inp_RD_`unit_modifier'`type' yr, lcolor("`c_inp_resp'") lpattern(longdash) || ///
			line inp_cap_`unit_modifier'`type' yr, lcolor("`c_inp_all'") lpattern(longdash) || ///
			line inp_costs_unit_`unit_modifier'`type' yr, lcolor("`c_inp_unit'") lpattern(longdash) ||, ///
			ylabel(, grid gstyle(major) glwidth(thin)) ///
			yscale( titlegap(*1)) ///
			xscale(range(0 200) titlegap(*1)) ///
			xlabel(0(20)200) ///
			ytitle("`ytitle_txt'", size(medsmall) margin(medium)) ///
			xtitle("Year", size(medium) margin(medium)) ///
			graphregion(color(white)) ///
			legend(label(1 "Advance R&D") ///
					label(2 "Advance capacity") ///
					label(3 "Enhanced surveillance") ///
					label(4 "Response R&D") ///
					label(5 "Response capacity") ///
					label(6 "Response unit costs") ///
					position(12) cols(3) region(lstyle(none)) size(small))
		
		local outname = "`figuredir'/`scenario'_costs_disagg_`type'"
		graph export "`outname'`outsuffix'.png", replace 

	} */
	
	* Print stats for presentation
	
	
	/*
	** Broken axes plots
	
	*** TIME SERIES -- COST BREAKDOWN
	foreach type in "n" "p" {

		if "`type'" == "n" {
			local ytitle_txt = "Costs`rel_moniker' ({c $|}bn, nom)"
			local unit_modifier = "bn_"
			local ymin `n_flow_costs_ymin'
			local ystep .5
			local ymax 3
		}
		else {
			local ytitle_txt = "Costs`rel_moniker' ({c $|}mn, pv)"
			local unit_modifier = ""
			local ymin `p_flow_costs_ymin'
			local ystep 500
			local ymax 2000
		}
		
		// scatter inp_costs_all_`type' yr, msymbol(X) mcolor("`c_inp_all'") msize(medlarge) ||
		qui line adv_RD_`unit_modifier'`type' yr, lcolor("`c_adv_RD'") lpattern(solid) || ///
			line adv_cap_`unit_modifier'`type' yr, lcolor("`c_adv_cap'") lpattern(solid) || ///
			line inp_costs_investments_`unit_modifier'`type' yr, lcolor("`c_inp_resp'") lpattern(longdash) || ///
			line inp_costs_unit_`unit_modifier'`type' yr, lcolor("`c_inp_unit'") lpattern(longdash) || ///
			line inp_costs_all_`unit_modifier'`type' yr, lcolor("`c_inp_all'") lpattern(longdash) ||, ///
			ylabel(0(`ystep')`ymax', grid gstyle(major) glwidth(thin)) ///
			yscale(range(0 `ymax') titlegap(*1)) ///
			xscale(range(0 200) titlegap(*5)) ///
			xlabel(0(20)200) ///
			ytitle("`ytitle_txt'", size(medsmall) margin(medium)) ///
			xtitle("Year", size(medium) margin(medium)) ///
			graphregion(color(white)) ///
			legend(label(1 "Advance R&D") ///
					label(2 "Advance capacity") ///
					label(3 "Response investments") ///
					label(4 "Response unit costs") ///
					label(5 "Tot. response costs") ///
					position(12) cols(3) region(lstyle(none)) size(small))
		
		local outname = "`figuredir'/`scenario'_costs_`type'_no_surveil"
		graph export "`outname'`outsuffix'.png", replace 
	} */
}

