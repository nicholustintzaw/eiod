* **************************************************************************** *
* **************************************************************************** *
*                                                                              *
*   eiod_fn_03_relative.do                                                     *
*   TABLES 4a-4g - RELATIVE BENCHMARK METRICS                                  *
*                                                                              *
* **************************************************************************** *
* **************************************************************************** *

/*
  ** DEFINES        eiod_relative

  ** PURPOSE        Place a one-day diet in one of ten decile bands of the
                    GLOBAL REFERENCE DISTRIBUTION of per capita daily dietary
                    environmental impacts.

  ** SOURCE         Intake-EIOD-Methods-Paper-Jan2026-Final.pdf
  **                https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf
                      Table 4a p.16 total land use      Table 4e p.18 water use
                      Table 4b p.17 arable land use     Table 4f p.19 eutrophication
                      Table 4c p.17 pasture land use    Table 4g p.19 biodiversity loss
                      Table 4d p.18 greenhouse gases
                      Method, p.3

  ** WHAT THE       The reference distribution is NOT the distribution of the
     COMPARISON     data in memory. It is a FIXED EXTERNAL STANDARD, identical
     IS AGAINST     for every analysis anywhere in the world, built by Intake as:
                      1. per-country average dietary impact per person per day
                         at each decile, from the Planet-Based Diets Database
                         (WWF 2020);
                      2. population-weighted to a global percentile distribution
                         using 2010 country populations (UN 2025);
                      3. scaled to each demographic group by its share of
                         average energy requirements.

                    DO NOT compute this with xtile, pctile or egen cut. Those
                    rank your sample against ITSELF and will put roughly 10% of
                    observations in every band by construction. That is a
                    different statistic with no cross-country meaning.

                    If your whole sample has low impacts, your whole sample
                    lands in low bands. That is the intended behaviour and the
                    reason the metric is comparable across countries and years.

  ** A LOW BAND IS NOT EVIDENCE OF SUSTAINABILITY.
                    The reference distribution describes diets as they are, not
                    as they would need to be. For greenhouse gas emissions the
                    Table 3 absolute planetary-boundary threshold lies BELOW
                    the 10th percentile of the reference distribution - so a
                    diet in band 1, the lowest band, still exceeds the
                    planetary boundary. For water use the threshold sits ABOVE
                    the 90th percentile, so essentially every diet passes.
                    Report the two metric families together, never one as a
                    proxy for the other. See eiod_validate.do Part I.

  ** BAND           row 1-9 of each table carry the P10..P90 cut-points;
     DEFINITION     row 10 repeats the P90 value as a lower bound.
                        band  1 : impact <  P10
                        band  2 : P10 <= impact < P20
                        ...
                        band  9 : P80 <= impact < P90
                        band 10 : impact >= P90
                    The inequality is strict, so a diet exactly on P10 belongs
                    in band 2, not band 1. See eiod_validate.do Part C.

  ** SYNTAX         eiod_relative INDICATOR , Value(varname) Group(varname)
                        GENerate(name)
                        [ MIDpoint(name) BELow(#) BELOWvar(name)
                          CUToffs(string) replace ]

  ** INDICATOR      landtotal landarable landpasture ghg eutroph water biodiv
                    (same set and units as eiod_absolute)

  ** OPTIONS        value()      respondent-day impact total
                    group()      the 1-8 variable from eiod_demogroup
                    generate()   name for the new 1-10 band variable
                    midpoint()   optional band midpoint (5,15,...,95) for
                                 reporting a mean position - see the caution below
                    below(#)     optional 0/1 flag for "below the #th percentile";
                                 # must be a multiple of 10 from 10 to 90.
                                 below(30) is the HDLEI environmental criterion.
                    belowvar()   name for that flag (default generate()_lt#)
                    cutoffs()    path to eiod_cutoffs.dta
                    replace      drop the output variables first if they exist

  ** REPORTING      The paper gives two forms (p.3-4):
                      distribution  "x% of one-day diets fall between the 10th
                                     and 20th percentile globally"  -> tab the band
                      mean position "the mean relative benchmark percentile is
                                     between the 10th and 20th percentile"
                                                                    -> use midpoint()

                    CAUTION ON THE MEAN. Averaging the band index treats the
                    bands as equally spaced on the impact scale, and they are
                    not. In Table 4c the P10-P20 gap is 0.002 m2*year while the
                    P80-P90 gap is 1.5 m2*year. The mean band is a legitimate
                    summary of POSITION IN THE REFERENCE DISTRIBUTION; it is not
                    a summary of impact. For a mean impact, average the impact
                    variable itself.

  ** STATED         The reference distribution is built from Food Balance Sheet
     LIMITATION     data - country-level availability averages, not individual
                    consumption (paper p.5). It captures variation BETWEEN
                    COUNTRIES, not between people or between days. A band is
                    therefore a statement about position relative to national
                    average availability patterns, not relative to other
                    individuals. Worth a sentence in any methods section.

  ** LAST UPDATE    2026-10-01
*/

