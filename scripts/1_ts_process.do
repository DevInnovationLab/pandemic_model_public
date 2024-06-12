
/**
 *
 * This script takes the output ts runs from matlab, and generates summary statistics across simulations.
 * It also take the difference between the baseline and preparedness scenarios across simulations, and computes those summary statistics.
 *
 */

pause off
set more off

local root "C:\Users\Sebastian Quaade\Documents\GitHub\pandemic_model\output\CEPI_phase_2_exogenous_rental"
local baseline_scenario "business_as_usual"
#delimit ;
local scenarios `" "`baseline_scenario'" "100dm" "moderate" "rd_heavy" 
	"cap_heavy" "surveillance_only" "rd_only" "cap_only"
	"surveil_and_rd" "surveil_and_cap" "rd_and_cap" "';
#delimit cr
local ts_name benefits inp_tail inp_marg inp_cap inp_RD adv_RD adv_cap surveil
local stats mean sem
local rawdir "`root'/raw"
local cleandir "`root'/clean"

* Note: create cleandir if not already existing

foreach scenario of local scenarios {
	foreach ts of local ts_name {
		foreach type in "n" "p" { // nominal vs present value
			local filename = "`rawdir'" + "/" + "`scenario'" + "_ts_" + "`ts'" + "_" + "`type'" + ".csv"
			
			import delimited "`filename'", clear
			foreach var of varlist _all {
				local newname = subinstr("`var'", "v", "y", 1)
				rename `var' `newname'
			}

			gen sim_num = _n
			order sim_num, first

			gen ts_name = "`ts'_`type'"
			order ts_name, after(sim_num)

			tempfile temp_`ts'_`type'
			save `temp_`ts'_`type'', replace
		}
		
	}

	use `temp_benefits_n', clear
	append using `temp_benefits_p'

	foreach ts of local ts_name {
		if "`ts'" ~= "benefits" {
			foreach type in "n" "p" { // nominal vs present value
				append using `temp_`ts'_`type''
			}
		}	
	}
	
	// Reshape to have ts names as columns
	tolong y, i(sim_num ts_name) j(yr)
	rename y value_
	fastreshape wide value_@, i(sim_num yr) j(ts_name) string fast
	rename value_* *
	
	// Create aggregated variables
	gen inp_costs_all_n = inp_cap_n + inp_RD_n + inp_marg_n + inp_tail_n
	gen inp_costs_all_p = inp_cap_p + inp_RD_p + inp_marg_p + inp_tail_p

	gen inp_costs_invest_n = inp_cap_n + inp_RD_n
	gen inp_costs_invest_p = inp_cap_p + inp_RD_p
	
	// call non-response "unit" costs
	gen inp_costs_unit_n = inp_marg_n + inp_tail_n 
	gen inp_costs_unit_p = inp_marg_p + inp_tail_p
	
	gen inp_costs_prod_n = inp_costs_unit_n + inp_costs_invest_n
	gen inp_costs_prod_p = inp_costs_unit_p + inp_costs_invest_p

	gen adv_costs_all_n = adv_RD_n + adv_cap_n + surveil_n
	gen adv_costs_all_p = adv_RD_p + adv_cap_p + surveil_p
	
	gen total_costs_p = adv_costs_all_p + inp_costs_all_p
	gen total_costs_n = adv_costs_all_n + inp_costs_all_n
	
	gen net_benefits_p = benefits_p - total_costs_p
	gen net_benefits_n = benefits_n - total_costs_n
	
	foreach var of varlist *_p *_n {
		bys sim_num (yr): gen `var'_cum = sum(`var')
	}
	
	pause
	if ("`scenario'" == "`baseline_scenario'") { // Save baseline outcomes for taking difference
		tempfile baseline_results
		preserve
			rename *_p *_p_b
			rename *_p_cum *_p_cum_b
			rename *_n *_n_b
			rename *_n_cum *_n_cum_b
			save `baseline_results', replace
		restore
	}
	
	// Save dataset with full time series for each variable
	save "`cleandir'/`scenario'_full.dta", replace
	export delimited "`cleandir'/`scenario'_full.csv", replace

		
	// Create collapse call
	local collapse_call
	foreach stat of local stats {
		local collapse_call `collapse_call' (`stat') `stat'_*
	}
	
	// Generate and save aggregated results
	preserve
		pause
		// Create variables for summary statistics to simplify collapse call
		foreach var of varlist *_p *_p_cum *_n *_n_cum {
			foreach stat of local stats {
				gen `stat'_`var'=`var'
			}
		}
		// Generate summary statistics and save
		collapse `collapse_call', by(yr)
		save "`cleandir'/`scenario'_agg.dta", replace
	restore
	
	// Generate and save aggregated results relative to baseline
	// Merge in baseline results and take difference
	merge 1:1 sim_num yr using `baseline_results'
	pause
			
	foreach var of varlist *_p *_p_cum *_n *_n_cum {
		replace `var' = `var' - `var'_b
	}
	drop *_b
		
	// Create variables for summary statistics to simplify collapse call
	foreach var of varlist *_p *_p_cum *_n *_n_cum {
		foreach stat of local stats {
			gen `stat'_`var'=`var'
		}
	}
		
	// Save dataset with full differenced time series for each variable
	save "`cleandir'/`scenario'_full_diff.dta", replace
	export delimited "`cleandir'/`scenario'_full_diff.csv", replace
			
	// Generate summary statistics
	collapse `collapse_call', by(yr)
		
	// Generate confidence intervals
	foreach var in benefits net_benefits inp_RD inp_cap inp_costs_invest inp_costs_prod inp_costs_all total_costs ///
		inp_marg inp_tail inp_costs_unit adv_RD adv_cap adv_costs_all surveil {
			foreach type in "n" "p" {
				foreach cum in "" "_cum" {
					gen lower_`var'_`type'`cum' = mean_`var'_`type'`cum' - (1.96 * sem_`var'_`type'`cum')
					gen upper_`var'_`type'`cum' = mean_`var'_`type'`cum' + (1.96 * sem_`var'_`type'`cum')
			}
		}
	}
			
	// Save summary results
	save "`cleandir'/`scenario'_agg_diff.dta", replace
	export delimited "`cleandir'/`scenario'_agg_diff.csv", replace
	
}

