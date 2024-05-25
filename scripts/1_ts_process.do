
/**
 *
 * This script takes the output ts runs from matlab, and takes the average across simulations
 *
 */

pause off
set more off

local scenarios `" "100DM" "cap_heavy" "moderate" "RD_heavy" "RD_heavy2" "'
local root "C:/Users/sebqu/Box/MSA/CEPI/model_outputs/202405"

foreach scenario of local scenarios {

	local home_folder "`root'/`scenario'"
	
	if "`scenario'" == "moderate" { 
		local date_string "20240501"
	}
	else if "`scenario'" == "RD_heavy2" {
		local date_string "20240503"
	}
	else if "`scenario'" == "cap_heavy" | "`scenario'" == "100DM" | "`scenario'" == "RD_heavy" { 
		local date_string "20240502"
	}


	foreach adv_ratio in "0.00" "0.25" "0.50" {
	
		if "`adv_ratio'" == "0.50" & "`scenario'" != "cap_heavy" { 
			continue 
		}
		if "`scenario'" == "cap_heavy" & "`adv_ratio'" == "0.25" { 
			continue
		}

		foreach has_RD of numlist 0/1 {
			foreach has_surveil of numlist 0/1 {
				// local file_parent "sim_ts_false_1_adv_0.00_RD_0_surveil_0_thold_0.00_20240318"
				local file_parent "sim_ts_false_1_adv_`adv_ratio'_RD_`has_RD'_surveil_`has_surveil'_thold_0.00_`date_string'"
				di "`file_parent'"
				pause

				local ts_name benefits inp_tail inp_marg inp_cap inp_RD adv_RD adv_cap surveil
				// local ts_name benefits

				foreach ts of local ts_name {

					foreach type in "n" "p" { // nominal vs present value
					// foreach type in "n" { // nominal vs present value

						local filename = "`home_folder'" + "/" + "`file_parent'" + "_" + "`ts'" + "_" + "`type'" + ".csv"
						
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

				gen inp_costs_response_n = inp_cap_n + inp_RD_n
				gen inp_costs_response_p = inp_cap_p + inp_RD_p

				gen inp_costs_unit_n = inp_marg_n + inp_tail_n // call non-response "unit" costs
				gen inp_costs_unit_p = inp_marg_p + inp_tail_p

				gen adv_costs_all_n = adv_RD_n + adv_cap_n + surveil_n
				gen adv_costs_all_p = adv_RD_p + adv_cap_p + surveil_p

				save "`home_folder'/processed/`file_parent'_agg.dta", replace
				export delimited "`home_folder'/processed/`file_parent'_agg.csv", replace

			}
		}
	}
}
