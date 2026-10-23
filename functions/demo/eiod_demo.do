* **************************************************************************** *
*  eiod_demo.do
*
*  PURPOSE  Worked example of every eiod_* command, and the template to copy
*           for a real analysis.
*
*  NOTE ON  The impact variables below are deliberately named land_ado,
*  NAMING   cropland_ado, ghg_ado ... and NOT landtotal, landarable, ghg.
*
*           An earlier version of this demo named them after the indicator
*           keys and then looped
*
*               foreach i in landtotal ghg ... { eiod_absolute `i', value(`i') }
*
*           which worked only because the names coincided, and so taught that
*           the package requires those names. It never did. The names here are
*           chosen to make that impossible to misread.
*
*           The data are SIMULATED. Prevalences printed below carry no
*           substantive meaning - they exercise the code paths.
*
*  OUTPUT   eiod_demo_results.xlsx   indicator summary by group
*           eiod_demo_data.dta       the synthetic dataset with metrics
*
*  LAST UPDATE  2026-10-05
* **************************************************************************** *

version 18
clear all
set more off
set varabbrev off

* ============================================================================ *
* 0. Setup - the only two lines a new user has to edit
* ============================================================================ *
/*
   EIOD_HOME  the folder holding eiod_load_functions.do and functions/
   EIOD_REF   the folder (or the file) holding eiod_cutoffs.dta

   If the cut-offs live inside EIOD_HOME, EIOD_REF can be left unset and the
   helper will find them. They are set separately here because in a real
   project the reference data is often on a shared drive while the code sits
   in a repository.
*/
/*
   NO ABSOLUTE PATH IS HARDCODED.

   This file lives in <package>/demo/, so when it is run from its own folder -
   which is what `do eiod_demo.do' from a shell, or RStudio/Stata's "run this
   do-file" both give you - ".." IS the package folder. That makes the repo
   work for anyone who clones it, with nothing to edit.

   If you are running from somewhere else, set EIOD_HOME yourself before this
   line and it is left alone.
*/
if "$EIOD_HOME" == "" {
    capture confirm file "../eiod_load_functions.do"
    if !_rc {
        global EIOD_HOME ".."
    }
    else {
        di as error "set EIOD_HOME to the package folder before running this demo, e.g."
        di as error `"    global EIOD_HOME "C:/path/to/eiod/functions""'
        exit 601
    }
}
if "$EIOD_REF" == "" {
    global EIOD_REF "$EIOD_HOME/dta"
}

* load the commands (must come AFTER `clear all' - it drops programs)
do "$EIOD_HOME/eiod_load_functions.do"

* ============================================================================ *
* 1. Synthetic respondent-day data, with realistic variable names
* ============================================================================ *
* One row per respondent-day. In a real analysis this is your recall dataset
* collapsed to person-day level, with the environmental impact totals already
* summed across every ingredient consumed that day.
set seed 20261001
qui set obs 3000

gen long   pid     = _n
gen double age_yr  = runiform() * 60                 // 0-60 years
gen byte   sex_c   = 1 + (runiform() < 0.5)          // 1 male, 2 female

* impacts per capita per day, on EIOF database units, lognormal for realism
gen double land_ado     = exp(rnormal(ln(8),     0.8))   // m2*year   total land
gen double cropland_ado = exp(rnormal(ln(2.5),   0.7))   // m2*year   arable
gen double pasture_ado  = exp(rnormal(ln(4),     1.0))   // m2*year   pasture
gen double ghg_ado      = exp(rnormal(ln(3),     0.7))   // kg CO2eq
* EUTROPHICATION IS IN GRAMS, and deliberately so. The EIOF country databases
* report `Eutr. (g PO43-e/kg)', so a respondent total built from them is in
* grams. Both cut-off tables are in grams too - Table 4f as printed, Table 3
* as corrected by Intake in October 2026 - so nothing is converted anywhere.
* See readme/03_eiod_absolute.md.
gen double eutr_ado     = exp(rnormal(ln(20),    0.7))   // g PO4(3-)eq
gen double water_ado    = exp(rnormal(ln(600),   0.6))   // litres
gen double biodiv_ado   = exp(rnormal(ln(8e-13), 1.0))   // PDF*year
gen double gdqs_score   = 12 + 26 * runiform()           // 12-38

* a realistic amount of missingness, to show how it propagates
qui replace biodiv_ado = . if runiform() < 0.03
qui replace gdqs_score = . if runiform() < 0.02

lab var age_yr     "Age (years)"
lab var gdqs_score "Global Diet Quality Score"

* ============================================================================ *
* 2. Demographic group - required by every other command
* ============================================================================ *
eiod_demogroup, age(age_yr) sex(sex_c) generate(dgroup)

* ============================================================================ *
* 3. TABLE 3 - absolute thresholds, all seven, in ONE call
* ============================================================================ *
/*
   Each option is an EIOD indicator key; its argument is YOUR variable.
   Output variables are named from the KEY (abs_landtotal, abs_ghg, ...) so
   that results stay comparable across datasets whose inputs are named
   differently.
*/
eiod_absolute_all, group(dgroup)      ///
    landtotal(land_ado)               ///
    landarable(cropland_ado)          ///
    landpasture(pasture_ado)          ///
    ghg(ghg_ado)                      ///
    eutroph(eutr_ado)                 ///
    water(water_ado)                  ///
    biodiv(biodiv_ado)

di as txt _n "created: `r(n_ind)' indicators -> `r(indlist)'"

* ---------------------------------------------------------------------------- *
* 3b. EUTROPHICATION - NO CONVERSION, AND A CUT-OFF THAT IS NOT IN THE PDF
* ---------------------------------------------------------------------------- *
/*
   eutr_ado is in GRAMS, because that is what the EIOF database gives you:
   kg food consumed x `Eutr. (g PO43-e/kg)' = g PO4(3-)eq per person per day.

   Both cut-off tables are in grams too, so the comparison is direct:

       eutr_ado  ->  compared with thr_eutroph  ->  abs_eutroph
         (g)            (Table 3, in grams)           (0/1)

   CHANGED OCT 2026. Until then the published Table 3 printed this row in
   KILOGRAMS, and this command divided your values by 1000 to match. Intake
   confirmed both tables are in grams and supplied corrected Table 3 values,
   so the division is gone. If you have an older script that divided
   eutrophication by 1000 before calling eiod_absolute, remove it.
*/
di as txt _n "{hline 78}"
di as txt "Eutrophication: the Table 3 comparison, in grams throughout"
di as txt "{hline 78}"
list eutr_ado thr_eutroph abs_eutroph in 1/8, noobs abbrev(14)

* the comparison is exactly what it looks like - no hidden step
assert abs_eutroph == (eutr_ado < thr_eutroph) if !mi(eutr_ado)
di as result "verified: abs_eutroph == (eutr_ado < thr_eutroph), nothing converted"

/*
   THE THRESHOLD ITSELF IS NOT IN THE PUBLISHED PDF.

   thr_eutroph carries Intake's corrected value. The paper prints the same
   quantity in kilograms, so PDF x 1000 reproduces it - which is what makes
   this a unit correction rather than a changed standard.
*/
qui su thr_eutroph if dgroup == 4, meanonly
di as txt _n "Male 10+ : shipped " as res %15.10f r(mean) as txt " g   (corrected by Intake)"
di as txt     "           the PDF prints " as res "0.0267453228" as txt " kg = " ///
              as res %15.10f (0.0267453228 * 1000) as txt " g"
assert reldif(r(mean), 0.0267453228 * 1000) < 1e-8

* ============================================================================ *
* 4. TABLES 4a-4g - relative benchmark bands, all seven, in ONE call
* ============================================================================ *
eiod_relative_all, group(dgroup) below(30) ///
    landtotal(land_ado)               ///
    landarable(cropland_ado)          ///
    landpasture(pasture_ado)          ///
    ghg(ghg_ado)                      ///
    eutroph(eutr_ado)                 ///
    water(water_ado)                  ///
    biodiv(biodiv_ado)

* ============================================================================ *
* 5. PARTIAL SUPPLY - the common real-world case
* ============================================================================ *
/*
   Most projects hold a subset. Name only what you have; nothing else is
   computed and no placeholder variable is created. Here: two indicators,
   with a prefix so the output does not collide with section 3.
*/
di as txt _n(2) "{hline 78}"
di as txt "Partial supply - two indicators only" _n "{hline 78}"

eiod_absolute_all, group(dgroup) prefix(sub_) threshprefix(subthr_) ///
    ghg(ghg_ado) biodiv(biodiv_ado)

di as txt "created: `r(varlist)'"

* and the identity worth knowing: the batch wrapper is a loop, nothing more
assert sub_ghg == abs_ghg
assert sub_biodiv == abs_biodiv
di as txt "verified: eiod_absolute_all reproduces eiod_absolute exactly"

* ============================================================================ *
* 6. The single-indicator commands are still there
* ============================================================================ *
* Use these when you want one indicator, or a non-default option combination.
eiod_absolute ghg, value(ghg_ado) group(dgroup) generate(one_ghg)
assert one_ghg == abs_ghg
di as txt "verified: single-indicator call agrees with the batch call"

* ============================================================================ *
* 7. TABLE 5a - HESD, with decomposed sub-indicators
* ============================================================================ *
di as txt _n(2) "{hline 78}" _n "TABLE 5a. HESD composite metric" _n "{hline 78}"
eiod_hesd, biodiversity(biodiv_ado) gdqs(gdqs_score) group(dgroup)

* ============================================================================ *
* 8. TABLE 5b - HDLEI, with decomposed sub-indicators
* ============================================================================ *
di as txt _n(2) "{hline 78}" _n "TABLE 5b. HDLEI composite metric" _n "{hline 78}"
eiod_hdlei, biodiversity(biodiv_ado) gdqs(gdqs_score) group(dgroup)

* ============================================================================ *
* 9. Why the two composites are not interchangeable
* ============================================================================ *
di as txt _n(2) "{hline 78}" _n "HESD vs HDLEI" _n "{hline 78}"
di as txt _n "The GDQS criterion is identical in both. The environmental"
di as txt    "criterion is not: HESD uses the absolute planetary boundary,"
di as txt    "HDLEI uses position in the global reference distribution."
tab hesd_envsust hdlei_lowimpact, row

di as txt _n "Resulting disagreement on the composite:"
tab hesd hdlei

* ============================================================================ *
* 10. Results table, by demographic group
* ============================================================================ *
* Unweighted. A real analysis applies the survey design (svyset) first -
* every prevalence below would need to come from svy: mean or svy: tab.
preserve
    collapse (mean) abs_landtotal abs_ghg abs_eutroph abs_water abs_biodiv ///
                    rel_biodiv_lt30 hesd hdlei                              ///
             (count) n = pid, by(dgroup)

    foreach v of varlist abs_* rel_* hesd hdlei {
        qui replace `v' = `v' * 100
        format `v' %5.1f
    }
    lab var n "Diets"
    list, noobs abbrev(16)
    export excel using "$EIOD_HOME/demo/eiod_demo_results.xlsx", ///
        sheet("by_group") firstrow(varlabels) sheetreplace
restore

* ============================================================================ *
* 11. Save
* ============================================================================ *
compress
note: SYNTHETIC demonstration data - not real survey data.
note: Created by eiod_demo.do on `c(current_date)'.
note: Input impact variables are deliberately NOT named after the indicator keys.
save "$EIOD_HOME/demo/eiod_demo_data.dta", replace

di as result _n(2) "{hline 78}"
di as result "demo complete"
di as txt    "  $EIOD_HOME/demo/eiod_demo_data.dta"
di as txt    "  $EIOD_HOME/demo/eiod_demo_results.xlsx"
di as result "{hline 78}"
