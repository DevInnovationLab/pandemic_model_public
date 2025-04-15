/* Estimte vaccine  development timelines from cleaned expert survey responses */

// Import data
import delimited "./data/clean/vaccine_rd_timelines.csv", clear

drop if viral_family == "covid-19"

// Encode variables
encode viral_family, gen(viral_family_enc)
label define has_adv_rd 0 "no_adv_rd" 1 "has_adv_rd"
label values has_adv_rd has_adv_rd

// Run regressions
eststo vf_model: intreg years_min years_max i.viral_family_enc i.has_adv_rd, vce(cluster respondent)

// Create LaTeX table with enhanced formatting
estout vf_model using "./output/rd_timelines/vf_model.tex", ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    label varlabels(_cons Constant) ///
    title("\begin{table}[htbp] \centering \caption{Interval regression results} \label{tab:ptrs_results}") ///
    prehead("\begin{longtable}{lcccc} \hline \hline") ///
    posthead("\hline & \multicolumn{4}{c}{Vaccine PTRS} \\ \cline{2-5} & \multicolumn{2}{c}{Without Clustering} & \multicolumn{2}{c}{With Clustering} \\ \cline{2-5} & Base & Interactions & Base & Interactions \\ \hline") ///
    keep(*.viral_family_enc _cons lnsigma) ///
    order(*.viral_family_enc _cons lnsigma) ///
    prefoot("\hline") ///
    postfoot("\hline \hline \multicolumn{5}{l}{\footnotesize{* \$p<0.10\$, ** \$p<0.05\$, *** \$p<0.01\$}} \\ \end{longtable} \end{table}") ///
    style(tex) ///
    stats(N r2 r2_p chi2, fmt(%9.0f %9.3f %9.3f %9.2f) ///
        labels("Observations" "R-squared" "Pseudo R-squared" "Chi-squared")) ///
    replace


// Export viral family model figure and coefficients.
preserve
    duplicates drop viral_family_enc has_adv_rd, force

    // Create a temporary capitalized label for viral family
    label copy viral_family_enc viral_family_enc_cap
    foreach v of numlist 1/9 { // Magic number so bad
        local lab : label viral_family_enc `v'
        label define viral_family_enc_cap `v' "`=proper("`lab'")'", modify
    }

    // Apply capitalized labels temporarily for plotting
    label values viral_family_enc viral_family_enc_cap

    // Generate predictions
    estimates restore vf_model
    predict preds, xb
    predict ses, stdp

    // Create confidence intervals
    gen pred_lb = preds - 1.96*ses
    gen pred_ub = preds + 1.96*ses

    // Generate x-axis positions to stack points
    gen has_prototype_xpos = viral_family_enc - 0.15 if has_adv_rd == 1
    gen no_prototype_xpos = viral_family_enc + 0.15 if has_adv_rd == 0

    // Plot predictions with confidence intervals by has)_adv_rd
    twoway (scatter preds viral_family_enc, msize(0)m mcolor(white%0)) ///
        (rcap pred_lb pred_ub has_prototype_xpos if has_adv_rd == 1, color(navy%70)) ///
        (scatter preds has_prototype_xpos if has_adv_rd == 1, msymbol(O) mcolor(navy) msize(medium)) ///
        (rcap pred_lb pred_ub no_prototype_xpos if has_adv_rd == 0, color(maroon%70)) ///
        (scatter preds no_prototype_xpos if has_adv_rd == 0, msymbol(O) mcolor(maroon) msize(medium)), ///
        xlabel(1(1)9, valuelabel angle(45)) ///
        ylabel(, angle(0)) ///
        ytitle("R&D timeline (years)") ///
        xtitle("Viral family") ///
        legend(order(3 "With prototype" 5 "Without prototype") rows(1)) ///
        scheme(s2color) graphregion(color(white)) bgcolor(white)

    // Save figure and estimates
    graph export "./output/rd_timelines/vf_model_preds.png", replace width(2400)

    // Put lower case value labels back
    label values viral_family_enc viral_family_enc

    drop years_min years_max respondent *_enc *_lb *_ub ///
        disease _est* *_xpos
    export delimited "./output/rd_timelines/vf_model_preds.csv", replace
restore
