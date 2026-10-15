* **************************************************************************** *
*  eiod_validate.do
*
*  PURPOSE  Prove that the eiod_* commands reproduce Tables 3, 4a-4g, 5a and 5b
*           of Intake-EIOD-Methods-Paper-Jan2026-Final.pdf.
*           https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf
*
*           Every check is an assert. If this do-file runs to the end, the
*           implementation matches the published tables on all tested points.
*           If one fails, FIX THE CODE - do not relax the assert.
*
*  PART A   Reference values, hand-typed from the PDF (independent of the
*           awk parser that produced eiod_cutoffs.csv)
*  PART B   Table 5a / 5b reuse the right source values
*  PART C   Boundary behaviour at a cut-off
*  PART D   Missing-value handling
*  PART E   Band assignment across all ten bands
*  PART F   Demographic group boundaries
*  PART G   Composite metric logic (the 2x2)
*  PART H   Sub-indicators equal the standalone metrics
*  PART I   Cross-table relationship: absolute vs relative
*
*  LAST UPDATE  2026-10-01
* **************************************************************************** *

version 18
clear all
set more off
set varabbrev off

* No absolute path is hardcoded. validate/ sits inside the package folder, so
* ".." is it whenever this file is run from its own directory. Set EIOD_HOME
* yourself if you are running from elsewhere.
if "$EIOD_HOME" == "" {
    capture confirm file "../eiod_load_functions.do"
    if !_rc {
        global EIOD_HOME ".."
    }
    else {
        di as error "set EIOD_HOME to the package folder before running this suite, e.g."
        di as error `"    global EIOD_HOME "C:/path/to/eiod/functions""'
        exit 601
    }
}
if "$EIOD_REF" == "" global EIOD_REF "$EIOD_HOME/dta"
global EIOD_OUT      "$EIOD_HOME"
* load the metric functions (must come AFTER `clear all` - it drops programs)
do "$EIOD_HOME/eiod_load_functions.do"

* resolve the cut-off file the same way every eiod_* command does, rather than
* reading a global the loader no longer sets
_eiod_cutfile
global EIOD_CUTFILE "`s(path)'"

local FAIL 0

* ============================================================================ *
* PART A. Reference values, hand-typed straight from the printed tables
* ============================================================================ *
di as txt _n "{hline 78}" _n "PART A. Hand-typed reference values" _n "{hline 78}"

use "$EIOD_CUTFILE", clear

* --- Table 3 (absolute thresholds) --- *
assert value == 4.0898629907    if metric=="abs" & indicator=="landtotal"   & demogroup==1
assert value == 5.5735931918    if metric=="abs" & indicator=="landarable"  & demogroup==4
assert value == 6.9692717624    if metric=="abs" & indicator=="landpasture" & demogroup==8
assert value == 0.8845537944    if metric=="abs" & indicator=="ghg"         & demogroup==6
assert value == 0.0267453228    if metric=="abs" & indicator=="eutroph"     & demogroup==4
assert value == 1726.3821057877 if metric=="abs" & indicator=="water"       & demogroup==8
assert value == 1.2844358718e-12 if metric=="abs" & indicator=="biodiv"     & demogroup==4
assert value == 3.6896027444e-13 if metric=="abs" & indicator=="biodiv"     & demogroup==1

* --- Table 4a (total land use) --- *
assert value == 1.1645159358  if metric=="rel" & indicator=="landtotal" & demogroup==1 & percentile==10
assert value == 15.4981270626 if metric=="rel" & indicator=="landtotal" & demogroup==4 & percentile==50
assert value == 30.1963086516 if metric=="rel" & indicator=="landtotal" & demogroup==8 & percentile==90

* --- Table 4b (arable land) --- *
assert value == 1.1010661656 if metric=="rel" & indicator=="landarable" & demogroup==1 & percentile==10
assert value == 2.2621082746 if metric=="rel" & indicator=="landarable" & demogroup==6 & percentile==50

* --- Table 4c (pasture land) --- *
assert value == 0.0634497703 if metric=="rel" & indicator=="landpasture" & demogroup==1 & percentile==10
assert value == 23.2607981018 if metric=="rel" & indicator=="landpasture" & demogroup==8 & percentile==90

* --- Table 4d (GHG) --- *
assert value == 0.8921758398 if metric=="rel" & indicator=="ghg" & demogroup==1 & percentile==10
assert value == 3.1058700138 if metric=="rel" & indicator=="ghg" & demogroup==4 & percentile==10

* --- Table 4e (water) --- *
assert value == 819.3029666619 if metric=="rel" & indicator=="water" & demogroup==7 & percentile==80
assert value == 213.1623613755 if metric=="rel" & indicator=="water" & demogroup==1 & percentile==10

* --- Table 4f (eutrophication): the STORED value is the PRINTED value --- *
* Before 2026-10-14 this row was shipped pre-divided by 1000. It is not any
* more, and must never be again - the conversion belongs in eiod_absolute,
* applied to the user's variable, not to the published cut-off.
assert value == 8.3451357297 if metric=="rel" & indicator=="eutroph" & demogroup==2 & percentile==20
assert value == real(value_published_str)
cap confirm variable scale_to_db_unit
assert _rc != 0

* --- and the unit column distinguishes the two eutrophication tables --- *
assert unit == "kg PO4(3-)eq" if indicator=="eutroph" & metric=="abs"
assert unit == "g PO4(3-)eq"  if indicator=="eutroph" & metric=="rel"

* --- Table 4g (biodiversity) --- *
assert value == 2.0227051058e-13 if metric=="rel" & indicator=="biodiv" & demogroup==1 & percentile==10
assert value == 3.7599901323e-13 if metric=="rel" & indicator=="biodiv" & demogroup==2 & percentile==30
assert value == 6.7861513180e-13 if metric=="rel" & indicator=="biodiv" & demogroup==8 & percentile==30

di as result "PART A passed: 22 hand-typed values match the built dataset exactly"


* ============================================================================ *
* PART B. Tables 5a / 5b reuse the correct source values
* ============================================================================ *
di as txt _n "{hline 78}" _n "PART B. Table 5 cut-offs trace to Tables 3 and 4g" _n "{hline 78}"

* Table 5a prints the ABSOLUTE biodiversity threshold (Table 3) for the six
* groups aged 2+. These are the values printed in the HESD table.
foreach spec in "2 5.7244838747e-13" "3 7.8836516181e-13" "4 1.2844358718e-12" ///
                "6 5.3018709712e-13" "7 7.2382064564e-13" "8 1.0331732910e-12" {
    local g : word 1 of `spec'
    local v : word 2 of `spec'
    assert value == `v' if metric=="abs" & indicator=="biodiv" & demogroup==`g'
}
di as result "  Table 5a cut-offs = Table 3 biodiversity row (6 groups) OK"

* Table 5b prints the 30th-percentile RELATIVE biodiversity benchmark (Table 4g).
foreach spec in "2 3.7599901323e-13" "3 5.1781877527e-13" "4 8.4365094030e-13" ///
                "6 3.4824069682e-13" "7 4.7542425566e-13" "8 6.7861513180e-13" {
    local g : word 1 of `spec'
    local v : word 2 of `spec'
    assert value == `v' if metric=="rel" & indicator=="biodiv" & demogroup==`g' & percentile==30
}
di as result "  Table 5b cut-offs = Table 4g P30 row (6 groups) OK"


* ============================================================================ *
* Build a synthetic test dataset with known answers
* ============================================================================ *
* Pull the biodiversity cut-offs for Male 10+ (group 4) into locals.
qui su value if metric=="abs" & indicator=="biodiv" & demogroup==4, meanonly
local ABS4 = r(mean)
forvalues k = 1/9 {
    qui su value if metric=="rel" & indicator=="biodiv" & demogroup==4 & percentile==`=`k'*10', meanonly
    local P4_`k' = r(mean)
}


* ============================================================================ *
* PART C. Behaviour exactly at a cut-off
* ============================================================================ *
di as txt _n "{hline 78}" _n "PART C. Boundary behaviour" _n "{hline 78}"

* Published cut-offs are strict "<". A diet sitting exactly ON the threshold is
* NOT below it, and a diet exactly on P10 belongs in band 2, not band 1.
clear
set obs 3
gen byte dgroup = 4
gen double bio = .
replace bio = `ABS4' * (1 - 1e-9) in 1      // just below the absolute threshold
replace bio = `ABS4'               in 2      // exactly on it
replace bio = `ABS4' * (1 + 1e-9) in 3      // just above it

eiod_absolute biodiv, value(bio) group(dgroup) generate(a)
assert a == 1 in 1
assert a == 0 in 2      // "<" is strict: on the threshold is not below it
assert a == 0 in 3
di as result "  absolute: strict < at the threshold OK"

clear
set obs 3
gen byte dgroup = 4
gen double bio = .
replace bio = `P4_1' * (1 - 1e-9) in 1
replace bio = `P4_1'               in 2
replace bio = `P4_9'               in 3

eiod_relative biodiv, value(bio) group(dgroup) generate(b)
assert b == 1  in 1     // below P10
assert b == 2  in 2     // exactly P10 -> band 2
assert b == 10 in 3     // exactly P90 -> top band
di as result "  relative: value on P10 -> band 2; value on P90 -> band 10  OK"


* ============================================================================ *
* PART D. Missing-value handling
* ============================================================================ *
di as txt _n "{hline 78}" _n "PART D. Missing values stay missing" _n "{hline 78}"

* In Stata, missing sorts ABOVE every real number. An unguarded `value < thr'
* would code a missing impact as 0 ("exceeds threshold"), and an unguarded
* `value >= P90' would put it in band 10. Both are silent wrong answers.
clear
set obs 4
gen byte   dgroup = 4 in 1/3
replace    dgroup = .  in 4
gen double bio    = `ABS4' / 2 in 1
replace    bio    = .          in 2
replace    bio    = .a         in 3
replace    bio    = `ABS4' / 2 in 4

eiod_absolute biodiv, value(bio) group(dgroup) generate(a)
eiod_relative biodiv, value(bio) group(dgroup) generate(b)

assert a == 1  in 1
assert mi(a)   in 2      // system missing impact
assert mi(a)   in 3      // extended missing impact
assert mi(a)   in 4      // missing demographic group
assert b == 1  in 1
assert mi(b)   in 2
assert mi(b)   in 3
assert mi(b)   in 4
di as result "  missing impact and missing group both propagate to missing  OK"


* ============================================================================ *
* PART E. Every band, for every demographic group
* ============================================================================ *
di as txt _n "{hline 78}" _n "PART E. Band assignment, all 10 bands x 8 groups" _n "{hline 78}"

* For each group, construct a value inside each band and check it lands there.
clear
qui set obs 80
gen byte dgroup   = ceil(_n / 10)
gen byte want     = mod(_n - 1, 10) + 1
gen double bio    = .

frame create cuts
frame cuts {
    qui use "$EIOD_CUTFILE", clear
    qui keep if metric=="rel" & indicator=="biodiv" & !mi(percentile)
    forvalues g = 1/8 {
        forvalues k = 1/9 {
            qui su value if demogroup==`g' & percentile==`=`k'*10', meanonly
            local q`g'_`k' = r(mean)
        }
    }
}
frame drop cuts

