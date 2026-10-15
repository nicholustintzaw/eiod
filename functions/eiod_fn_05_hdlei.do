* **************************************************************************** *
* **************************************************************************** *
*                                                                              *
*   eiod_fn_05_hdlei.do                                                        *
*   TABLE 5b - HEALTHY DIET WITH LOW ENVIRONMENTAL IMPACTS (HDLEI)             *
*                                                                              *
* **************************************************************************** *
* **************************************************************************** *

/*
  ** DEFINES        eiod_hdlei

  ** PURPOSE        Composite metric combining a diet-quality criterion with a
                    RELATIVE low-impact criterion, and - as requested -
                    returning each criterion as its own sub-indicator alongside
                    the combined measure.

  ** SOURCE         Intake-EIOD-Methods-Paper-Jan2026-Final.pdf
                      Table 5b, p.20
                      Method,   p.4
                      Annex 1 Part II, p.17

  ** THE TWO        healthy      GDQS >= 23                     (same as HESD)
     CRITERIA       low impact   biodiversity loss < the 30th percentile of the
                                 Table 4g RELATIVE benchmark distribution

  ** THE ONLY       HESD tests biodiversity against the ABSOLUTE planetary
     DIFFERENCE     boundary share (Table 3).
     FROM HESD      HDLEI tests it against a POSITION in the global reference
                    distribution (Table 4g, P30).

                    The diet-quality criterion is identical in both.

  ** THE TWO        For biodiversity the relative P30 cut-off is BELOW the
     METRICS ARE    absolute threshold in every one of the eight demographic
     NESTED         groups, by a constant factor of 1.52x. Both are the same
                    all-population figure scaled by the same energy-requirement
                    weight, so the ratio is constant by construction, not by
                    coincidence.

                    CONSEQUENCE: the HDLEI environmental criterion is strictly
                    more demanding than the HESD one, so

                        hdlei == 1  implies  hesd == 1

                    and HESD prevalence can never fall below HDLEI prevalence.
                    Reporting both is still informative - the gap between them
                    is the share of diets sitting between the two cut-offs -
                    but they are NOT two independent dimensions and must not be
                    presented as a 2x2. Asserted in eiod_validate.do Part J.

  ** SYNTAX         eiod_hdlei , BIODiversity(varname) GDQS(varname)
                        Group(varname)
                        [ PREfix(name) GDQScut(#) PERCentile(#)
                          CUToffs(string) replace ]

  ** OPTIONS        biodiversity()  respondent-day biodiversity loss (PDF*year)
                    gdqs()          Global Diet Quality Score
                    group()         the 1-8 variable from eiod_demogroup
                    prefix()        stub for the output names (default hdlei)
                    gdqscut()       GDQS threshold (default 23)
                    percentile()    relative cut-off (default 30, as published;
                                    exposed for sensitivity analysis only -
                                    anything other than 30 is NOT the HDLEI
                                    metric and must be labelled as such)
                    cutoffs()       path to eiod_cutoffs.dta
                    replace         drop the output variables first

  ** OUTPUT         FOUR variables. With the default prefix:

                      hdlei_healthy    0/1  GDQS criterion alone
                                            <-- DECOMPOSED SUB-INDICATOR
                      hdlei_lowimpact  0/1  biodiversity criterion alone
                                            <-- DECOMPOSED SUB-INDICATOR
                      hdlei_cat        1-4  the four categories of Table 5b
                      hdlei            0/1  dichotomous: category 1 vs all else

                    Category coding follows the printed ROW ORDER of Table 5b:
                      1  Healthy with low environmental impacts
                      2  Not healthy but low environmental impacts
                      3  Healthy but not low environmental impacts
                      4  Not healthy and not low environmental impacts

  ** NO DUPLICATED  hdlei_lowimpact is produced by CALLING eiod_relative with
     LOGIC          below(30) rather than by re-implementing the band logic. It
                    is therefore identical, by construction, to the standalone
                    Table 4g result. Asserted in eiod_validate.do Part H.

  ** AGE            As for HESD: restricted to ages 2 and older (paper p.4), so
     RESTRICTION    all four variables are left MISSING for demographic groups
                    1 and 5 (Male/Female 0-1.9 yr).

  ** LAST UPDATE    2026-10-01
*/