* ---------------------------------------------------------------------------- *
capture program drop eiod_relative
program define eiod_relative, rclass
    version 18
    syntax namelist(max=1 id="indicator"), ///
             Value(varname numeric) Group(varname numeric) GENerate(name) ///
             [ MIDpoint(name) BELow(numlist integer min=1 max=1 >=10 <=90) ///
               BELOWvar(name) CUTVar(name) CUToffs(string) replace strict nocheck ]

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
    * STEP 2. Validate the options and output names
    * ======================================================================== *
    if "`below'" != "" {
        if mod(`below', 10) {
            di as error "below() must be a multiple of 10 between 10 and 90"
            di as error "  the published cut-points are deciles only"
            exit 198
        }
        if "`belowvar'" == "" local belowvar "`generate'_lt`below'"
    }

    if "`replace'" != "" {
        capture drop `generate'
        if "`midpoint'" != "" capture drop `midpoint'
        if "`belowvar'" != "" capture drop `belowvar'
        if "`cutvar'"   != "" capture drop `cutvar'
    }
    confirm new variable `generate'
    if "`midpoint'" != "" confirm new variable `midpoint'
    if "`belowvar'" != "" confirm new variable `belowvar'
    if "`cutvar'"   != "" confirm new variable `cutvar'

    qui count if !inrange(`group', 1, 8) & !mi(`group')
    if r(N) {
        di as error "`group' has `r(N)' value(s) outside 1-8"
        di as error "  build the group variable with eiod_demogroup"
        exit 459
    }

    * ======================================================================== *
    * STEP 2b. QC the input BEFORE computing anything
    * ======================================================================== *
    * Same graded check as eiod_absolute. `nocheck' creates a local `check'.
    local qcmode ""
    if "`check'"  != "" local qcmode "nocheck"
    if "`strict'" != "" local qcmode "strict"
    _eiod_precheck `value' "`ind'" "`qcmode'"

    * ======================================================================== *
    * STEP 3. Read the nine cut-points (P10..P90) for each of the eight groups
    * ======================================================================== *
    * 8 groups x 9 cut-points = 72 rows. Row 10 of each table is excluded here
    * because it repeats P90 as a lower bound and is not a separate cut-point.
    _eiod_cutfile `cutoffs'
    local cutpath `"`s(path)'"'

    tempname cf
    frame create `cf'
    frame `cf' {
        qui use `"`cutpath'"', clear
        qui keep if metric == "rel" & indicator == "`ind'" & !mi(percentile)

        if _N != 72 {
            di as error "expected 72 relative cut-points for `ind' (8 groups x P10-P90), found `=_N'"
            di as error `"  in `cutpath'"'
            exit 459
        }
        qui isid demogroup percentile
        sort demogroup percentile
        local unit = unit[1]

        forvalues g = 1/8 {
            forvalues k = 1/9 {
                qui su value if demogroup == `g' & percentile == `=`k'*10', meanonly
                local p`g'_`k' = r(mean)
            }
        }
    }
    frame drop `cf'

    * ======================================================================== *
    * STEP 4. Assign the decile band
    * ======================================================================== *
    * Method: start at band 1, then add 1 for every cut-point the impact equals
    * or exceeds. A diet below P10 clears none and stays in band 1; a diet at or
    * above P90 clears all nine and lands in band 10.
    *
    * The !mi() guard is load-bearing. Missing sorts above every real number in
    * Stata, so an unguarded `value >= P90' would place every respondent with no
    * impact data in band 10 - the highest-impact band - silently.
    qui gen byte `generate' = .

    forvalues g = 1/8 {
        qui replace `generate' = 1 if `group' == `g' & !mi(`value')

        forvalues k = 1/9 {
            qui replace `generate' = `generate' + 1 ///
                if `group' == `g' & !mi(`value') & `value' >= `p`g'_`k''
        }
    }

    * ---- optional: the cut-point this diet was actually compared against ---- *
    /*
       The parallel of threshvar() in eiod_absolute, and there for the same
       reason: so a reader can see the number without opening the cut-off file.
       It holds the LOWER bound of the assigned band - that is, the highest
       published percentile the value cleared. Band 1 has no lower bound and is
       left missing, which is correct rather than a gap: nothing is published
       below P10.
    */
    if "`cutvar'" != "" {
        qui gen double `cutvar' = .
        forvalues g = 1/8 {
            forvalues k = 1/9 {
                qui replace `cutvar' = `p`g'_`k'' ///
                    if `group' == `g' & `generate' == `=`k'+1'
            }
        }
        lab var `cutvar' "`ind': lower cut-point of the assigned band (`unit')"
        * published precision - see the note in eiod_fn_02_absolute.do
        format `cutvar' %18.14g
    }

    * ======================================================================== *
    * STEP 5. Label the bands
    * ======================================================================== *
    lab def eiod_band  1 "< 10th pctile"        2 "10th to <20th"  3 "20th to <30th"  ///
                       4 "30th to <40th"        5 "40th to <50th"  6 "50th to <60th"  ///
                       7 "60th to <70th"        8 "70th to <80th"  9 "80th to <90th"  ///
                      10 "90th to 100th pctile", replace
    lab val `generate' eiod_band
    lab var `generate' "`ind': relative benchmark decile band (global reference)"

    * ======================================================================== *
    * STEP 6. Optional band midpoint, for reporting a mean position
    * ======================================================================== *
    if "`midpoint'" != "" {
        qui gen byte `midpoint' = `generate' * 10 - 5
        lab var `midpoint' "`ind': band midpoint percentile (see note on means)"
    }

    * ======================================================================== *
    * STEP 7. Optional below-percentile flag
    * ======================================================================== *
    * below(30) reproduces the environmental criterion of the HDLEI metric
    * (Table 5b). Band k covers percentiles up to k*10, so "below the Nth
    * percentile" is "band <= N/10".
    if "`below'" != "" {
        local kband = `below' / 10
        qui gen byte `belowvar' = (`generate' <= `kband') if !mi(`generate')

        lab def eiod_lt 0 "At or above" 1 "Below", replace
        lab val `belowvar' eiod_lt
        lab var `belowvar' "`ind': below P`below' of the global reference distribution"
    }

    * ======================================================================== *
    * STEP 8. Report and return
    * ======================================================================== *
    qui count if mi(`generate')
    local nmiss = r(N)
    qui count if !mi(`generate')
    local nobs = r(N)

    di as txt _n "{bf:Table 4 - relative benchmark}  `ind' (`unit' per capita per day)"
    di as txt    "  created {res}`generate'{txt}" ///
                 cond(`nmiss', " ; {res}`nmiss'{txt} missing of `=`nobs'+`nmiss''", "")
    if "`below'" != "" & `nobs' {
        qui su `belowvar', meanonly
        di as txt "  below P`below': {res}" %5.1f `=r(mean)*100' "%{txt} of `nobs' diets"
    }
    if `nobs' {
        qui su `generate', meanonly
        di as txt "  mean band: {res}" %4.2f r(mean) ///
                  "{txt}  (midpoint of the " %4.1f `=r(mean)*10-5' "th percentile)"
    }

    return scalar N      = `nobs'
    return scalar N_miss = `nmiss'
    return local  ind    "`ind'"
    return local  unit   "`unit'"
end
* ---------------------------------------------------------------------------- *
