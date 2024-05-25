
*** Net benefits across scenarios
local root "C:/Users/sebqu/Box/MSA/CEPI/CEPI all-risks model/model_outputs/202405"
#delimit ;
local scenario_files `" "RD_heavy2/processed/sim_ts_false_1_adv_0.25_RD_1_surveil_1_thold_0.00_20240503_agg_diff.dta"
	"moderate/processed/sim_ts_false_1_adv_0.25_RD_1_surveil_1_thold_0.00_20240501_agg_diff.dta"
	"cap_heavy/processed/sim_ts_false_1_adv_0.50_RD_1_surveil_1_thold_0.00_20240502_agg_diff.dta"
	"RD_heavy/processed/sim_ts_false_1_adv_0.25_RD_1_surveil_1_thold_0.00_20240502_agg_diff.dta" "';
#delimit cr
	
local i 1
tempfile temp

foreach scenario_file of local scenario_files {

	local filepath "`root'/`scenario_file'"
	use "`filepath'", clear
	
	gen net_bene_cum_p = sum(benefits_p - adv_costs_all_p)
	local pos = strpos("`scenario_file'", "/") - 1
    local scenario_name = substr("`scenario_file'", 1, `pos')
	gen scenario = "`scenario_name'"
	
	keep yr net_bene_cum_p scenario adv_cap_p adv_cap_n inp_cap_p inp_cap_n
	
	if (`i' == 1) { 
		sa `temp', replace
	}
	else { 
		append using `temp'
		sa `temp', replace
	}
	
	local i = `i' + 1
}

use `temp', clear

replace net_bene_cum_p = net_bene_cum_p / 1000
replace scenario = "100 Day Mission" if scenario == "RD_heavy2"
replace scenario = "Moderate" if scenario == "moderate"
replace scenario = "Capacity Heavy" if scenario == "cap_heavy"
replace scenario = "R&D Heavy" if scenario == "RD_heavy"
encode scenario, gen(scenario_code)

* Net benefits in present value across scenarios
local ytitle_txt "Net cumulative benefits" ///
	"relative to business as usual ($ bn, pv)"
twoway (line net_bene_cum_p yr if scenario == "100 Day Mission") ///
	   (line net_bene_cum_p yr if scenario == "R&D Heavy") ///
	   (line net_bene_cum_p yr if scenario == "Capacity Heavy") ///
	   (line net_bene_cum_p yr if scenario == "Moderate"), ///
	   ylabel(, grid gstyle(major)) yscale(titlegap(*10)) xscale( titlegap(*5)) ytitle("`ytitle_txt'", size(medium)) ///
	   xtitle("Year", size(medium)) graphregion(color(white)) ///
	   legend(label(1 "100 Day Mission") label(2 "R&D Heavy") label(3 "Capacity Heavy") label(4 "Moderate") position(12) cols(2) region(lstyle(none)))
	
local outfile = "`root'/net_cumulative_benefits_p_by_scenario.png"
graph export "`outfile'", replace

* Advance capacity costs in present value across scenarios
local ytitle_txt "Advance capacity costs ($ mn, pv)"
twoway (line adv_cap_p yr if scenario == "100 Day Mission") ///
	   (line adv_cap_p yr if scenario == "R&D Heavy") ///
	   (line adv_cap_p yr if scenario == "Capacity Heavy") ///
	   (line adv_cap_p yr if scenario == "Moderate"), ///
	   ylabel(, grid gstyle(major)) yscale(titlegap(*10)) xscale( titlegap(*5)) ytitle("`ytitle_txt'", size(medium)) ///
	   xtitle("Year", size(medium)) graphregion(color(white)) ///
	   legend(label(1 "100 Day Mission") label(2 "R&D Heavy") label(3 "Capacity Heavy") label(4 "Moderate") position(12) cols(2) region(lstyle(none)))
	
local outfile = "`root'/adv_cap_costs_p_by_scenario.png"
graph export "`outfile'", replace

* Advance capacity costs in present value across scenarios
local ytitle_txt "Advance capacity costs ($ mn, nominal)"
twoway (line adv_cap_n yr if scenario == "100 Day Mission") ///
	   (line adv_cap_n yr if scenario == "R&D Heavy") ///
	   (line adv_cap_n yr if scenario == "Capacity Heavy") ///
	   (line adv_cap_n yr if scenario == "Moderate"), ///
	   ylabel(, grid gstyle(major)) yscale(titlegap(*10)) xscale( titlegap(*5)) ytitle("`ytitle_txt'", size(medium)) ///
	   xtitle("Year", size(medium)) graphregion(color(white)) ///
	   legend(label(1 "100 Day Mission") label(2 "R&D Heavy") label(3 "Capacity Heavy") label(4 "Moderate") position(12) cols(2) region(lstyle(none)))
	
local outfile = "`root'/adv_cap_costs_n_by_scenario.png"
graph export "`outfile'", replace

* In-pandemic capacity costs in present value across scenarios
local ytitle_txt "In-pandemic capacity costs relative to business as usual($ mn, pv)"
twoway (line inp_cap_p yr if scenario == "100 Day Mission") ///
	   (line inp_cap_p yr if scenario == "R&D Heavy") ///
	   (line inp_cap_p yr if scenario == "Capacity Heavy") ///
	   (line inp_cap_p yr if scenario == "Moderate"), ///
	   ylabel(, grid gstyle(major)) yscale(titlegap(*10)) xscale( titlegap(*5)) ytitle("`ytitle_txt'", size(medium)) ///
	   xtitle("Year", size(medium)) graphregion(color(white)) ///
	   legend(label(1 "100 Day Mission") label(2 "R&D Heavy") label(3 "Capacity Heavy") label(4 "Moderate") position(12) cols(2) region(lstyle(none)))
	
local outfile = "`root'/inp_cap_costs_p_by_scenario.png"
graph export "`outfile'", replace


* In-pandemic capacity costs in present value across scenarios
local ytitle_txt "In-pandemic capacity costs relative to business as usual ($ mn, nominal)"
twoway (line inp_cap_n yr if scenario == "100 Day Mission") ///
	   (line inp_cap_n yr if scenario == "R&D Heavy") ///
	   (line inp_cap_n yr if scenario == "Capacity Heavy") ///
	   (line inp_cap_n yr if scenario == "Moderate"), ///
	   ylabel(, grid gstyle(major)) yscale(titlegap(*10)) xscale( titlegap(*5)) ytitle("`ytitle_txt'", size(medium)) ///
	   xtitle("Year", size(medium)) graphregion(color(white)) ///
	   legend(label(1 "100 Day Mission") label(2 "R&D Heavy") label(3 "Capacity Heavy") label(4 "Moderate") position(12) cols(2) region(lstyle(none)))
	
local outfile = "`root'/inp_cap_costs_n_by_scenario.png"
graph export "`outfile'", replace

bys scenario (yr): gen adv_cap_cum_n_bn = sum(adv_cap_n) / 1000
bys scenario (yr): gen adv_cap_cum_p_bn = sum(adv_cap_p) / 1000


* Cumulative Advance capacity costs in present value across scenarios
local ytitle_txt "Cumulative advance capacity costs ($ bn, pv)"
twoway (line adv_cap_cum_p_bn yr if scenario == "100 Day Mission") ///
	   (line adv_cap_cum_p_bn  yr if scenario == "R&D Heavy") ///
	   (line adv_cap_cum_p_bn  yr if scenario == "Capacity Heavy") ///
	   (line adv_cap_cum_p_bn  yr if scenario == "Moderate"), ///
	   ylabel(, grid gstyle(major)) yscale(titlegap(*10)) xscale( titlegap(*5)) ytitle("`ytitle_txt'", size(medium)) ///
	   xtitle("Year", size(medium)) graphregion(color(white)) ///
	   legend(label(1 "100 Day Mission") label(2 "R&D Heavy") label(3 "Capacity Heavy") label(4 "Moderate") position(12) cols(2) region(lstyle(none)))
	
local outfile = "`root'/adv_cap_costs_cum_p_by_scenario.png"
graph export "`outfile'", replace


* Cumulative Advance capacity costs in nominal value across scenarios
local ytitle_txt "Cumulative advance capacity costs ($ bn, nominal)"
twoway (line adv_cap_cum_n_bn yr if scenario == "100 Day Mission") ///
	   (line adv_cap_cum_n_bn  yr if scenario == "R&D Heavy") ///
	   (line adv_cap_cum_n_bn  yr if scenario == "Capacity Heavy") ///
	   (line adv_cap_cum_n_bn  yr if scenario == "Moderate"), ///
	   ylabel(, grid gstyle(major)) yscale(titlegap(*10)) xscale( titlegap(*5)) ytitle("`ytitle_txt'", size(medium)) ///
	   xtitle("Year", size(medium)) graphregion(color(white)) ///
	   legend(label(1 "100 Day Mission") label(2 "R&D Heavy") label(3 "Capacity Heavy") label(4 "Moderate") position(12) cols(2) region(lstyle(none)))
	
local outfile = "`root'/adv_cap_costs_cum_n_by_scenario.png"
graph export "`outfile'", replace