forvalues g = 1/8 {
    * band 1: below P10
    qui replace bio = `q`g'_1' * 0.5                      if dgroup==`g' & want==1
    * bands 2-9: midway between consecutive cut-points
    forvalues k = 1/8 {
        qui replace bio = (`q`g'_`k'' + `q`g'_`=`k'+1'') / 2 ///
                                                          if dgroup==`g' & want==`=`k'+1'
    }
    * band 10: at or above P90
    qui replace bio = `q`g'_9' * 1.5                      if dgroup==`g' & want==10
}
assert !mi(bio)

eiod_relative biodiv, value(bio) group(dgroup) generate(got) midpoint(mid)
assert got == want
assert mid == want * 10 - 5
di as result "  all 80 group x band combinations assigned correctly  OK"

* and the band must be monotone in the impact within each group
bysort dgroup (bio): assert got >= got[_n-1] if _n > 1
di as result "  band is monotone non-decreasing in the impact value  OK"


* ============================================================================ *
* PART F. Demographic group boundaries
* ============================================================================ *
di as txt _n "{hline 78}" _n "PART F. Age/sex group boundaries" _n "{hline 78}"

* The paper labels groups "0-1.9", "2-4.9", "5-9.9", "10+". Read as half-open
* intervals, so a child aged 1.95 is in the 0-1.9 group, not unassigned.
clear
input double age byte sexv byte want
 0.00 1 1
 1.90 1 1
 1.95 1 1
 1.999 1 1
 2.00 1 2
 4.90 1 2
 4.999 1 2
 5.00 1 3
 9.999 1 3
