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
    * STEP 3b. Put the user's values on the unit THIS table is printed in
    * ======================================================================== *
    /*
       SIX of the seven indicators need nothing here: the EIOF database, the
       methods paper and both cut-off tables all agree.

       EUTROPHICATION DOES NOT.

         - the EIOF country databases report it as `Eutr. (g PO43-e/kg)', so a
           respondent total built from them is in GRAMS;
         - Table 4f is printed in grams, so eiod_relative needs nothing;
         - Table 3 is printed in KILOGRAMS - the methods paper states this on
           p.29 - so the absolute metric needs the user's value / 1000.

       THE CONVERSION IS APPLIED TO THE USER'S VALUE, NEVER TO THE PUBLISHED
       CUT-OFF. eiod_cutoffs.dta holds exactly what the paper prints, for all
       616 rows, and can be checked line by line against the PDF. Before
       2026-10-14 the 80 Table 4f rows were stored pre-divided and matched
       nothing in the source document.

       The unit reading is an INFERENCE and is not yet confirmed by Intake.
       See readme/03_eiod_absolute.md.

       THE CONVERTED VALUE IS KEPT, not thrown away in a tempvar.

       A conversion the user cannot see is a conversion the user has to take on
       trust. So when one happens, the command leaves `<yourvar>_kg' behind -
       for eutr_ado you get eutr_ado_kg - and you can check the whole chain by
       eye in one `list':

           . list eutr_ado eutr_ado_kg thr_eutroph abs_eutroph in 1/5

       g -> kg -> compared against the published Table 3 threshold -> result.
       Nothing is hidden inside the command.
    */
    local convfac  = 1
    local convnote ""
    local convvar  ""
    if "`ind'" == "eutroph" {
        local convfac = 0.001
        local convnote "eutroph: your values divided by 1000 (g -> kg PO4(3-)eq) to match Table 3"
        local convvar "`value'_kg"

        * a Stata variable name is at most 32 characters
        if length("`convvar'") > 32 {
            di as error "cannot create the converted variable `convvar': name too long"
            di as error "  rename `value' to something shorter (<= 29 characters)"
            exit 198
        }
        if "`replace'" != "" capture drop `convvar'
        confirm new variable `convvar'
    }

    * The comparison uses the kept variable when there is one, so the number
    * you can see is literally the number that was tested - not a parallel
    * copy that could drift from it.
    tempvar vtmp
    if "`convvar'" != "" {
        qui gen double `convvar' = `value' * `convfac'
        local vcmp `convvar'
    }
    else {
        qui gen double `vtmp' = `value' * `convfac'
        local vcmp `vtmp'
    }

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
        qui replace `generate' = (`vcmp' < `thr`g'') ///
            if `group' == `g' & !mi(`vcmp')

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
    if "`convvar'" != "" {
        lab var `convvar' "`value' converted g -> kg PO4(3-)eq, as compared to Table 3"
        format `convvar' %18.14g
    }
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
    if "`convnote'" != "" {
        di as txt "  {bf:unit:} `convnote'"
        di as txt "         supply this indicator in GRAMS, as the EIOF database reports it"
        di as txt "         the published cut-off is NOT altered - see readme/03_eiod_absolute.md"
        di as txt "  created {res}`convvar'{txt} - the converted value that was actually compared"
        di as txt "         check it:  {inp}list `value' `convvar'" ///
                  cond("`threshvar'" != "", " `threshvar'", "") " `generate' in 1/5{txt}"
    }
    if `nobs' {
        di as txt "  below threshold: {res}" %5.1f `pct' "%{txt} of `nobs' diets"
    }

    return scalar N      = `nobs'
    return scalar N_miss = `nmiss'
    return scalar pct    = `pct'
    return scalar convfac = `convfac'
    return local  convvar "`convvar'"
    return local  ind    "`ind'"
    return local  unit   "`unit'"
end
* ---------------------------------------------------------------------------- *
