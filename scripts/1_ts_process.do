
/**
 *
 * This script takes the output ts runs from matlab, and takes the average across simulations
 *
 */

pause off
set more off
local root "C:/Users/sebqu/OneDrive/Documents/GitHub/pandemic_model/output/CEPI_phase_2_exogenous_rental"
#delimit ;
local scenarios `" "100dm" "moderate" "business_as_usual" "rd_heavy" "cap_heavy" 
	"cap_only" "rd_and_cap" "rd_only" "surveil_and_cap" "surveil_and_rd"
	"surveillance_only" "';
#delimit cr
local ts_name benefits inp_tail inp_marg inp_cap inp_RD adv_RD adv_cap surveil
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

	collapse (mean) y*, by(ts_name)

	reshape long y, i(ts_name) j(yr)
	rename y value

	reshape wide value, i(yr) j(ts_name) string

	foreach var of varlist _all {
		local newname = subinstr("`var'", "value", "", 1)
		rename `var' `newname'
	}

	gen inp_costs_all_n = inp_cap_n + inp_RD_n + inp_marg_n + inp_tail_n
	gen inp_costs_all_p = inp_cap_p + inp_RD_p + inp_marg_p + inp_tail_p

	gen inp_costs_investments_n = inp_cap_n + inp_RD_n
	gen inp_costs_investments_p = inp_cap_p + inp_RD_p

	gen inp_costs_unit_n = inp_marg_n + inp_tail_n // call non-response "unit" costs
	gen inp_costs_unit_p = inp_marg_p + inp_tail_p
	
	gen inp_costs_production_n = inp_costs_unit_n + inp_costs_investments_n
	gen inp_costs_production_p = inp_costs_unit_p + inp_costs_investments_p

	gen adv_costs_all_n = adv_RD_n + adv_cap_n + surveil_n
	gen adv_costs_all_p = adv_RD_p + adv_cap_p + surveil_p

	save "`cleandir'/`scenario'_agg.dta", replace
	export delimited "`cleandir'/`scenario'_agg.csv", replace
}

