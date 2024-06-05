** Creates bar chart comparing one-hot investment scenarios to combined

pause on
set more off

local root "C:/Users/Sebastian Quaade/Documents/GitHub/pandemic_model/output/CEPI_phase_2_exogenous_rental"
local cleandir "`root'/clean"
local figuredir "`root'/figures"
#delimit ;
local scenarios `" "business_as_usual" "surveillance_only" "rd_only" "cap_only"
				   "surveil_and_rd" "surveil_and_cap" "rd_and_cap" "moderate" "';
#delimit cr

* Collate scenario summary statistics.
tempfile summary_ds
local i = 1
foreach scenario of local scenarios {
    use "`cleandir'/`scenario'_agg_diff.dta", clear
	
	replace benefits_n = benefits_n / 1000
	replace benefits_p = benefits_p / 1000
    gen all_costs_n = (inp_costs_all_n + adv_costs_all_n) / 1000
    gen all_costs_p = (inp_costs_all_p + adv_costs_all_p) / 1000
    collapse (sum) benefits_n benefits_p all_costs_n all_costs_p
	gen scenario = "`scenario'"

    if (`i' > 1) {
        append using `summary_ds'
    }

    sa `summary_ds', replace
    local i = `i' + 1

}

use `summary_ds', clear

replace scenario = "Business as usual" if scenario == "business_as_usual"
replace scenario = "Capacity only" if scenario == "cap_only"
replace scenario = "R&D only" if scenario == "rd_only"
replace scenario = "R&D and capacity" if scenario == "rd_and_cap"
replace scenario = "Surveillance and capacity" if scenario == "surveil_and_cap"
replace scenario = "Surveillance only" if scenario == "surveillance_only"
replace scenario = "Surveillance and R&D" if scenario == "surveil_and_rd"
replace scenario = "Moderate" if scenario == "moderate"

encode(scenario), gen(scenario_labeled)

gen bar_order = _N - _n

** Create figure

* Advance capacity costs in present value across scenarios
local ytitle_txt `" "Benefits and costs from" "advance investments" "({c $|}bn, present value)" "'
graph bar all_costs_p benefits_p, over(scenario_labeled, ///
    label(labsize(medsmall) angle(45) labgap(3)) sort(bar_order)) ///
    ylabel(, grid gstyle(major)) yscale(titlegap(*1)) ytitle(`ytitle_txt', size(medium)) ///
    graphregion(color(white)) blabel(bar, format(%9.0f)) xsize(8) ///
    legend(label(1 "Costs") label(2 "Benefits") position(12) cols(2) region(lstyle(none))) ///
    bar(1, color(red)) bar(2, color(green))
	
local outfile = "`figuredir'/comparison_across_scenarios_p.png"
graph export "`outfile'", replace

* Advance capacity costs in nominal value across scenarios
local ytitle_txt `" "Benefits and costs from" "advance investments" "({c $|}bn, nominal value)" "'
graph bar all_costs_n benefits_n, over(scenario_labeled, ///
	label(labsize(medsmall) angle(45) labgap(3))) ///
	ylabel(, grid gstyle(major)) yscale(titlegap(*1)) ytitle(`ytitle_txt', size(medium)) ///
	graphregion(color(white)) blabel(bar, format(%9.0f)) xsize(8) ///
    legend(label(1 "Costs") label(2 "Benefits") position(12) cols(2) region(lstyle(none))) ///
    bar(1, color(red)) bar(2, color(green))
	
local outfile = "`figuredir'/comparison_across_scenarios_n.png"
graph export "`outfile'", replace