10.00 1 4
85.00 1 4
 1.95 2 5
 2.00 2 6
 5.00 2 7
10.00 2 8
end

eiod_demogroup, age(age) sex(sexv) generate(g)
assert g == want
di as result "  15 boundary ages assigned correctly (half-open intervals)  OK"

* age in months
clear
input double agem byte sexv byte want
 23 1 1
 24 1 2
 59 1 2
 60 1 3
119 1 3
120 1 4
end
eiod_demogroup, age(agem) sex(sexv) generate(g) units(months)
assert g == want
di as result "  units(months) conversion correct  OK"

* an unexpected sex code must raise an error, not be silently dropped
clear
set obs 3
gen byte age  = 20
gen byte sexv = 9
capture noisily eiod_demogroup, age(age) sex(sexv) generate(g)
assert _rc == 459
di as result "  unrecognised sex code raises an error rather than dropping  OK"


* ============================================================================ *
* PART G. Composite metric logic (the 2x2 of Tables 5a and 5b)
* ============================================================================ *
di as txt _n "{hline 78}" _n "PART G. HESD / HDLEI category logic" _n "{hline 78}"

clear
set obs 8
gen byte   dgroup = 4
gen double bio = .
gen double gdqs = .
* four cells of the 2x2, for the absolute (HESD) criterion
replace bio = `ABS4' * 0.5 in 1    // sustainable
replace gdqs = 30          in 1    // healthy        -> cat 1
replace bio = `ABS4' * 0.5 in 2
replace gdqs = 10          in 2    // not healthy    -> cat 2
replace bio = `ABS4' * 2   in 3    // not sustainable
replace gdqs = 30          in 3    // healthy        -> cat 3
replace bio = `ABS4' * 2   in 4
replace gdqs = 10          in 4    // not healthy    -> cat 4
* exactly on the GDQS cut-off: 23 counts as healthy ("23 or more")
replace bio = `ABS4' * 0.5 in 5
replace gdqs = 23          in 5    // -> cat 1
replace bio = `ABS4' * 0.5 in 6
replace gdqs = 22.999      in 6    // -> cat 2
* missing inputs
replace bio = .            in 7
replace gdqs = 30          in 7
replace bio = `ABS4' * 0.5 in 8
replace gdqs = .           in 8

eiod_hesd, biodiversity(bio) gdqs(gdqs) group(dgroup)

assert hesd_cat == 1 in 1
assert hesd_cat == 2 in 2
assert hesd_cat == 3 in 3
assert hesd_cat == 4 in 4
assert hesd_cat == 1 in 5
assert hesd_cat == 2 in 6
assert mi(hesd_cat) in 7
assert mi(hesd_cat) in 8

assert hesd == 1 in 1
assert hesd == 0 in 2/4
assert hesd_healthy == 1 in 1
assert hesd_healthy == 0 in 2
assert hesd_envsust == 1 in 1/2
assert hesd_envsust == 0 in 3/4
di as result "  HESD: 4 categories, GDQS>=23 inclusive, missing propagates  OK"

* the dichotomous variable must be exactly "category 1"
assert hesd == (hesd_cat == 1) if !mi(hesd_cat)
di as result "  HESD dichotomous == (category 1)  OK"

* same for HDLEI, against the relative P30 criterion
clear
set obs 4
gen byte   dgroup = 4
gen double bio = .
gen double gdqs = .
replace bio = `P4_3' * 0.5 in 1
replace gdqs = 30          in 1    // -> cat 1
replace bio = `P4_3' * 0.5 in 2
replace gdqs = 10          in 2    // -> cat 2
replace bio = `P4_9' * 1.2 in 3
replace gdqs = 30          in 3    // -> cat 3
replace bio = `P4_9' * 1.2 in 4
replace gdqs = 10          in 4    // -> cat 4

eiod_hdlei, biodiversity(bio) gdqs(gdqs) group(dgroup)
assert hdlei_cat == 1 in 1
assert hdlei_cat == 2 in 2
assert hdlei_cat == 3 in 3
assert hdlei_cat == 4 in 4
assert hdlei == (hdlei_cat == 1) if !mi(hdlei_cat)
di as result "  HDLEI: 4 categories and dichotomous  OK"

* --- age restriction: composites are missing below 2 years ------------------ *
clear
set obs 4
gen byte   dgroup = .
replace    dgroup = 1 in 1          // Male 0-1.9    -> ineligible
replace    dgroup = 5 in 2          // Female 0-1.9  -> ineligible
replace    dgroup = 2 in 3          // Male 2-4.9    -> eligible
replace    dgroup = 6 in 4          // Female 2-4.9  -> eligible
gen double bio  = 1e-14             // comfortably below every cut-off
gen double gdqs = 30

eiod_hesd,  biodiversity(bio) gdqs(gdqs) group(dgroup)
eiod_hdlei, biodiversity(bio) gdqs(gdqs) group(dgroup)
assert mi(hesd)  & mi(hesd_cat)  & mi(hesd_healthy)  & mi(hesd_envsust)   in 1/2
assert mi(hdlei) & mi(hdlei_cat) & mi(hdlei_healthy) & mi(hdlei_lowimpact) in 1/2
assert hesd  == 1 in 3/4
assert hdlei == 1 in 3/4
di as result "  under-2 groups left missing for both composites  OK"


* ============================================================================ *
* PART H. Sub-indicators equal the standalone metrics
* ============================================================================ *
di as txt _n "{hline 78}" _n "PART H. Decomposed sub-indicators match standalone metrics" _n "{hline 78}"

clear
set seed 20261001
qui set obs 4000
gen byte   dgroup = 2 + mod(_n, 3)
qui replace dgroup = dgroup + 4 if mod(_n, 2) == 0
qui replace dgroup = 4 if !inlist(dgroup, 2, 3, 4, 6, 7, 8)
gen double bio  = exp(rnormal(ln(5e-13), 1.1))
gen double gdqs = 15 + 20 * runiform()

eiod_absolute biodiv, value(bio) group(dgroup) generate(standalone_abs)
eiod_relative biodiv, value(bio) group(dgroup) generate(standalone_band) below(30) belowvar(standalone_lt30)
eiod_hesd,  biodiversity(bio) gdqs(gdqs) group(dgroup)
eiod_hdlei, biodiversity(bio) gdqs(gdqs) group(dgroup)

assert hesd_envsust    == standalone_abs
assert hdlei_lowimpact == standalone_lt30
assert hesd_healthy    == hdlei_healthy
di as result "  hesd_envsust == eiod_absolute biodiv            OK"
di as result "  hdlei_lowimpact == eiod_relative biodiv below(30)  OK"
di as result "  the GDQS sub-indicator is identical in both composites  OK"

* the two composites genuinely differ - they are not the same metric
count if hesd != hdlei
di as txt "  HESD and HDLEI disagree on {res}" r(N) "{txt} of 4000 simulated diets"


* ============================================================================ *
* PART I. Cross-table relationship between the two metric families
* ============================================================================ *
di as txt _n "{hline 78}" _n "PART I. Where each absolute threshold sits in the relative distribution" _n "{hline 78}"

use "$EIOD_CUTFILE", clear
keep if demogroup == 4

* the absolute threshold for each indicator
preserve
    keep if metric == "abs"
    keep indicator value
    rename value thr
    isid indicator
    tempfile absthr
    save `absthr'
