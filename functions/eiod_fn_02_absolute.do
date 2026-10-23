* **************************************************************************** *
* **************************************************************************** *
*                                                                              *
*   eiod_fn_02_absolute.do                                                     *
*   TABLE 3 - ABSOLUTE THRESHOLD METRICS                                       *
*                                                                              *
* **************************************************************************** *
* **************************************************************************** *

/*
  ** DEFINES        eiod_absolute

  ** PURPOSE        Code a one-day diet 1 if its per capita environmental
                    impact falls BELOW the demographic group's share of the
                    per capita daily planetary boundary, and 0 if it does not.

  ** SOURCE         Intake-EIOD-Methods-Paper-Jan2026-Final.pdf
  **                https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf
                      Table 3, p.16  "Cut-Offs by Demographic Group for
                                      Absolute Threshold Metrics"
                      Method, p.3    thresholds follow Moberg et al. (2020)
                                     and Hallstrom et al. (2022), assuming a
                                     7.7 billion population, converted to an
                                     average per capita DAILY threshold.

  ** INTERPRETATION "x% of one-day diets fall below the absolute per capita
                    daily threshold established for <indicator>."

                    This is a pass/fail against a planetary boundary share. It
                    is NOT a statement about how the diet compares with other
                    diets - for that see eiod_relative (Tables 4a-4g).

  ** SYNTAX         eiod_absolute INDICATOR , Value(varname) Group(varname)
                        GENerate(name) [ THRESHvar(name) CUToffs(string) replace ]

  ** INDICATOR      exactly one of
                      landtotal      total land use           m2*year
                      landarable     arable land use          m2*year
                      landpasture    pasture land use         m2*year
                      ghg            greenhouse gas emissions kg CO2eq
                      eutroph        eutrophication potential kg PO4(3-)eq
                      water          water use                litres
                      biodiv         biodiversity loss        PDF*year

  ** OPTIONS        value()      the respondent-day impact total, already summed
                                 across every ingredient consumed that day
                    group()      the 1-8 variable from eiod_demogroup
                    generate()   name for the new 0/1 indicator
                    threshvar()  optional: also store the threshold applied, so
                                 a reader can see which number each respondent
                                 was compared against
                    cutoffs()    path to eiod_cutoffs.dta (otherwise found via
                                 $EIOD_CUTOFFS or the adopath)
                    replace      drop the output variables first if they exist

  ** OUTPUT         generate()   byte 0/1, value-labelled eiod_abs
                                   1 = below threshold
                                   0 = at or above threshold
                                   . = impact or group not observed

  ** RETURNS        r(N)      diets with a non-missing result
                    r(N_miss) diets left missing
                    r(pct)    percent below the threshold
                    r(ind)    indicator name
                    r(unit)   unit of the indicator

  ** STRICT "<"     The published cut-offs carry a "<" sign. A diet sitting
                    EXACTLY on the threshold is therefore NOT below it and is
                    coded 0. See eiod_validate.do Part C.

  ** LAST UPDATE    2026-10-01
*/

