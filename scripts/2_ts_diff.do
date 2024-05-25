/**
 *
 * Takes each scenario output and diffs it vs status quo
 *
 */

pause on
set more off

local scenarios `" "100DM" "cap_heavy" "moderate" "RD_heavy" "RD_heavy2" "'
local root "C:/Users/sebqu/Box/MSA/CEPI/model_outputs/202405"
local date_string "20240502"

// local ts_name inp_costs_all inp_costs_response inp_costs_unit adv_costs_all
local ts_name benefits inp_tail inp_marg inp_cap inp_RD adv_RD adv_cap inp_costs_all inp_costs_response inp_costs_unit adv_costs_all surveil

foreach scenario of local scenarios {
	
	local home_folder "`root'/`scenario'/processed"
	
	if "`scenario'" == "moderate" { 
		local date_string "20240501"
	}
	if "`scenario'" == "RD_heavy2" {
		local date_string "20240503"
	}
	if "`scenario'" == "cap_heavy" | "`scenario'" == "100DM" | "`scenario'" == "RD_heavy" { 
		local date_string "20240502"
	}
	
	di "`date_string'"
	
	foreach adv_ratio in "0.00" "0.25" "0.50" {
	
		if "`adv_ratio'" == "0.50" & "`scenario'" != "cap_heavy" { 
			continue 
		}
		if "`scenario'" == "cap_heavy" & "`adv_ratio'" == "0.25" { 
			continue
		}
	
		foreach has_RD of numlist 0/1 {
			foreach has_surveil of numlist 0/1 {
			
				local file_parent0 "sim_ts_false_1_adv_0.00_RD_0_surveil_0_thold_0.00_`date_string'" // status quo file
				local file_parent "sim_ts_false_1_adv_`adv_ratio'_RD_`has_RD'_surveil_`has_surveil'_thold_0.00_`date_string'"
				
				if "`file_parent0'" ~= "`file_parent'" {
					
					use "`home_folder'/`file_parent0'_agg.dta", clear

					foreach var of local ts_name { // append 0 to var name in status quo
						
						foreach type in "n" "p" {
							local vname "`var'_`type'"
						
							rename `vname' `vname'0
						}
					}
					tempfile status_quo
					save `status_quo', replace

					use "`home_folder'/`file_parent'_agg.dta", clear

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

					save "`home_folder'/`file_parent'_agg_diff.dta", replace

				}
			}
		}
	}
}



