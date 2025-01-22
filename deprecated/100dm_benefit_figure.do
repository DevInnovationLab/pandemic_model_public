** Create 100 DM comparison figure


pause on
set more off

local root "C:/Users/Sebastian Quaade/Documents/GitHub/pandemic_model/output/CEPI_phase_2_exogenous_rental"
local cleandir "`root'/clean"
local figuredir "`root'/figures"


use "`cleandir'/100dm_agg_diff.dta", clear
gen scenario = "100 Day Mission"

tempfile 100_dm_file
sa `100_dm_file', replace

use "`cleandir'/rd_heavy_agg_diff.dta", clear
gen scenario = "R&D Heavy"

append using `100_dm_file'

gen benefits_bn_p = benefits_p / 1000

local ytitle `" "Benefits relative to business as usual" "({c $|}bn, nominal value)" "'
graph hbar (sum) benefits_bn_p, over(scenario, reverse) ///
	ytitle(`ytitle') ///
	graphregion(color(white)) ///
	bar(1, color(maroon))

graph export "`figuredir'/100dm_comparison.png", replace



