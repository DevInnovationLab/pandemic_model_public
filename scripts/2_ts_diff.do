/**
 *
 * Takes each scenario output and diffs it vs status quo
 *
 */

pause on
set more off

local root "C:\Users\Sebastian Quaade\Documents\GitHub\pandemic_model\output\CEPI_phase_2_exogenous_rental"
local cleandir "`root'/clean"
local baseline "business_as_usual"
#delimit ;
local scenarios `" "100dm" "moderate" "rd_heavy" "cap_heavy" "cap_only" "business_as_usual"
	"rd_and_cap" "rd_only" "surveil_and_cap" "surveil_and_rd" "surveillance_only" "';
#delimit cr
local ts_name benefits inp_tail inp_marg inp_cap inp_RD adv_RD adv_cap inp_costs_all inp_costs_investments inp_costs_unit inp_costs_production adv_costs_all surveil
// local ts_name inp_costs_all inp_costs_response inp_costs_unit adv_costs_all

** Load baseline and save as tempfile

use "`cleandir'/`baseline'_agg.dta", clear

foreach var of local ts_name { // append 0 to var name in status quo	
	foreach type in "n" "p" {
		local vname "`var'_`type'"
	
		rename `vname' `vname'0
	}
}
tempfile status_quo
save `status_quo', replace
	
** Loop through scenarios and take difference

foreach scenario of local scenarios {
	
	use "`cleandir'/`scenario'_agg.dta", clear

	merge 1:1 yr using "`status_quo'", assert(3) nogen

	foreach var of local ts_name {
		foreach type in "n" "p" {
			// di "`var'_`type'"
			// di "`var'_`type'0"
			gen `var'_`type'_diff = `var'_`type' - `var'_`type'0

			// pause check "`var'_`type'_diff"
		}
	}

	keep yr *_diff

	foreach var of varlist _all { // remove _diff in naming
		if "`var'" ~= "yr" {
			local nodiff = subinstr("`var'", "_diff", "", .)
			// di "`nodiff'"
			rename `var' `nodiff'
		}
	}

	save "`cleandir'/`scenario'_agg_diff.dta", replace

}