* ---------------------------------------------------------------------------- *
capture program drop eiod_hdlei
program define eiod_hdlei, rclass
    version 18
    syntax , BIODiversity(varname numeric) GDQS(varname numeric) ///
             Group(varname numeric)                              ///
             [ PREfix(name) GDQScut(real 23)                       ///
               PERCentile(numlist integer min=1 max=1 >=10 <=90)   ///
               CUToffs(string) replace ]

    * ======================================================================== *
    * STEP 1. Options and output names
    * ======================================================================== *
    if "`prefix'" == ""     local prefix "hdlei"
    if "`percentile'" == "" local percentile 30

    if mod(`percentile', 10) {
        di as error "percentile() must be a multiple of 10 between 10 and 90"
        exit 198
    }
    if `percentile' != 30 {
        di as txt "{bf:note}: percentile(`percentile') is not the published HDLEI" ///
                  " criterion (30) - label any result from this as a sensitivity analysis"
    }

    local vH  "`prefix'_healthy"        // sub-indicator: diet quality
    local vE  "`prefix'_lowimpact"      // sub-indicator: environment
    local vC  "`prefix'_cat"            // combined, 4 categories
    local vD  "`prefix'"                // combined, dichotomous

    if "`replace'" != "" {
        foreach v in `vH' `vE' `vC' `vD' {
            capture drop `v'
        }
    }
    foreach v in `vH' `vE' `vC' `vD' {
        confirm new variable `v'
    }

    qui count if !inrange(`group', 1, 8) & !mi(`group')
    if r(N) {
        di as error "`group' has `r(N)' value(s) outside 1-8"
        di as error "  build the group variable with eiod_demogroup"
        exit 459
    }

    * ======================================================================== *
    * STEP 2. Eligibility - 2 years and older only (see header)
    * ======================================================================== *
    tempvar elig
    qui gen byte `elig' = inlist(`group', 2, 3, 4, 6, 7, 8)
    qui count if inlist(`group', 1, 5)
    local nunder2 = r(N)

    * ======================================================================== *
    * STEP 3. SUB-INDICATOR 1 - healthy diet (GDQS)
    * ======================================================================== *
    * Identical criterion to HESD: "a GDQS of 23 or more" (paper p.4).
    qui gen byte `vH' = (`gdqs' >= `gdqscut') if !mi(`gdqs') & `elig'

    lab def eiod_healthy 0 "Not a healthy diet" 1 "Healthy diet", replace
    lab val `vH' eiod_healthy
    lab var `vH' "HDLEI sub-indicator: healthy diet (GDQS >= `gdqscut')"

    * ======================================================================== *
    * STEP 4. SUB-INDICATOR 2 - low environmental impacts (relative < P30)
    * ======================================================================== *
    * Delegated to eiod_relative so there is exactly one implementation of the
    * Table 4g band logic in the whole codebase.
    /*
       Run QUIETLY and re-report under this command's own heading - eiod_relative
       would otherwise announce the TEMPVAR it created (`created __000001'),
       which reads like a naming fault. See the matching note in eiod_fn_04_hesd.do.
    */
    tempvar bandall lowall
    qui eiod_relative biodiv, value(`biodiversity') group(`group')  ///
        generate(`bandall') below(`percentile') belowvar(`lowall')  ///
        cutoffs(`cutoffs')
    local biounit   "`r(unit)'"
    local bio_n      = r(N)
    local bio_nmiss  = r(N_miss)
    local bio_pct    = r(pct_below)

    qui gen byte `vE' = `lowall' if `elig'

    lab def eiod_lowimp 0 "Not a diet with low env. impacts" ///
                        1 "Diet with low env. impacts", replace
    lab val `vE' eiod_lowimp
    lab var `vE' "HDLEI sub-indicator: low impacts (biodiv < P`percentile' global ref.)"

    * ======================================================================== *
    * STEP 5. COMBINED - the four categories of Table 5b
    * ======================================================================== *
    * Four explicit replaces, so each line can be checked against the printed
    * table row by row.
    qui gen byte `vC' = .
    qui replace  `vC' = 1 if `vH' == 1 & `vE' == 1    // healthy     + low impact
    qui replace  `vC' = 2 if `vH' == 0 & `vE' == 1    // not healthy + low impact
    qui replace  `vC' = 3 if `vH' == 1 & `vE' == 0    // healthy     + not low impact
    qui replace  `vC' = 4 if `vH' == 0 & `vE' == 0    // not healthy + not low impact

    lab def eiod_hdlei_cat ///
        1 "Healthy with low env. impacts"         ///
        2 "Not healthy but low env. impacts"      ///
        3 "Healthy but not low env. impacts"      ///
        4 "Not healthy and not low env. impacts", replace
    lab val `vC' eiod_hdlei_cat
    lab var `vC' "HDLEI category (Table 5b)"

    * ======================================================================== *
    * STEP 6. COMBINED - dichotomous
    * ======================================================================== *
    qui gen byte `vD' = (`vC' == 1) if !mi(`vC')

    lab def eiod_hdlei_bin 0 "Not a HDLEI" 1 "Healthy diet with low env. impacts", replace
    lab val `vD' eiod_hdlei_bin
    lab var `vD' "HDLEI: healthy diet with low environmental impacts"

    * ======================================================================== *
    * STEP 7. Internal consistency check
    * ======================================================================== *
    assert mi(`vC') == (mi(`vH') | mi(`vE'))

    * ======================================================================== *
    * STEP 8. Report and return
    * ======================================================================== *
    qui count if !mi(`vC')
    local nobs = r(N)

    di as txt _n "{bf:Table 5b - HDLEI composite metric}"
    di as txt    "  diet-quality criterion : `gdqs' >= `gdqscut'"
    di as txt    "  environment criterion  : `biodiversity' < P`percentile' of Table 4g global reference"
    if "`bio_pct'" != "" & "`bio_pct'" != "." {
        di as txt "    {res}`vE'{txt}: " %5.1f `bio_pct' "% of `bio_n' diets below P`percentile'" ///
                  cond(`bio_nmiss', ", `bio_nmiss' missing", "")
    }
    di as txt    "  created {res}`vH'{txt}, {res}`vE'{txt}, {res}`vC'{txt}, {res}`vD'{txt}"
    if `nunder2' {
        di as txt "  {res}`nunder2'{txt} observation(s) aged under 2 yr set to missing"
        di as txt "     (the GDQS is not validated below age 2 - paper p.4)"
    }
    if `nobs' {
        qui su `vD', meanonly
        di as txt "  HDLEI prevalence       : {res}" %5.1f `=r(mean)*100' ///
                  "%{txt} of `nobs' eligible diets"
        tab `vC', m
    }

    return scalar N          = `nobs'
    return scalar N_under2   = `nunder2'
    return scalar percentile = `percentile'
    return scalar gdqscut    = `gdqscut'
    return local  prefix     "`prefix'"
end
* ---------------------------------------------------------------------------- *
