* **************************************************************************** *
* **************************************************************************** *
*                                                                              *
*   eiod_fn_04_hesd.do                                                         *
*   TABLE 5a - HEALTHY AND ENVIRONMENTALLY SUSTAINABLE DIET (HESD)             *
*                                                                              *
* **************************************************************************** *
* **************************************************************************** *

/*
  ** DEFINES        eiod_hesd

  ** PURPOSE        Composite metric combining a diet-quality criterion with an
                    ABSOLUTE environmental sustainability criterion, and - as
                    requested - returning each criterion as its own
                    sub-indicator alongside the combined measure.

  ** SOURCE         Intake-EIOD-Methods-Paper-Jan2026-Final.pdf
  **                https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf
                      Table 5a, p.20
                      Method,   p.4
                      Annex 1 Part II, p.17

  ** THE TWO        healthy            GDQS >= 23
     CRITERIA       env. sustainable   biodiversity loss < the Table 3 ABSOLUTE
                                       threshold for the demographic group

                    Biodiversity loss is used as the proxy for total
                    environmental impact (paper p.4). The GDQS cut-off of 23
                    is the paper's "healthy diet" criterion, supported by the
                    GDQS validation literature it cites.

  ** SYNTAX         eiod_hesd , BIODiversity(varname) GDQS(varname)
                        Group(varname)
                        [ PREfix(name) GDQScut(#) CUToffs(string) replace ]

  ** OPTIONS        biodiversity()  respondent-day biodiversity loss (PDF*year)
                    gdqs()          Global Diet Quality Score
                    group()         the 1-8 variable from eiod_demogroup
                    prefix()        stub for the output names (default hesd)
                    gdqscut()       GDQS threshold (default 23 - change only
                                    with a documented reason)
                    cutoffs()       path to eiod_cutoffs.dta
                    replace         drop the output variables first

  ** OUTPUT         FOUR variables. With the default prefix:

                      hesd_healthy  0/1  GDQS criterion alone
                                         <-- DECOMPOSED SUB-INDICATOR
                      hesd_envsust  0/1  biodiversity criterion alone
                                         <-- DECOMPOSED SUB-INDICATOR
                      hesd_cat      1-4  the four categories of Table 5a
                      hesd          0/1  dichotomous: category 1 vs all else

                    Category coding follows the printed ROW ORDER of Table 5a:
                      1  Healthy and environmentally sustainable
                      2  Not healthy but environmentally sustainable
                      3  Healthy but not environmentally sustainable
                      4  Not healthy and not environmentally sustainable

  ** NO DUPLICATED  hesd_envsust is produced by CALLING eiod_absolute rather
     LOGIC          than by re-implementing the threshold comparison. It is
                    therefore identical, by construction, to the standalone
                    Table 3 biodiversity metric - there is no second copy of
                    the logic that could drift. Asserted in eiod_validate.do
                    Part H.

  ** AGE            The paper (p.4) restricts the composite metrics to
     RESTRICTION    individuals aged 2 years and older, because the GDQS has
                    not been adapted or validated below age 2. Table 5a
                    accordingly prints only six columns, not eight.

                    All four output variables are therefore left MISSING for
                    demographic groups 1 and 5 (Male/Female 0-1.9 yr), and the
                    number of observations affected is reported. If your sample
                    includes under-2s, decide explicitly whether they belong in
                    the analysis sample at all - it changes every denominator.

  ** RELATION TO    See eiod_fn_05_hdlei.do. The two composites are NESTED, not
     HDLEI          independent: the HDLEI environmental cut-off is uniformly
                    1.52x stricter, so hdlei==1 implies hesd==1 in every
                    demographic group. Do not present them as two dimensions
                    of a 2x2.

  ** LAST UPDATE    2026-10-01
*/

