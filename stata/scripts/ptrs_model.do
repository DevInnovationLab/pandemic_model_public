// Import data
import delimited "./data/clean/vaccine_ptrs.csv", clear

drop if viral_family == "covid-19"
keep if platform == "Traditional only" | platform == "mRNA only"

// Encode variables
encode viral_family, gen(viral_family_enc)
encode platform, gen(platform_enc)

// Run regressions without clustering
eststo m1_nc: intreg value_min value_max i.viral_family_enc i.platform_enc
eststo m2_nc: intreg value_min value_max i.viral_family_enc##i.platform_enc

// Run regressions with clustering
eststo m1: intreg value_min value_max i.viral_family_enc i.platform_enc, vce(cluster respondent)
eststo m2: intreg value_min value_max i.viral_family_enc##i.platform_enc, vce(cluster respondent)

// Create LaTeX table with enhanced formatting
estout m1_nc m2_nc m1 m2 using "./output/ptrs_model_results.tex", ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    label varlabels(_cons Constant) ///
    title("\begin{table}[htbp] \centering \caption{Interval Regression Results} \label{tab:ptrs_results}") ///
    prehead("\begin{longtable}{lcccc} \hline \hline") ///
    posthead("\hline & \multicolumn{4}{c}{Vaccine PTRS} \\ \cline{2-5} & \multicolumn{2}{c}{Without Clustering} & \multicolumn{2}{c}{With Clustering} \\ \cline{2-5} & Base & Interactions & Base & Interactions \\ \hline") ///
    keep(*.viral_family_enc *.platform_enc _cons lnsigma) ///
    order(*.viral_family_enc *.platform_enc _cons lnsigma) ///
    prefoot("\hline") ///
    postfoot("\hline \hline \multicolumn{5}{l}{\footnotesize{* \$p<0.10\$, ** \$p<0.05\$, *** \$p<0.01\$}} \\ \end{longtable} \end{table}") ///
    style(tex) ///
    stats(N r2 r2_p chi2, fmt(%9.0f %9.3f %9.3f %9.2f) ///
        labels("Observations" "R-squared" "Pseudo R-squared" "Chi-squared")) ///
    replace

// Generate predictions for each model
estimates restore m1_nc
predict ptrs_pred_m1nc if e(sample), xb

estimates restore m2_nc
predict ptrs_pred_m2nc if e(sample), xb

estimates restore m1
predict ptrs_pred_m1 if e(sample), xb

estimates restore m2  
predict ptrs_pred_m2 if e(sample), xb

// Create combined graph with two panels
grstyle init
grstyle set plain
grstyle set legend 6

// Traditional vaccines subplot
graph twoway (scatter ptrs_pred_m1nc viral_family_enc if platform_enc==1, msymbol(O) mcolor(navy%70) lcolor(navy%70)) ///
       (scatter ptrs_pred_m2nc viral_family_enc if platform_enc==1, msymbol(D) mcolor(maroon%70) lcolor(maroon%70)) ///
       (scatter ptrs_pred_m1 viral_family_enc if platform_enc==1, msymbol(S) mcolor(forest_green%70) lcolor(forest_green%70)) ///
       (scatter ptrs_pred_m2 viral_family_enc if platform_enc==1, msymbol(T) mcolor(dkorange%70) lcolor(dkorange%70)), ///
    name(traditional, replace) ///
    title("Traditional Vaccines", size(medium)) ///
    xlabel(1(1)9, valuelabel angle(45)) ///
    ylabel(0(0.1)1, angle(0) format(%3.1f)) ///
    ytitle("Predicted PTRS") ///
    xtitle("Viral Family") ///
    legend(off) ///
    scheme(s2color) graphregion(color(white)) bgcolor(white)

// mRNA vaccines subplot
graph twoway (scatter ptrs_pred_m1nc viral_family_enc if platform_enc==2, msymbol(O) mcolor(navy%70) lcolor(navy%70)) ///
       (scatter ptrs_pred_m2nc viral_family_enc if platform_enc==2, msymbol(D) mcolor(maroon%70) lcolor(maroon%70)) ///
       (scatter ptrs_pred_m1 viral_family_enc if platform_enc==2, msymbol(S) mcolor(forest_green%70) lcolor(forest_green%70)) ///
       (scatter ptrs_pred_m2 viral_family_enc if platform_enc==2, msymbol(T) mcolor(dkorange%70) lcolor(dkorange%70)), ///
    name(mrna, replace) ///
    title("mRNA Vaccines", size(medium)) ///
    xlabel(1(1)9, valuelabel angle(45)) ///
    ylabel(0(0.1)1, angle(0) format(%3.1f)) ///
    ytitle("Predicted PTRS") ///
    xtitle("Viral Family") ///
    legend(order(1 "Base - no clustering" 2 "With interactions - no clustering" ///
                 3 "Base - clustering" 4 "With interactions - clustering") ///
           position(6) rows(2) size(small)) ///
    scheme(s2color) graphregion(color(white)) bgcolor(white)

// Combine plots vertically
graph combine traditional mrna, ///
    title("Predicted Vaccine PTRS by Viral Family and Platform Type", size(medium)) ///
    note("Note: Points show model predictions for each viral family" ///
         "Base = no interactions between viral family and platform", size(small)) ///
    cols(1) xsize(12) ysize(12) iscale(1.1) graphregion(color(white)) ///
    commonscheme
// Save combined plot
graph export "./output/ptrs_estimates_plot_combined.png", replace width(2400)

// Save individual plots
graph export "./output/ptrs_estimates_plot_traditional.png", name(traditional) replace width(2400)
graph export "./output/ptrs_estimates_plot_mrna.png", name(mrna) replace width(2400)