restore

* against the nine relative cut-points for the same group
keep if metric == "rel" & !mi(percentile)
merge m:1 indicator using `absthr', assert(match) nogen
isid indicator percentile

* how many of P10..P90 does the absolute threshold equal or exceed?
gen byte above = (thr >= value)
bysort indicator: egen byte n_below_thr = total(above)

preserve
    bysort indicator: keep if _n == 1
    gen str24 position = ""
    replace position = "below P10"     if n_below_thr == 0
    replace position = "at/above P90"  if n_below_thr == 9
    replace position = "P" + string(n_below_thr*10) + "-P" + string((n_below_thr+1)*10) ///
        if inrange(n_below_thr, 1, 8)
    list indicator thr position, noobs abbrev(16)

    * This is the claim documented in eiod_relative.ado and progressnote.md:
    * for GHG the absolute threshold is below the whole reference distribution,
    * so even band 1 exceeds the planetary boundary.
    assert n_below_thr == 0 if indicator == "ghg"
    * and for water the threshold is above the whole distribution
    assert n_below_thr == 9 if indicator == "water"
restore
di as result _n "  GHG: absolute threshold lies below band 1 of the reference distribution  OK"
di as result "  Water: absolute threshold lies above band 10  OK"


* ============================================================================ *
* PART J. HDLEI is nested inside HESD
* ============================================================================ *
di as txt _n "{hline 78}" _n "PART J. Nesting of the two composite metrics" _n "{hline 78}"

* For biodiversity, the 30th-percentile relative cut-off is BELOW the absolute
* threshold in every demographic group, by the same factor. Both are the same
* all-population figure scaled by the same energy-requirement weight, so the
* ratio is constant by construction.
*
* Consequence: the HDLEI environmental criterion is strictly more demanding
* than the HESD one, so HDLEI = 1 implies HESD = 1 and HESD prevalence can
* never be lower than HDLEI prevalence. The two metrics are nested, not
* independent -- do not read them as separate dimensions.
use "$EIOD_CUTFILE", clear
keep if indicator == "biodiv"
preserve
    keep if metric == "abs"
    keep demogroup value
    rename value abs_thr
    isid demogroup
    tempfile ab
    save `ab'
