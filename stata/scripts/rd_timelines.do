/* Estimate vaccine development timelines from cleaned expert survey responses */

// Import data
import delimited "./data/clean/vaccine_rd_timelines.csv", clear

drop if has_prototype == 0 // Clean this up later as these data are actually very different

// Encode variables
encode pathogen, gen(pathogen_enc)

// Define nice labels for pathogens (capitalize, no underscores)
label define pathogen_lbl 1 "CCHF" 2 "Chikungunya" 3 "Coronavirus" 4 "Ebola" 5 "Flu" 6 "Lassa" 7 "Nipah" 8 "Rift Valley Fever" 9 "Zika"
label values pathogen_enc pathogen_lbl

// Run regression
eststo pathogen_model: intreg years_min years_max i.pathogen_enc, vce(cluster respondent)

// Output results: Create LaTeX table with enhanced formatting and nice labels
estout pathogen_model using "./output/rd_timelines/pathogen_model.tex", ///
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
        9.pathogen_enc "Zika") ///
    prehead("\begin{table}[htbp] \centering \caption{Interval regression results predicting R\&D timelines} \label{tab:rd_timelines_results} \begin{tabular}{lcc} \hline \hline") ///
    posthead("\textbf{Variable} & \textbf{Coefficient} & \textbf{Standard error} \\ \hline") ///
    keep(*.pathogen_enc _cons lnsigma) ///
    order(*.pathogen_enc _cons lnsigma) ///
    prefoot("\hline") ///
    postfoot("\hline \hline \multicolumn{2}{l}{\footnotesize{* \$p<0.10\$, ** \$p<0.05\$, *** \$p<0.01\$}. Standard errors are clustered at the respondent level.} \\ \end{tabular} \end{table}") ///
    style(tex) ///
    stats(N chi2, fmt(%9.0f %9.2f) ///
        labels("Observations" "Chi-squared")) ///
    replace

// Prepare all unique pathogens for x axis order (for both figures)
// Do NOT reload or overwrite the current data in memory, just use what is already loaded
preserve
    keep pathogen has_prototype
    duplicates drop
    sort pathogen
    gen pathogen_id = _n
    tempfile all_pathogens
    save `all_pathogens', replace
restore

// Export pathogen model figure and coefficients.
preserve
    duplicates drop pathogen_enc has_prototype, force

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

    // Plot predictions with confidence intervals by prototype status
    // Set lower y-axis limit to zero, keep same ticks, and extend one tick above the previous max
    quietly summarize pred_ub
    local ymax = r(max)
    local ytop = ceil(`ymax')

    graph twoway ///
        (rcap pred_lb pred_ub pathogen_enc, color(maroon%70)) ///
        (scatter preds pathogen_enc, msize(medium) msymbol(O) mcolor(maroon)), ///
        xlabel(1(1)9, valuelabel angle(45)) ///
        ylabel(0(1)`ytop', angle(0) grid gmin gmax) ///
        ytitle("R&D duration (years)") ///
        xtitle("Pathogen") ///
        title("Vaccine R&D duration (with prototype)") ///
        legend(off) ///
        scheme(s2color) graphregion(color(white)) bgcolor(white)

    // Save figure and estimates
    graph export "./output/rd_timelines/timeline_with_prototype_preds.png", replace width(2400)

    // Put lower case value labels back
    label values pathogen_enc pathogen_enc

    drop years_min years_max respondent *_enc *_lb *_ub ///
        disease _est*
    export delimited "./output/rd_timelines/timeline_with_prototype_preds.csv", replace
restore

// Create second figure showing with/without prototype timelines
preserve
    // Re-import the original data to avoid repeated work and merge in pathogen_id and has_prototype from the original survey data
    import delimited using "./data/clean/vaccine_rd_timelines.csv", clear
    encode pathogen, gen(pathogen_enc)
    bysort pathogen_enc: keep if _n == 1
    keep pathogen pathogen_enc has_prototype

    // Merge in pathogen_id for x axis order
    merge m:1 pathogen using `all_pathogens', keepusing(pathogen_id) nogen

    // Create a temporary capitalized label for pathogen for nice x labels
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

    // Generate predictions for with prototype (from model)
    estimates restore pathogen_model
    predict preds, xb
    predict ses, stdp

    // For pathogens without prototype, create a "no prototype" prediction (2x longer)
    gen preds_no_proto = preds * 2

    // Set up x axis positions for with/without prototype
    gen proto_xpos = pathogen_id - 0.15
    gen no_proto_xpos = pathogen_id + 0.15

    // Set lower y-axis limit to zero, keep same ticks, and extend one tick unit above top
    quietly summarize preds_no_proto
    local ymax2 = r(max)
    quietly summarize preds
    if r(max) > `ymax2' local ymax2 = r(max)
    local ytop2 = ceil(`ymax2')

    // Plot: show all pathogens, with/without prototype predictions, with nice capitalized x labels
    graph twoway ///
        (scatter preds pathogen_enc, msize(0) mcolor(white)) ///
        (scatter preds proto_xpos, msize(medium) msymbol(O) mcolor(navy)) ///
        (scatter preds_no_proto no_proto_xpos if has_prototype == 0, msize(medium) msymbol(D) mcolor(maroon)), ///
        xlabel(1(1)9, valuelabel angle(45) labsize(small)) ///
        ylabel(0(1)`ytop2', angle(0) grid gmin gmax) ///
        ytitle("R&D durations (years)") ///
        xtitle("Pathogen") ///
        title("Vaccine R&D duration") ///
        legend(order(2 "With prototype vaccine" 3 "Without prototype vaccine") position(6) rows(1)) ///
        scheme(s2color) graphregion(color(white)) bgcolor(white)

    // Save figure
    graph export "./output/rd_timelines/timeline_with_without_prototype_preds.png", replace width(2400)

restore
