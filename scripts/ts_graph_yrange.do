
pause on

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
	foreach var of varlist _all {
		if "`var'" ~= "yr" {
			gen `var'_cum = sum(`var') / 1000 // all cum are in bn, by default
		}
	}
	gen total_costs_p_cum = adv_costs_all_p_cum + inp_costs_all_p_cum
	gen net_bene_adv_cum = benefits_p_cum - adv_costs_all_p_cum
	gen net_bene_tot_cum = benefits_p_cum - total_costs_p_cum
	list benefits_p_cum if yr == 30 | yr == 200
	list net_bene_adv_cum if yr == 30 | yr == 200
	list net_bene_tot_cum if yr == 30 | yr == 200
	list total_costs_p_cum if yr == 30 | yr == 200
	list inp_cap_p_cum if yr == 30 | yr == 200
	list inp_costs_all_p_cum if yr == 30 | yr == 200

	foreach type in "n" "p" { // benefits and the two aggregated cost categories are in bn
		gen benefits_bn_`type' = benefits_`type'/1000
		gen adv_costs_all_bn_`type' = adv_costs_all_`type'/1000
		gen inp_costs_all_bn_`type' = inp_costs_all_`type'/1000
	}

	foreach type in "n" { 

		*** nominal benfits and the two aggregated costs are in tn for cumulative
		gen benefits_tn_`type'_cum = benefits_`type'_cum /1000
		gen adv_costs_all_tn_`type'_cum = adv_costs_all_`type'_cum/1000
		gen inp_costs_all_tn_`type'_cum = inp_costs_all_`type'_cum/1000

		*** nominal costs in bn
		gen adv_RD_bn_`type' = adv_RD_`type' / 1000
		gen surveil_bn_`type' = surveil_`type' / 1000
		gen adv_cap_bn_`type' = adv_cap_`type' / 1000
		gen inp_RD_bn_`type' = inp_RD_`type' / 1000
		gen inp_cap_bn_`type' = inp_cap_`type' / 1000
		gen inp_costs_investments_bn_`type' = inp_costs_investments_`type' / 1000
		gen inp_costs_unit_bn_`type' = inp_costs_unit_`type' / 1000
	}

	*** TIME SERIES -- COST BREAKDOWN
	foreach type in "n" "p" {

		if "`type'" == "n" {
			local ytitle_txt = "Costs`rel_moniker' ({c $|}bn, nom)"
			local unit_modifer = "bn_"
			local ymin `n_flow_costs_ymin'
			local ymax `n_flow_costs_ymax'
		}
		else {
			local ytitle_txt = "Costs`rel_moniker' ({c $|}mn, pv)"
			local unit_modifer = ""
			local ymin `p_flow_costs_ymin'
			local ymax `p_flow_costs_ymax'
		}
		
		// scatter inp_costs_all_`type' yr, msymbol(X) mcolor("`c_inp_all'") msize(medlarge) ||
		qui line adv_RD_`unit_modifer'`type' yr, lcolor("`c_adv_RD'") lpattern(solid) || ///
			line adv_cap_`unit_modifer'`type' yr, lcolor("`c_adv_cap'") lpattern(solid) || ///
			line surveil_`unit_modifer'`type' yr, lcolor("`c_surveil'") lpattern(solid) || ///
			line inp_costs_investments_`unit_modifer'`type' yr, lcolor("`c_inp_resp'") lpattern(longdash) || ///
			line inp_costs_unit_`unit_modifer'`type' yr, lcolor("`c_inp_unit'") lpattern(longdash) || ///
			line inp_costs_all_`unit_modifer'`type' yr, lcolor("`c_inp_all'") lpattern(longdash) ||, ///
			ylabel(0(1)5, grid gstyle(major) glwidth(thin)) ///
			yscale(range(`ymin' `ymax') titlegap(*1)) ///
			yscale( titlegap(*1)) ///
			xscale(range(0 200) titlegap(*1)) ///
			xlabel(0(20)200) ///
			ytitle(`ytitle_txt', size(medsmall) margin(medium)) ///
			xtitle("Year", size(medium) margin(medium)) ///
			graphregion(color(white)) ///
			legend(label(1 "Advance R&D") ///
					label(2 "Advance capacity") ///
					label(3 "Enhanced surveillance") ///
					label(4 "Response investments") ///
					label(5 "Response unit costs") ///
					label(6 "Tot. response costs") ///
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
		
		qui line benefits_bn_`type' yr, lcolor("`c_bene'") lpattern(solid) || ///
			line adv_costs_all_bn_`type' yr, lcolor("`c_adv_all'") lpattern(solid) || ///
			line inp_costs_all_bn_`type' yr, lcolor("`c_inp_all'") lpattern(longdash) ||, ///
			ylabel(, grid gstyle(major) glwidth(thin)) ///
			yscale( titlegap(*1)) ///
			xscale(range(0 200) titlegap(*1)) ///
			xlabel(0(20)200) ///
			ytitle(`ytitle_txt', size(medsmall) margin(medium)) ///
			xtitle("Year", size(medium) margin(medium)) ///
			graphregion(color(white)) ///
			legend(label(1 "Benefits") ///
					label(2 "Advance costs") ///
					label(3 "Response costs") ///
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
		qui line adv_RD_`type'_cum yr, lcolor("`c_adv_RD'") lpattern(solid) ///
		|| line adv_cap_`type'_cum yr, lcolor("`c_adv_cap'") lpattern(solid) ///
		|| line surveil_`type'_cum yr, lcolor("`c_surveil'") lpattern(solid) ///
		|| line inp_costs_investments_`type'_cum yr, lcolor("`c_inp_resp'") lpattern(longdash) ///
		|| line inp_costs_unit_`type'_cum yr, lcolor("`c_inp_unit'") lpattern(longdash) ///
		|| line inp_costs_all_`type'_cum yr, lcolor("`c_inp_all'") lpattern(longdash) ///
		, ylabel(, grid gstyle(major) glwidth(thin)) ///
			yscale( titlegap(*1)) ///
			xscale(range(0 200) titlegap(*1)) ///
			xlabel(0(20)200, labsize(small)) ///
			ytitle("`ytitle_txt'", size(medsmall) margin(medium)) ///
			xtitle("Year", size(medium) margin(medium)) ///
			graphregion(color(white)) ///
			legend(label(1 "Advance R&D") ///
					label(2 "Advance capacity") ///
					label(3 "Enhanced surveillance") ///
					label(4 "Response investments") ///
					label(5 "Response unit costs") ///
					label(6 "Tot. response costs") ///
					position(12) cols(3) size(small) region(lstyle(none)))

		local outname = "`figuredir'/`scenario'_costs_`type'_cum"
		graph export "`outname'`outsuffix'.png", replace 
	}

	*** CUM TIME SERIES -- COST vs BENEFIT
	
	// Identify the year where var1 becomes greater than var2
	gen diff = benefits_n_cum - adv_costs_all_n_cum - inp_costs_all_n_cum
	gen crossover_year = yr if diff > 0 & diff[_n-1] <= 0
	levelsof crossover_year if !missing(crossover_year), local(crossover_year)
	local line_label_year = `crossover_year' + 1
	
	foreach type in "n" "p" {

		if "`type'" == "n" {
			local ytitle_txt = `" "Cum. costs and benefits" "`rel_moniker' ({c $|}tn, nom)" "'
			local unit_modifer = "tn_"
		}
		else {
			local ytitle_txt = `" "Cum. costs and benefits" "`rel_moniker' ({c $|}bn, pv)" "'
			local unit_modifer = ""
		}
		
		qui line benefits_`unit_modifer'`type'_cum yr, lcolor("`c_bene'") lpattern(solid) || ///
			line adv_costs_all_`unit_modifer'`type'_cum yr, lcolor("`c_adv_all'") lpattern(solid) || ///
			line inp_costs_all_`unit_modifer'`type'_cum yr, lcolor("`c_inp_all'") lpattern(longdash) ||, ///
			xline(`crossover_year', lcolor(black) lwidth(medthin) lpattern(dash)) ///
			text(800 `line_label_year' "Year `crossover_year'", place(e) size(small)) ///
			ylabel(`cum_bene_ymin'(500)`cum_bene_ymax', grid gstyle(major) glwidth(thin)) ///
			yscale(range(`cum_bene_ymin' `cum_bene_ymax') titlegap(*1)) ///
			xscale(range(0 200) titlegap(*1)) ///
			xlabel(0(20)200) ///
			ytitle(`ytitle_txt', size(medsmall) margin(medium)) ///
			xtitle("Year", size(medium) margin(medium)) ///
			graphregion(color(white)) ///
			legend(label(1 "Benefits") ///
					label(2 "Advance costs") ///
					label(3 "Response costs") ///
					position(12) cols(3) region(lstyle(none)) size(small))

		local outname = "`figuredir'/`scenario'_bene_costs_`type'_cum"
		graph export "`outname'`outsuffix'.png", replace
	}
	
	** Alternate flow cost plot
	
	foreach type in "n" "p" {

		if "`type'" == "n" {
			local ytitle_txt = "Costs`rel_moniker' ({c $|}bn, nom)"
			local unit_modifer = "bn_"
			local ymin `n_flow_costs_ymin'
			local ymax `n_flow_costs_ymax'
		}
		else {
			local ytitle_txt = "Costs`rel_moniker' ({c $|}mn, pv)"
			local unit_modifer = ""
			local ymin `p_flow_costs_ymin'
			local ymax `p_flow_costs_ymax'
		}
		
		// scatter inp_costs_all_`type' yr, msymbol(X) mcolor("`c_inp_all'") msize(medlarge) ||
		qui line adv_RD_`unit_modifer'`type' yr, lcolor("`c_adv_RD'") lpattern(solid) || ///
			line adv_cap_`unit_modifer'`type' yr, lcolor("`c_adv_cap'") lpattern(solid) || ///
			line surveil_`unit_modifer'`type' yr, lcolor("`c_surveil'") lpattern(solid) || ///
			line inp_RD_`unit_modifer'`type' yr, lcolor("`c_inp_resp'") lpattern(longdash) || ///
			line inp_cap_`unit_modifer'`type' yr, lcolor("`c_inp_all'") lpattern(longdash) || ///
			line inp_costs_unit_`unit_modifer'`type' yr, lcolor("`c_inp_unit'") lpattern(longdash) ||, ///
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

	}
	
	* Print stats for presentation
	
	
	/*
	** Broken axes plots
	
	*** TIME SERIES -- COST BREAKDOWN
	foreach type in "n" "p" {

		if "`type'" == "n" {
			local ytitle_txt = "Costs`rel_moniker' ({c $|}bn, nom)"
			local unit_modifer = "bn_"
			local ymin `n_flow_costs_ymin'
			local ystep .5
			local ymax 3
		}
		else {
			local ytitle_txt = "Costs`rel_moniker' ({c $|}mn, pv)"
			local unit_modifer = ""
			local ymin `p_flow_costs_ymin'
			local ystep 500
			local ymax 2000
		}
		
		// scatter inp_costs_all_`type' yr, msymbol(X) mcolor("`c_inp_all'") msize(medlarge) ||
		qui line adv_RD_`unit_modifer'`type' yr, lcolor("`c_adv_RD'") lpattern(solid) || ///
			line adv_cap_`unit_modifer'`type' yr, lcolor("`c_adv_cap'") lpattern(solid) || ///
			line inp_costs_investments_`unit_modifer'`type' yr, lcolor("`c_inp_resp'") lpattern(longdash) || ///
			line inp_costs_unit_`unit_modifer'`type' yr, lcolor("`c_inp_unit'") lpattern(longdash) || ///
			line inp_costs_all_`unit_modifer'`type' yr, lcolor("`c_inp_all'") lpattern(longdash) ||, ///
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