restore
keep if metric == "rel" & percentile == 30
keep demogroup value
rename value p30
merge 1:1 demogroup using `ab', assert(match) nogen

assert p30 < abs_thr
gen double ratio = abs_thr / p30
qui su ratio
assert reldif(r(min), r(max)) < 1e-9        // the same ratio in all 8 groups
local r : di %4.2f r(mean)
di as result "  P30 < absolute threshold in all 8 groups; ratio constant at `r'x  OK"

* so the nesting must show up in the data too
clear
set seed 7
qui set obs 3000
gen byte   dgroup = 2 + mod(_n, 3)
qui replace dgroup = dgroup + 4 if mod(_n, 2) == 0
qui replace dgroup = 4 if !inlist(dgroup, 2, 3, 4, 6, 7, 8)
gen double bio  = exp(rnormal(ln(6e-13), 1.2))
gen double gdqs = 12 + 26 * runiform()

eiod_hesd,  biodiversity(bio) gdqs(gdqs) group(dgroup)
eiod_hdlei, biodiversity(bio) gdqs(gdqs) group(dgroup)

assert hesd == 1 if hdlei == 1                 // HDLEI implies HESD
count if hesd == 1 & hdlei == 0                // the gap between the cut-offs
di as result "  HDLEI = 1 implies HESD = 1 for all simulated diets  OK"
di as txt    "  {res}" r(N) "{txt} diets are HESD but not HDLEI (they sit between the two cut-offs)"


* ============================================================================ *
di as result _n(2) "{hline 78}"
di as result "ALL VALIDATION CHECKS PASSED"
di as result "{hline 78}"
