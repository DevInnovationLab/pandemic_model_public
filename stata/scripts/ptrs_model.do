/* Estimte vaccine success probabilities from cleaned expert survey responses */

// Import data
import delimited "./data/clean/vaccine_ptrs.csv", clear

keep if platform == "traditional_only" | platform == "mrna_only"

// Encode variables
encode pathogen, gen(pathogen_enc)
encode platform, gen(platform_enc)
label define has_prototype 0 "no_prototype" 1 "has_prototype"
label values has_prototype has_prototype

// Define nice labels for pathogens and platforms (capitalize, no underscores)
label define pathogen_lbl 1 "CCHF" 2 "Chikungunya" 3 "Coronavirus" 4 "Ebola" 5 "Flu" 6 "Lassa" 7 "Nipah" 8 "Rift Valley Fever" 9 "Zika"
label values pathogen_enc pathogen_lbl
label define platform_lbl 1 "mRNA only" 2 "Traditional only"
label values platform_enc platform_lbl

// Run regressions
eststo pathogen_model: meintreg value_min value_max i.pathogen_enc i.platform_enc || respondent:, family(logit)
eststo rd_model: meintreg value_min value_max i.has_prototype i.platform_enc || respondent:, family(logit)

// Output results *******

// Create LaTeX table with enhanced formatting and nice labels
estout pathogen_model using "./output/ptrs/pathogen_model.tex", ///
    cells("b(fmt(3) star) se(par fmt(3))") ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    label varlabels(_cons "Constant" ///
        1.pathogen_enc "CCHF" ///
        2.pathogen_enc "Chikungunya" ///
        3.pathogen_enc "Coronavirus" ///
        4.pathogen_enc "Ebola" ///
        5.pathogen_enc "Flu" ///
        6.pathogen_enc "Lassa" ///
        7.pathogen_enc "Nipah" ///
        8.pathogen_enc "Rift Valley Fever" ///
        9.pathogen_enc "Zika" ///
        1.platform_enc "mRNA only" ///
        2.platform_enc "Traditional only" ///
        lnsigma "Log sigma") ///
    prehead("\begin{table}[htbp] \centering \caption{Interval regression results predicting vaccine PTRS} \label{tab:ptrs_results} \begin{tabular}{lcc} \hline \hline") ///
    posthead("\textbf{Variable} & \textbf{Coefficient} & \textbf(Standard error) \\ \hline") ///
    keep(*.pathogen_enc *.platform_enc _cons lnsigma) ///
    order(*.pathogen_enc *.platform_enc _cons lnsigma) ///
    prefoot("\hline") ///
    postfoot("\hline \hline \multicolumn{2}{l}{\footnotesize{* \$p<0.10\$, ** \$p<0.05\$, *** \$p<0.01\$}. Standard errors are clustered at the respondent level.} \\ \end{tabular} \end{table}") ///
    style(tex) ///
    stats(N chi2, fmt(%9.0f %9.2f) ///
        labels("Observations" "Chi-squared")) ///
    replace

// Also create coefplot
coefplot pathogen_model, ///
    keep(*.pathogen_enc *.platform_enc _cons) ///
    drop(lnsigma) ///
    vertical ///
    xlabel(, angle(45)) ///
    yline(0, lpattern(dash)) ///
    title("Coefficient estimates with 95% CI") ///
    legend(off)

graph export "./output/ptrs/pathogen_model_coefplot.png", replace width(2400)

