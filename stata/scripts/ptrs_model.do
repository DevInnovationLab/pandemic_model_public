/* Estimte vaccine success probabilities from cleaned expert survey responses */

// Import data
import delimited "./data/clean/vaccine_ptrs.csv", clear

drop if viral_family == "covid-19"
keep if platform == "traditional_only" | platform == "mrna_only"

// Encode variables
encode viral_family, gen(viral_family_enc)
encode platform, gen(platform_enc)
label define has_prototype 0 "no_prototype" 1 "has_prototype"
label values has_prototype has_prototype

// Define nice labels for viral families and platforms (capitalize, no underscores)
label define viral_family_lbl 1 "Arenaviridae" 2 "Coronaviridae" 3 "Filoviridae" 4 "Flaviviridae" 5 "Nairoviridae" 6 "Orthomyxoviridae" 7 "Paramyxoviridae" 8 "Phenuiviridae" 9 "Togaviridae"
label values viral_family_enc viral_family_lbl
label define platform_lbl 1 "mRNA only" 2 "Traditional only"
label values platform_enc platform_lbl

// Run regressions
eststo vf_model: intreg value_min value_max i.viral_family_enc i.platform_enc, vce(cluster respondent)
eststo rd_model: intreg value_min value_max i.has_prototype i.platform_enc, vce(cluster respondent)

// Output results *******

// Create LaTeX table with enhanced formatting and nice labels
estout vf_model using "./output/ptrs/vf_model.tex", ///
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
        9.viral_family_enc "Togaviridae" ///
        1.platform_enc "mRNA only" ///
        2.platform_enc "Traditional only" ///
        lnsigma "Log sigma") ///
    prehead("\begin{table}[htbp] \centering \caption{Interval regression results predicting vaccine PTRS} \label{tab:ptrs_results} \begin{tabular}{lcc} \hline \hline") ///
    posthead("\textbf{Variable} & \textbf{Coefficient} & \textbf(Standard error) \\ \hline") ///
    keep(*.viral_family_enc *.platform_enc _cons lnsigma) ///
    order(*.viral_family_enc *.platform_enc _cons lnsigma) ///
    prefoot("\hline") ///
    postfoot("\hline \hline \multicolumn{2}{l}{\footnotesize{* \$p<0.10\$, ** \$p<0.05\$, *** \$p<0.01\$}. Standard errors are clustered at the respondent level.} \\ \end{tabular} \end{table}") ///
    style(tex) ///
    stats(N chi2, fmt(%9.0f %9.2f) ///
        labels("Observations" "Chi-squared")) ///
    replace

// Also create coefplot
coefplot vf_model, ///
    keep(*.viral_family_enc *.platform_enc _cons) ///
    drop(lnsigma) ///
    vertical ///
    xlabel(, angle(45)) ///
    yline(0, lpattern(dash)) ///
    title("Coefficient estimates with 95% CI") ///
    legend(off)

graph export "./output/ptrs/vf_model_coefplot.png", replace width(2400)

// Export viral family model figure and coefficients.
preserve
    duplicates drop viral_family_enc platform_enc, force

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
    gen trad_xpos = viral_family_enc - 0.15 if platform == "traditional_only"
    gen mrna_xpos = viral_family_enc + 0.15 if platform == "mrna_only"

    // Plot predictions with confidence intervals by platform
    twoway (scatter preds viral_family_enc, msize(0)) ///
        (rcap pred_lb pred_ub trad_xpos if platform == "traditional_only", color(navy%70)) ///
        (scatter preds trad_xpos if platform == "traditional_only", msymbol(O) mcolor(navy) msize(medium)) ///
        (rcap pred_lb pred_ub mrna_xpos if platform == "mrna_only", color(maroon%70)) ///
        (scatter preds mrna_xpos if platform == "mrna_only", msymbol(O) mcolor(maroon) msize(medium)), ///
        xlabel(1(1)9, valuelabel angle(45)) ///
        ylabel(0(0.1)1, angle(0)) ///
        ytitle("Predicted PTRS") ///
        xtitle("Viral Family") ///
        legend(order(2 "Traditional" 4 "mRNA") rows(1)) ///
        scheme(s2color) graphregion(color(white)) bgcolor(white)

    // Save figure and estimates
    graph export "./output/ptrs/vf_model_preds.png", replace width(2400)

    // Put lower case value labels back
    label values viral_family_enc viral_family_enc

    drop value_min value_max has_prototype* respondent *_enc *_lb *_ub ///
        disease _est* *_xpos
    export delimited "./output/ptrs/vf_model_preds.csv", replace
