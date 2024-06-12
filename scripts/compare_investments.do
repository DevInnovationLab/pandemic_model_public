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
    use "`cleandir'/`scenario'_full_diff.dta", clear
	
	keep if yr == 200
	keep yr benefits_?_cum total_costs_?_cum
	
	gen scenario = "`scenario'"

    if (`i' > 1) {
        append using `summary_ds'
    }

    sa `summary_ds', replace
    local i = `i' + 1

}

use `summary_ds', clear

local eps 0.000001
foreach var of varlist benefits_?_cum total_costs_?_cum {
	replace `var' = `var' / 1000
}

tempfile costs_stats
tempfile benefits_stats

* Calculate means and confidence intervals for costs and benefits
statsby mean_total_costs_p_cum=r(mean) lb_total_costs_p_cum=r(lb) ub_total_costs_p_cum=r(ub), by(scenario) saving(`costs_stats'): ci means total_costs_p_cum
statsby mean_benefits_p_cum=r(mean) lb_benefits_p_cum=r(lb) ub_benefits_p_cum=r(ub), by(scenario) saving(`benefits_stats'): ci means benefits_p_cum

* Merge the two datasets by scenario_labeled
use `costs_stats', clear
merge 1:1 scenario using `benefits_stats'

* Reshape data for graph bar
rename mean_total_costs_p_cum mean_c
rename lb_total_costs_p_cum lb_c
rename ub_total_costs_p_cum ub_c
rename mean_benefits_p_cum mean_b
rename lb_benefits_p_cum lb_b
rename ub_benefits_p_cum ub_b
drop _merge
tolong mean_ lb_ ub_, i(scenario) j(type)

rename *_ *
replace type = "Benefits" if type == "b"
replace type = "Costs" if type == "c"

local i = 1
gen scen_type = .
foreach scen of local scenarios {
	replace scen_type = `i' * 3 if scenario == "`scen'"
	local i = `i' + 1
}

replace scen_type = scen_type - 1 if type == "Benefits"
replace scen_type = scen_type - 2 if type == "Costs"

* Create the bar chart with error bars
local ytitle_txt `" "Benefits and costs from" "advance investments" "({c $|}bn, present value)" "'
twoway (bar mean scen_type if type=="Costs", color(red)) ///
       (bar mean scen_type if type=="Benefits", color(green)) ///
       (rcap ub lb scen_type, color(black%70)), ///
	   ytitle(`ytitle_txt', size(medium)) ///
	   ylabel(, grid gstyle(major)) yscale(titlegap(*1)) ///
	   graphregion(color(white)) xsize(8) ///
       legend( ///
		row(1) order(1 "Costs" 2 "Benefits") ///
		position(12) cols(2) region(lstyle(none))) ///
       xlabel( ///
	    1.5 "Business-as-usual" ///
		4.5 "Surveillance only" ///
		7.5 "R&D only" ///
		10.5 "Cap only" ///
		13.5 "Surveil and R&D" ///
		16.5 "Surveil and cap" ///
		19.5 "R&D and cap" ///
		22.5 "Moderate", noticks labsize(small) angle(45) labgap(3)) xtitle("")
		
local outfile = "`figuredir'/comparison_across_scenarios_p.png"
graph export "`outfile'", replace