* ---------------------------------------------------------------------------- *
capture program drop eiod_absolute
program define eiod_absolute, rclass
    version 18
    syntax namelist(max=1 id="indicator"), ///
             Value(varname numeric) Group(varname numeric) GENerate(name) ///
             [ CUToffs(string) THRESHvar(name) replace strict nocheck ]

    * ======================================================================== *
    * STEP 1. Validate the indicator name
    * ======================================================================== *
    local ind `namelist'
    local ok "landtotal landarable landpasture ghg eutroph water biodiv"
    if !`: list ind in ok' {
        di as error "indicator must be exactly one of:"
        di as error "  `ok'"
        exit 198
    }

    * ======================================================================== *
    * STEP 2. Validate the output names and the demographic group
    * ======================================================================== *
    if "`replace'" != "" {
        capture drop `generate'
        if "`threshvar'" != "" capture drop `threshvar'
    }
    confirm new variable `generate'
    if "`threshvar'" != "" confirm new variable `threshvar'

    qui count if !inrange(`group', 1, 8) & !mi(`group')
    if r(N) {
        di as error "`group' has `r(N)' value(s) outside 1-8"
        di as error "  build the group variable with eiod_demogroup"
        exit 459
    }

    * ======================================================================== *
    * STEP 2b. QC the input BEFORE computing anything
    * ======================================================================== *
    * Storage type, sign, underflow and scale. Integer storage and float
    * underflow are errors; plain float is a note. See eiod_fn_07_check.do for
    * what was measured and why the grading is what it is.
    * `nocheck' creates a local named `check'.
    local qcmode ""
    if "`check'"  != "" local qcmode "nocheck"
    if "`strict'" != "" local qcmode "strict"
    capture confirm variable `value'
    _eiod_precheck `value' "`ind'" "`qcmode'"

    * ======================================================================== *
    * STEP 3. Read the eight thresholds for this indicator
    * ======================================================================== *
    * Read in a temporary frame so the analyst's data in memory is untouched.
    _eiod_cutfile `cutoffs'
    local cutpath `"`s(path)'"'

    tempname cf
    frame create `cf'
    frame `cf' {
        qui use `"`cutpath'"', clear
        qui keep if metric == "abs" & indicator == "`ind'"

        if _N != 8 {
            di as error "expected 8 absolute thresholds for `ind', found `=_N' in"
            di as error `"  `cutpath'"'
            exit 459
        }
        qui isid demogroup
        sort demogroup
        local unit = unit[1]

        forvalues g = 1/8 {
            qui su value if demogroup == `g', meanonly
            local thr`g' = r(mean)
        }
    }
    frame drop `cf'

    * ======================================================================== *
    * STEP 3b. No unit conversion - deliberately, and this is a change
    * ======================================================================== *
    /*
       Between July and October 2026 this command divided eutrophication
       values by 1000 before comparing, and kept the converted variable as
       `<yourvar>_kg' so the step was visible.

       THAT IS GONE. Intake confirmed by email in October 2026 that BOTH
       Table 3 and Table 4f are expressed in grams PO4(3-)eq, and supplied
       corrected Table 3 eutrophication thresholds - the published PDF prints
       those eight cells in kilograms. The corrected values ship in
       eiod_cutoffs.dta and are flagged there by value_source.

       So every indicator is now on a single unit across both tables and
       nothing is converted anywhere. Supply eutrophication in GRAMS, as the
       EIOF database gives it to you, and pass it straight in.

       The quantities did not change - the corrected thresholds are the
       printed ones x1000 - so no classification moves. Tested on 400,000
       simulated gram-scale values: old and new behaviour agree everywhere
       except within about one ULP of a cut-off, where the new path is the
       more exact because it no longer divides before comparing.

       IF YOU ARE REVISITING AN OLDER SCRIPT that divided eutrophication by
       1000 before calling this command, remove the division.

       See readme/01_eiod_build_cutoffs.md and readme/03_eiod_absolute.md.
    */


    * ======================================================================== *
    * STEP 4. Apply the threshold, group by group
    * ======================================================================== *
    * The !mi() guard is load-bearing, not defensive padding. In Stata missing
    * sorts ABOVE every real number, so `. < threshold' evaluates to 0 - a
    * respondent with no impact data would be silently coded as EXCEEDING the
    * threshold. Guarding leaves them missing instead.
    qui gen byte `generate' = .
    if "`threshvar'" != "" qui gen double `threshvar' = .

    forvalues g = 1/8 {
        qui replace `generate' = (`value' < `thr`g'') ///
            if `group' == `g' & !mi(`value')

        if "`threshvar'" != "" {
            qui replace `threshvar' = `thr`g'' if `group' == `g'
        }
    }

    * ======================================================================== *
    * STEP 5. Label
    * ======================================================================== *
    lab def eiod_abs 0 "At or above threshold" 1 "Below threshold", replace
    lab val `generate' eiod_abs
    lab var `generate' "`ind': below absolute per capita daily threshold"
    if "`threshvar'" != "" {
        lab var `threshvar' "`ind': absolute threshold applied (`unit')"
        /*
           Display at the PUBLISHED precision.

           The value stored is already the exact double nearest the number
           printed in the paper - storage was never the issue. But Stata's
           default %10.0g shows only about 8 significant digits, so
           14.2377570161 appeared as 14.237757 and looked as though the
           package had rounded the guideline. It had not.

           %18.14g shows every digit the paper prints: the widest cut-off in
           the whole table needs 14 significant digits, and g-format drops
           trailing zeros, so shorter values are not padded.
        */
        format `threshvar' %18.14g
    }

    * ======================================================================== *
    * STEP 6. Report and return
    * ======================================================================== *
    qui count if mi(`generate')
    local nmiss = r(N)
    qui count if !mi(`generate')
    local nobs = r(N)
    local pct = .
    if `nobs' {
        qui su `generate', meanonly
        local pct = r(mean) * 100
    }

    di as txt _n "{bf:Table 3 - absolute threshold}  `ind' (`unit' per capita per day)"
    di as txt    "  created {res}`generate'{txt}" ///
                 cond(`nmiss', " ; {res}`nmiss'{txt} missing of `=`nobs'+`nmiss''", "")
    if "`ind'" == "eutroph" {
        di as txt "  {bf:note:} the Table 3 eutrophication thresholds were CORRECTED BY INTAKE"
        di as txt "         in Oct 2026 and DIFFER FROM THE PUBLISHED PDF, which prints them"
        di as txt "         in kg. Both tables are in grams; supply grams, convert nothing."
    }
    if `nobs' {
        di as txt "  below threshold: {res}" %5.1f `pct' "%{txt} of `nobs' diets"
    }

    return scalar N      = `nobs'
    return scalar N_miss = `nmiss'
    return scalar pct    = `pct'
    return local  ind    "`ind'"
    return local  unit   "`unit'"
end
* ---------------------------------------------------------------------------- *