restore


// Output regression table for R&D model.
estout rd_model using "./output/ptrs/rd_model.tex", ///
    cells("b(fmt(3) star) se(par fmt(3))") ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    label varlabels( ///
        _cons "Constant" ///
        0.has_prototype "No prototype" ///
        1.has_prototype "Has prototype" ///
        1.platform_enc "mRNA only" ///
        2.platform_enc "Traditional only" ///
        lnsigma "Log sigma") ///
    prehead("\begin{table}[htbp] \centering \caption{Interval regression results: PTRS by R\&D status} \label{tab:ptrs_prototype_rd} \begin{tabular}{lcc} \hline \hline") ///
    posthead("\textbf{Variable} & \textbf{Coefficient} & \textbf{Standard error} \\ \hline") ///
    keep(*.has_prototype *.platform_enc _cons lnsigma) ///
    order(*.has_prototype *.platform_enc _cons lnsigma) ///
    prefoot("\hline") ///
    postfoot("\hline \hline \multicolumn{2}{l}{\footnotesize{* \$p<0.10\$, ** \$p<0.05\$, *** \$p<0.01\$}. Standard errors are clustered at the respondent level.} \\ \end{tabular} \end{table}") ///
    style(tex) ///
    stats(N chi2, fmt(%9.0f %9.2f) ///
        labels("Observations" "Chi-squared")) ///
    replace


// Export R&D model figure and coefficients.
preserve
    duplicates drop has_prototype platform_enc, force

    // Generate predictions
    estimates restore rd_model
    predict preds, xb
    predict ses, stdp

    // Create confidence intervals
    gen pred_lb = preds - 1.96*ses
    gen pred_ub = preds + 1.96*ses

    generate trad_xpos = (has_prototype - 0.05) / 2 if platform == "traditional_only"
    generate mrna_xpos = (has_prototype + 0.05) / 2 if platform == "mrna_only"

    // Plot predictions with confidence intervals by platform
    graph twoway ///
        (rcap pred_lb pred_ub trad_xpos if platform == "traditional_only", ///
            vertical lcolor(navy%70)) ///
        (scatter preds trad_xpos if platform == "traditional_only", ///
            msymbol(O) mcolor(navy) msize(medium)) ///
        (rcap pred_lb pred_ub mrna_xpos if platform == "mrna_only", ///
            vertical lcolor(maroon%70)) ///
        (scatter preds mrna_xpos if platform == "mrna_only", ///
            msymbol(D) mcolor(maroon) msize(medium)), ///
        title("Predicted PTRS by platform and prototype vaccine status", size(medium)) ///
        xlabel(0 "No prototype" 0.5 "Has prototype", angle(0)) ///
        ylabel(0(0.1)1, angle(0) format(%3.1f)) ///
        ytitle("Predicted PTRS") ///
        xtitle("R&D status") ///
        legend(order(2 "Traditional" 4 "mRNA") position(6) rows(1)) ///
        scheme(s2color) graphregion(color(white)) bgcolor(white) ///
        xscale(range(-0.2 0.7))

    // Save figure and estimates
    graph export "./output//ptrs/rd_model_preds.png", replace width(2400)

    drop value_min value_max viral_family* respondent *_enc *_lb *_ub ///
        disease _est* *_xpos
    export delimited "./output/ptrs/rd_model_preds.csv", replace
restore
