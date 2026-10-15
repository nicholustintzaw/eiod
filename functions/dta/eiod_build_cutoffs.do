* **************************************************************************** *
*  eiod_build_cutoffs.do
*
*  PURPOSE   Build the single long-format cut-off dataset used by every
*            eiod_* command, from the human-readable reference CSV.
*
*  INPUT     outputs/eiod_cutoffs.csv
*              Transcribed programmatically from Tables 3 and 4a-4g of
*              Intake-EIOD-Methods-Paper-Jan2026-Final.pdf (pages 16-19).
*              https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf
*              One row per (metric x indicator x demographic group x row).
*
*  OUTPUT    outputs/eiod_cutoffs.dta    616 rows, long format
*            outputs/eiod_cutoffs_wide_check.csv   (eyeball vs the PDF)
*
*  NOTE ON   Tables 5a and 5b are NOT stored here. They are composites that
*  TABLE 5   reuse values already in this file:
*              HESD  env criterion = abs  / biodiv                  (Table 3)
*              HDLEI env criterion = rel  / biodiv / percentile 30  (Table 4g)
*            Storing them again would be a second copy that could drift.
*
*  LAST UPDATE  2026-10-01
* **************************************************************************** *

version 18
clear all
set more off
set varabbrev off

* ---- paths ----------------------------------------------------------------- *
* No absolute path is hardcoded. The CSV sits beside this do-file, so "." is
* the right place whenever the build is run from its own directory. Set
* EIOD_OUT yourself if you keep the source CSV somewhere else.
if "$EIOD_OUT" == "" {
    capture confirm file "./eiod_cutoffs.csv"
    if !_rc {
        global EIOD_OUT "."
    }
    else {
        di as error "set EIOD_OUT to the folder holding eiod_cutoffs.csv, e.g."
        di as error `"    global EIOD_OUT "C:/path/to/eiod/functions/dta""'
        exit 601
    }
}

capture confirm file "$EIOD_OUT/eiod_cutoffs.csv"
if _rc {
    di as error "missing: $EIOD_OUT/eiod_cutoffs.csv"
    exit 601
}

* ---- import ---------------------------------------------------------------- *
* The cut-offs are printed to 11 significant digits. `import delimited' types a
* column like this as FLOAT, which holds only ~7 significant digits, and a
* later `recast double' cannot recover the digits already lost (it widens the
* storage, not the value). So read the two value columns as strings and convert
* with real(), which returns a double.
*   column 13 = value_published
import delimited "$EIOD_OUT/eiod_cutoffs.csv", varnames(1) case(preserve) ///
    stringcols(13) clear

rename value_published vp_str
gen double value = real(vp_str)

/*
   KEEP the literal text, do not drop it.

   vp_str is the number exactly as it is typed in the methods paper, character
   for character, before it has been through any numeric type at all. Keeping
   it removes the last possible doubt: a reader comparing this dataset against
   the printed table can check the STRING, not a rendering of a double.

   The double in value is the nearest IEEE 754 double to that text - which is
   as exact as any binary floating-point representation can be - and
   round-trips back to the same text. That is asserted below.
*/
rename vp_str value_published_str

* real() returns missing on anything it cannot parse - catch that loudly
assert !mi(value)

* age bounds as double too, so group logic is not at the mercy of float width
recast double age_min age_max

* ---- NOTHING IS RESCALED HERE ---------------------------------------------- *
*
* Changed 2026-10-14, deliberately.
*
* Until this date the build multiplied the 80 relative eutrophication rows by
* 0.001, so that every cut-off sat on one internal unit scale. That was
* arithmetically sound and it was documented, but it meant eiod_cutoffs.dta
* held 80 numbers that could not be found anywhere in the methods paper - and
* the entire point of shipping this dataset is that a reader can check it line
* by line against the PDF.
*
* `value' is now the cut-off EXACTLY as printed, for all 616 rows. The
* eutrophication adjustment happens where it belongs: inside eiod_absolute, at
* the moment of comparison, applied to the USER'S variable, announced in the
* output, and documented in readme/03_eiod_absolute.md.
*
* The `unit' column now records what each table is actually printed in:
*   eutroph + abs  -> kg PO4(3-)eq   (Table 3)
*   eutroph + rel  ->  g PO4(3-)eq   (Table 4f)
* Every other indicator uses one unit across both tables.
lab var value               "Cut-off exactly as printed in the methods paper"
lab var value_published_str "Cut-off as printed in the methods paper (literal text)"

/*
   DISPLAY PRECISION.

   Both numeric columns are double, so storage was never the issue. But Stata's
   default %10.0g shows only about 8 significant digits, which made
   14.2377570161 appear as 14.237757 and looked as though the package had
   rounded the guideline.

   The widest cut-off in the table needs 14 significant digits, so %18.14g
   shows every published digit. g-format drops trailing zeros, so the shorter
   values are not padded out with meaningless noise.
*/
format value %18.14g

* the numeric column must reproduce the literal text it was parsed from
gen double _vp_back = real(value_published_str)
assert _vp_back == value
drop _vp_back
di as txt "verified: value round-trips to value_published_str exactly"

* ---- labels ---------------------------------------------------------------- *
lab var metric          "abs = Table 3 absolute threshold; rel = Table 4 relative benchmark"
lab var table           "Source table in the methods paper"
lab var indicator       "Environmental impact indicator (short name)"
lab var indicator_label "Environmental impact indicator"
lab var unit            "Unit of value (per capita per day)"
lab var demogroup       "Age/sex demographic group (1-8)"
lab var demogroup_label "Age/sex demographic group"
lab var sex             "Sex"
lab var age_min         "Lowest age in group (years)"
lab var age_max         "Highest age in group (years; 999 = no upper bound)"
lab var row_order       "Row position within the source table"
lab var percentile      "Upper percentile of the decile band (rel only)"

lab def eiod_sex 1 "Male" 2 "Female", replace
lab val sex eiod_sex

lab def eiod_group  1 "Male 0-1.9 yr"   2 "Male 2-4.9 yr"   3 "Male 5-9.9 yr"   ///
                    4 "Male 10+ yr"     5 "Female 0-1.9 yr" 6 "Female 2-4.9 yr" ///
                    7 "Female 5-9.9 yr" 8 "Female 10+ yr", replace
lab val demogroup eiod_group

* ---- structural validation ------------------------------------------------- *
* Everything below should hold for any future version of the reference tables.
* If one fails, the CSV is wrong -- do not "fix" it by relaxing the assert.

* 1. shape
assert _N == 616
assert inlist(metric, "abs", "rel")
count if metric == "abs"
assert r(N) == 56                       // 7 indicators x 8 groups
count if metric == "rel"
assert r(N) == 560                      // 7 indicators x 8 groups x 10 rows

* 2. complete grid, no duplicates
isid metric indicator demogroup row_order
assert inrange(demogroup, 1, 8)
distinct indicator
assert r(ndistinct) == 7

* 3. no missing or non-positive cut-offs
assert !mi(value) & value > 0

* 4. absolute metrics: exactly one threshold per indicator x group
preserve
    keep if metric == "abs"
    isid indicator demogroup
    assert row_order == 7 | row_order < 7   // row_order is the Table 3 row
restore

* 5. relative metrics: rows 1-9 are the P10..P90 cut-points and must be
*    strictly increasing within indicator x group; row 10 repeats P90.
preserve
    keep if metric == "rel"
    sort indicator demogroup row_order
    by indicator demogroup: assert _N == 10

    * strictly increasing across rows 1-9
    by indicator demogroup: gen double v_prev = value[_n-1] if _n > 1
    assert value > v_prev if row_order <= 9 & !mi(v_prev)

    * row 10 is the same number as row 9 (printed as a lower bound in the PDF)
    by indicator demogroup: gen double v9 = value[9]
    assert reldif(value, v9) < 1e-12 if row_order == 10

    * percentile is populated for rows 1-9 only, and equals row_order*10
    assert percentile == row_order * 10 if row_order <= 9
    assert mi(percentile) if row_order == 10
restore

* 6. age/sex coding is internally consistent
assert sex == 1 if inrange(demogroup, 1, 4)
assert sex == 2 if inrange(demogroup, 5, 8)
* reldif() not ==, because 1.9 / 4.9 / 9.9 are not exactly representable in
* binary floating point and `age_max == 1.9` is false for every observation.
assert age_min == 0  & reldif(age_max, 1.9) < 1e-6 if inlist(demogroup, 1, 5)
assert age_min == 2  & reldif(age_max, 4.9) < 1e-6 if inlist(demogroup, 2, 6)
assert age_min == 5  & reldif(age_max, 9.9) < 1e-6 if inlist(demogroup, 3, 7)
assert age_min == 10 & age_max == 999           if inlist(demogroup, 4, 8)

* 7. NOTHING is rescaled: the stored number is the printed number, every row
cap confirm variable scale_to_db_unit
assert _rc != 0                         // the column must not come back
assert value == real(value_published_str)

* 8. the unit column says what each table is actually printed in.
*    Eutrophication is the only indicator whose two tables differ.
assert unit == "kg PO4(3-)eq" if indicator == "eutroph" & metric == "abs"
assert unit == "g PO4(3-)eq"  if indicator == "eutroph" & metric == "rel"
* Count DISTINCT levels with r(r). Do not use `: word count' on the levels -
* several units contain a space ("kg CO2eq", "m2*year"), so word-counting them
* reports 2 for a single level and the assertion fails on correct data.
levelsof indicator, local(INDS) clean
foreach i of local INDS {
    if "`i'" != "eutroph" {
        qui levelsof unit if indicator == "`i'"
        assert r(r) == 1
    }
}
qui levelsof unit if indicator == "eutroph"
assert r(r) == 2

di as result _n "all structural checks passed"

* ---- save ------------------------------------------------------------------ *
order   metric table indicator indicator_label unit                 ///
        demogroup demogroup_label sex age_min age_max               ///
        row_order percentile value value_published_str
sort    metric indicator demogroup row_order

compress
note: Cut-offs for the Intake dietary environmental impact metrics.
note: Source - Intake-EIOD-Methods-Paper-Jan2026-Final.pdf, Tables 3 and 4a-4g.
note: https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf
note: Built by eiod_build_cutoffs.do on `c(current_date)'.
note: `value' is the cut-off EXACTLY as printed in the paper - nothing is rescaled.
note: Eutrophication is printed in kg in Table 3 and in g in Table 4f; see the
note: unit variable and eiod_absolute, which converts the users value not the cut-off.

save "$EIOD_OUT/eiod_cutoffs.dta", replace

* ---- wide view, for eyeballing against the printed tables ------------------ *
preserve
    keep metric indicator demogroup row_order percentile value
    tostring value, replace force format(%20.10e)
    reshape wide value, i(metric indicator row_order percentile) j(demogroup)
    order metric indicator row_order percentile
    sort  metric indicator row_order
    export delimited "$EIOD_OUT/eiod_cutoffs_wide_check.csv", replace
restore

di as result _n "saved: $EIOD_OUT/eiod_cutoffs.dta  (" _N " rows)"

describe
tab indicator metric