// Export pathogen model figure and coefficients.
preserve
    duplicates drop pathogen_enc platform_enc, force

    // Create a temporary capitalized label for pathogen
    label copy pathogen_enc pathogen_enc_cap
    foreach v of numlist 1/9 {
        local lab : label pathogen_enc `v'
        local lab = subinstr("`lab'", "_", " ", .)
        // Rename "Crimean Congo Hemorrhagic Fever" to "CCHF" before proper() is applied
        if lower("`lab'") == "crimean-congo hemorrhagic fever" {
            local lab = "CCHF"
            label define pathogen_enc_cap `v' "`lab'", modify
        }
        else {
            label define pathogen_enc_cap `v' "`=proper("`lab'")'", modify
        }
    }

    // Apply capitalized labels temporarily for plotting
    label values pathogen_enc pathogen_enc_cap

    // Generate predictions
    estimates restore pathogen_model
    predict preds, xb
    predict ses, stdp

    // Create confidence intervals
    gen pred_lb = preds - 1.96*ses
    gen pred_ub = preds + 1.96*ses

    // Convert predictions and CIs to percent
    gen preds_pct = preds * 100
    gen pred_lb_pct = pred_lb * 100
    gen pred_ub_pct = pred_ub * 100

    // Generate x-axis positions to stack points
    gen trad_xpos = pathogen_enc - 0.15 if platform == "traditional_only"
    gen mrna_xpos = pathogen_enc + 0.15 if platform == "mrna_only"

    // Plot predictions with confidence intervals by platform (percent version)
    twoway (scatter preds_pct pathogen_enc, msize(0) mcolor(white)) ///
        (rcap pred_lb_pct pred_ub_pct trad_xpos if platform == "traditional_only", color(navy%70)) ///
        (scatter preds_pct trad_xpos if platform == "traditional_only", msymbol(O) mcolor(navy) msize(medium)) ///
        (rcap pred_lb_pct pred_ub_pct mrna_xpos if platform == "mrna_only", color(maroon%70)) ///
        (scatter preds_pct mrna_xpos if platform == "mrna_only", msymbol(O) mcolor(maroon) msize(medium)), ///
        xlabel(1(1)9, valuelabel angle(45) labsize(small)) ///
        ylabel(0(10)100, angle(0) format(%2.0f)) ///
        ytitle("Predicted PTRS (%)") ///
        xtitle("Pathogen") ///
        legend(order(2 "Traditional" 4 "mRNA") rows(1)) ///
        scheme(s2color) graphregion(color(white)) bgcolor(white)

    // Save percent figure and estimates
    graph export "./output/ptrs/pathogen_model_preds_percent.png", replace width(2400)

    // Plot predictions by platform (percent version, no error bars)
    twoway ///
        (scatter preds_pct pathogen_enc, msize(0) mcolor(white)) ///
        (scatter preds_pct trad_xpos if platform == "traditional_only", msymbol(O) mcolor(navy) msize(medium)) ///
        (scatter preds_pct mrna_xpos if platform == "mrna_only", msymbol(O) mcolor(maroon) msize(medium)), ///
        xlabel(1(1)9, valuelabel angle(45) labsize(small)) ///
        ylabel(0(10)100, angle(0) format(%2.0f)) ///
        ytitle("Predicted PTRS (%)") ///
        xtitle("Pathogen") ///
        legend(order(2 "Traditional" 3 "mRNA") rows(1)) ///
        scheme(s2color) graphregion(color(white)) bgcolor(white)

    graph export "./output/ptrs/pathogen_model_preds_percent_noerr.png", replace width(2400)

    // Put lower case value labels back
    label values pathogen_enc pathogen_enc

    drop value_min value_max has_prototype* respondent *_enc *_lb *_ub ///
        disease _est* *_xpos preds_pct pred_lb_pct pred_ub_pct
    export delimited "./output/ptrs/pathogen_model_preds.csv", replace
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
    drop if missing(has_prototype)

    // Generate predictions
    estimates restore rd_model
    predict preds, xb
    predict ses, stdp

    // Create confidence intervals
    gen pred_lb = preds - 1.96*ses
    gen pred_ub = preds + 1.96*ses

    // Convert predictions and CIs to percent
    gen preds_pct = preds * 100
    gen pred_lb_pct = pred_lb * 100
    gen pred_ub_pct = pred_ub * 100

    generate trad_xpos = (has_prototype - 0.05) / 2 if platform == "traditional_only"
    generate mrna_xpos = (has_prototype + 0.05) / 2 if platform == "mrna_only"

    // Plot predictions with confidence intervals by platform (percent version)
    graph twoway ///
        (rcap pred_lb_pct pred_ub_pct trad_xpos if platform == "traditional_only", ///
            vertical lcolor(navy%70)) ///
        (scatter preds_pct trad_xpos if platform == "traditional_only", ///
            msymbol(O) mcolor(navy) msize(medium)) ///
        (rcap pred_lb_pct pred_ub_pct mrna_xpos if platform == "mrna_only", ///
            vertical lcolor(maroon%70)) ///
        (scatter preds_pct mrna_xpos if platform == "mrna_only", ///
            msymbol(D) mcolor(maroon) msize(medium)), ///
        title("Predicted PTRS by platform and prototype vaccine status", size(medium)) ///
        xlabel(0 "No prototype" 0.5 "Has prototype", angle(0)) ///
        ylabel(0(10)100, angle(0) format(%2.0f)) ///
        ytitle("Predicted PTRS (%)") ///
        xtitle("R&D status") ///
        legend(order(2 "Traditional" 4 "mRNA") position(6) rows(1)) ///
        scheme(s2color) graphregion(color(white)) bgcolor(white) ///
        xscale(range(-0.2 0.7))

    // Save percent figure and estimates
    graph export "./output/ptrs/rd_model_preds_percent.png", replace width(2400)

    // Plot predictions by platform (percent version, no error bars)
    graph twoway ///
        (scatter preds_pct trad_xpos if platform == "traditional_only", ///
            msymbol(O) mcolor(navy) msize(medium)) ///
        (scatter preds_pct mrna_xpos if platform == "mrna_only", ///
            msymbol(D) mcolor(maroon) msize(medium)), ///
        title("Predicted PTRS by platform and prototype vaccine status", size(medium)) ///
        xlabel(0 "No prototype" 0.5 "Has prototype", angle(0)) ///
        ylabel(0(10)100, angle(0) format(%2.0f)) ///
        ytitle("Predicted PTRS (%)") ///
        xtitle("R&D status") ///
        legend(order(1 "Traditional" 2 "mRNA") position(6) rows(1)) ///
        scheme(s2color) graphregion(color(white)) bgcolor(white) ///
        xscale(range(-0.2 0.7))

    graph export "./output/ptrs/rd_model_preds_percent_noerr.png", replace width(2400)

    drop value_min value_max pathogen* respondent *_enc *_lb *_ub ///
        disease _est* *_xpos preds_pct pred_lb_pct pred_ub_pct
    export delimited "./output/ptrs/rd_model_preds.csv", replace
restore
