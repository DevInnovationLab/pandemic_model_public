/* Estimate vaccine development timelines from cleaned expert survey responses */

// Import data
import delimited "./data/clean/vaccine_rd_timelines.csv", clear

drop if has_prototype == 0 // Clean this up later as these data are actually very different

// Encode variables
encode viral_family, gen(viral_family_enc)

// Define nice labels for viral families (capitalize, no underscores)
label define viral_family_lbl 1 "Arenaviridae" 2 "Coronaviridae" 3 "Filoviridae" 4 "Flaviviridae" 5 "Nairoviridae" 6 "Orthomyxoviridae" 7 "Paramyxoviridae" 8 "Phenuiviridae" 9 "Togaviridae"
label values viral_family_enc viral_family_lbl

// Run regression
eststo vf_model: intreg years_min years_max i.viral_family_enc, vce(cluster respondent)

// Output results: Create LaTeX table with enhanced formatting and nice labels
estout vf_model using "./output/rd_timelines/vf_model.tex", ///
    cells("b(fmt(3) star) se(par fmt(3))") ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    label varlabels(_cons "Constant" ///
        1.viral_family_enc "Arenaviridae" ///
        2.viral_family_enc "Coronaviridae" ///
        3.viral_family_enc "Filoviridae" ///
        4.viral_family_enc "Flaviviridae" ///
        5.viral_family_enc "Nairoviridae" ///
        6.viral_family_enc "Orthomyxoviridae" ///
        7.viral_family_enc "Paramyxoviridae" ///
        8.viral_family_enc "Phenuiviridae" ///
        9.viral_family_enc "Togaviridae") ///
    prehead("\begin{table}[htbp] \centering \caption{Interval regression results predicting R\&D timelines} \label{tab:rd_timelines_results} \begin{tabular}{lcc} \hline \hline") ///
    posthead("\textbf{Variable} & \textbf{Coefficient} & \textbf{Standard error} \\ \hline") ///
    keep(*.viral_family_enc _cons lnsigma) ///
    order(*.viral_family_enc _cons lnsigma) ///
    prefoot("\hline") ///
    postfoot("\hline \hline \multicolumn{2}{l}{\footnotesize{* \$p<0.10\$, ** \$p<0.05\$, *** \$p<0.01\$}. Standard errors are clustered at the respondent level.} \\ \end{tabular} \end{table}") ///
    style(tex) ///
    stats(N chi2, fmt(%9.0f %9.2f) ///
        labels("Observations" "Chi-squared")) ///
    replace

// Export viral family model figure and coefficients.
preserve
    duplicates drop viral_family_enc has_prototype, force

    // Create a temporary capitalized label for viral family
    label copy viral_family_enc viral_family_enc_cap
    foreach v of numlist 1/9 {
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

    // Plot predictions with confidence intervals by prototype status
    graph twoway ///
        (rcap pred_lb pred_ub viral_family_enc, color(maroon%70)) ///
        (scatter preds viral_family_enc, msize(medium) msymbol(O) mcolor(maroon)), ///
        xlabel(1(1)9, valuelabel angle(45)) ///
        ylabel(, angle(0)) ///
        ytitle("Development time (years)") ///
        xtitle("Viral family") ///
        title("Vaccine development duration (with prototype)") ///
        legend(off) ///
        scheme(s2color) graphregion(color(white)) bgcolor(white)

    // Save figure and estimates
    graph export "./output/rd_timelines/timeline_with_prototype_preds.png", replace width(2400)

    // Put lower case value labels back
    label values viral_family_enc viral_family_enc

    drop years_min years_max respondent *_enc *_lb *_ub ///
        disease _est*
    export delimited "./output/rd_timelines/timeline_with_prototype_preds.csv", replace
restore