* ---------------------------------------------------------------------------- *
capture program drop eiod_hesd
program define eiod_hesd, rclass
    version 18
    syntax , BIODiversity(varname numeric) GDQS(varname numeric) ///
             Group(varname numeric)                              ///
             [ PREfix(name) GDQScut(real 23) CUToffs(string) replace ]

    * ======================================================================== *
    * STEP 1. Output names
    * ======================================================================== *
    if "`prefix'" == "" local prefix "hesd"
    local vH  "`prefix'_healthy"      // sub-indicator: diet quality
    local vE  "`prefix'_envsust"      // sub-indicator: environment
    local vC  "`prefix'_cat"          // combined, 4 categories
    local vD  "`prefix'"              // combined, dichotomous

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
    * "a Global Diet Quality Score (GDQS) of 23 or more" (paper p.4), so the
    * comparison is >= and a score of exactly 23 counts as healthy.
    qui gen byte `vH' = (`gdqs' >= `gdqscut') if !mi(`gdqs') & `elig'

    lab def eiod_healthy 0 "Not a healthy diet" 1 "Healthy diet", replace
    lab val `vH' eiod_healthy
    lab var `vH' "HESD sub-indicator: healthy diet (GDQS >= `gdqscut')"

    * ======================================================================== *
    * STEP 4. SUB-INDICATOR 2 - environmentally sustainable (absolute biodiv)
    * ======================================================================== *
    * Delegated to eiod_absolute so there is exactly one implementation of the
    * Table 3 comparison in the whole codebase.
    /*
       Run QUIETLY and re-report underneath this command's own heading.

       eiod_absolute announces the variable it created, and here that variable
       is a tempvar - so the unsuppressed call printed

           created __000001 ; 84 missing of 3000

       which reads like a naming fault. It never was one: __000001 is Stata's
       internal name for the temporary 0/1 column that becomes hesd_envsust two
       lines below. The information in that line is worth keeping, so it is
       recovered from the r() returns and printed against the real name.
    */
    tempvar envall
    qui eiod_absolute biodiv, value(`biodiversity') group(`group') ///
        generate(`envall') cutoffs(`cutoffs')
    local biounit  "`r(unit)'"
    local bio_n     = r(N)
    local bio_nmiss = r(N_miss)
    local bio_pct   = r(pct)

    qui gen byte `vE' = `envall' if `elig'

    lab def eiod_envsust 0 "Not environmentally sustainable" ///
                         1 "Environmentally sustainable", replace
    lab val `vE' eiod_envsust
    lab var `vE' "HESD sub-indicator: env. sustainable (biodiv < Table 3 threshold)"

    * ======================================================================== *
    * STEP 5. COMBINED - the four categories of Table 5a
    * ======================================================================== *
    * Written as four explicit replaces rather than an arithmetic formula so a
    * reader can check each line against the printed table row by row.
    qui gen byte `vC' = .
    qui replace  `vC' = 1 if `vH' == 1 & `vE' == 1    // healthy     + sustainable
    qui replace  `vC' = 2 if `vH' == 0 & `vE' == 1    // not healthy + sustainable
    qui replace  `vC' = 3 if `vH' == 1 & `vE' == 0    // healthy     + not sustainable
    qui replace  `vC' = 4 if `vH' == 0 & `vE' == 0    // not healthy + not sustainable

    lab def eiod_hesd_cat ///
        1 "Healthy and env. sustainable"        ///
        2 "Not healthy but env. sustainable"    ///
        3 "Healthy but not env. sustainable"    ///
        4 "Not healthy and not env. sustainable", replace
    lab val `vC' eiod_hesd_cat
    lab var `vC' "HESD category (Table 5a)"

    * ======================================================================== *
    * STEP 6. COMBINED - dichotomous
    * ======================================================================== *
    qui gen byte `vD' = (`vC' == 1) if !mi(`vC')

    lab def eiod_hesd_bin 0 "Not a HESD" 1 "Healthy and env. sustainable diet", replace
    lab val `vD' eiod_hesd_bin
    lab var `vD' "HESD: healthy AND environmentally sustainable diet"

    * ======================================================================== *
    * STEP 7. Internal consistency check
    * ======================================================================== *
    * The category must be defined exactly when both sub-indicators are, and
    * missing exactly when either is. If this ever fails, the eligibility or
    * missing-value handling above has broken.
    assert mi(`vC') == (mi(`vH') | mi(`vE'))

    * ======================================================================== *
    * STEP 8. Report and return
    * ======================================================================== *
    qui count if !mi(`vC')
    local nobs = r(N)

    di as txt _n "{bf:Table 5a - HESD composite metric}"
    di as txt    "  diet-quality criterion : `gdqs' >= `gdqscut'"
    di as txt    "  environment criterion  : `biodiversity' < Table 3 absolute threshold (`biounit')"
    if "`bio_pct'" != "" & "`bio_pct'" != "." {
        di as txt "    {res}`vE'{txt}: " %5.1f `bio_pct' "% of `bio_n' diets below the threshold" ///
                  cond(`bio_nmiss', ", `bio_nmiss' missing", "")
    }
    di as txt    "  created {res}`vH'{txt}, {res}`vE'{txt}, {res}`vC'{txt}, {res}`vD'{txt}"
    if `nunder2' {
        di as txt "  {res}`nunder2'{txt} observation(s) aged under 2 yr set to missing"
        di as txt "     (the GDQS is not validated below age 2 - paper p.4)"
    }
    if `nobs' {
        qui su `vD', meanonly
        di as txt "  HESD prevalence        : {res}" %5.1f `=r(mean)*100' ///
                  "%{txt} of `nobs' eligible diets"
        tab `vC', m
    }

    return scalar N        = `nobs'
    return scalar N_under2 = `nunder2'
    return scalar gdqscut  = `gdqscut'
    return local  prefix   "`prefix'"
end
* ---------------------------------------------------------------------------- *
