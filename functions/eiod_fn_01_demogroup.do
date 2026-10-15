* **************************************************************************** *
* **************************************************************************** *
*                                                                              *
*   eiod_fn_01_demogroup.do                                                    *
*   AGE/SEX DEMOGRAPHIC GROUP - the key every other metric is scaled by        *
*                                                                              *
* **************************************************************************** *
* **************************************************************************** *

/*
  ** DEFINES        eiod_demogroup

  ** PURPOSE        Build the 8-category age/sex variable that all Intake EIOD
                    metrics are defined against. Every other eiod_* function
                    requires it.

  ** SOURCE         Intake-EIOD-Methods-Paper-Jan2026-Final.pdf, p.3
  **                https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf
                      i.   Male   0-1.9 yr      v.    Female 0-1.9 yr
                      ii.  Male   2-4.9 yr      vi.   Female 2-4.9 yr
                      iii. Male   5-9.9 yr      vii.  Female 5-9.9 yr
                      iv.  Male   10+   yr      viii. Female 10+   yr

                    These eight groups exist because average dietary energy
                    requirement differs across them. The paper computes a
                    weighting factor per group (average energy requirement at a
                    moderate activity level, FAO/WHO/UNU 2004, weighted by the
                    world population age distribution, UNDP 2022, assuming a
                    50:50 sex split) and applies it to a single all-population
                    figure to produce every cut-off in Tables 3 and 4a-4g.

  ** SYNTAX         eiod_demogroup , Age(varname) Sex(varname) GENerate(name)
                        [ UNITs(years|months) MALEcode(#) FEMALEcode(#) replace ]

  ** OPTIONS        age()         respondent age, numeric
                    sex()         respondent sex, numeric
                    generate()    name for the new 1-8 group variable
                    units()       years (default) or months
                    malecode()    value of sex() meaning male   (default 1)
                    femalecode()  value of sex() meaning female (default 2)
                    replace       drop generate() first if it already exists

  ** OUTPUT         one byte variable, values 1-8, value-labelled eiod_group

  ** INTERVAL       The paper prints the groups as "0-1.9", "2-4.9", "5-9.9",
     CONVENTION     "10+". These are read as HALF-OPEN intervals:
                        group 1 / 5 : age <  2
                        group 2 / 6 : 2  <= age <  5
                        group 3 / 7 : 5  <= age < 10
                        group 4 / 8 : age >= 10
                    This matters. A child aged 1.95 years belongs in the first
                    group. Testing `age <= 1.9` instead would leave everyone
                    between 1.9 and 2.0 unassigned, and they would then silently
                    drop out of every downstream metric.

  ** LAST UPDATE    2026-10-01
*/

* ---------------------------------------------------------------------------- *
capture program drop eiod_demogroup
program define eiod_demogroup
    version 18
    syntax , Age(varname numeric) Sex(varname numeric) GENerate(name) ///
             [ MALEcode(integer 1) FEMALEcode(integer 2)              ///
               UNITs(string) replace ]

    * ======================================================================== *
    * STEP 1. Validate the options
    * ======================================================================== *
    if "`units'" == "" local units "years"
    if !inlist("`units'", "years", "months") {
        di as error "units() must be years or months"
        exit 198
    }
    if `malecode' == `femalecode' {
        di as error "malecode() and femalecode() must differ"
        exit 198
    }
    if "`replace'" != "" capture drop `generate'
    confirm new variable `generate'

    * ======================================================================== *
    * STEP 2. Put age on a years scale
    * ======================================================================== *
    tempvar ageyr
    if "`units'" == "months" qui gen double `ageyr' = `age' / 12
    else                     qui gen double `ageyr' = `age'

    qui count if `ageyr' < 0 & !mi(`ageyr')
    if r(N) {
        di as error "`age' has `r(N)' negative value(s)"
        exit 459
    }

    * ======================================================================== *
    * STEP 3. Refuse unrecognised sex codes rather than dropping them
    * ======================================================================== *
    * Without this check an unexpected code (9 for "missing", say, or 0/1
    * coding when 1/2 was assumed) would simply fail every condition in STEP 4
    * and leave those respondents unassigned - and they would then vanish from
    * every metric with no error and no message.
    qui count if !inlist(`sex', `malecode', `femalecode') & !mi(`sex')
    if r(N) {
        di as error "`sex' has `r(N)' value(s) that are neither malecode(`malecode') nor femalecode(`femalecode')"
        di as error "  recode them, or set malecode()/femalecode() to match your data"
        exit 459
    }

    * ======================================================================== *
    * STEP 4. Assign the eight groups (half-open intervals - see header)
    * ======================================================================== *
    qui gen byte `generate' = .

    * ---- males ------------------------------------------------------------- *
    qui replace `generate' = 1 if `sex' == `malecode'   & `ageyr' <   2
    qui replace `generate' = 2 if `sex' == `malecode'   & `ageyr' >=  2 & `ageyr' <  5
    qui replace `generate' = 3 if `sex' == `malecode'   & `ageyr' >=  5 & `ageyr' < 10
    qui replace `generate' = 4 if `sex' == `malecode'   & `ageyr' >= 10 & !mi(`ageyr')

    * ---- females ----------------------------------------------------------- *
    qui replace `generate' = 5 if `sex' == `femalecode' & `ageyr' <   2
    qui replace `generate' = 6 if `sex' == `femalecode' & `ageyr' >=  2 & `ageyr' <  5
    qui replace `generate' = 7 if `sex' == `femalecode' & `ageyr' >=  5 & `ageyr' < 10
    qui replace `generate' = 8 if `sex' == `femalecode' & `ageyr' >= 10 & !mi(`ageyr')

    * ======================================================================== *
    * STEP 5. Prove nobody with observed age and sex was left out
    * ======================================================================== *
    qui count if mi(`generate') & !mi(`ageyr') & !mi(`sex')
    if r(N) {
        di as error "`r(N)' observation(s) with non-missing age and sex were not assigned a group"
        di as error "  this should be impossible - inspect the age distribution"
        exit 459
    }

    * ======================================================================== *
    * STEP 6. Label
    * ======================================================================== *
    lab def eiod_group  1 "Male 0-1.9 yr"   2 "Male 2-4.9 yr"   3 "Male 5-9.9 yr"   ///
                        4 "Male 10+ yr"     5 "Female 0-1.9 yr" 6 "Female 2-4.9 yr" ///
                        7 "Female 5-9.9 yr" 8 "Female 10+ yr", replace
    lab val `generate' eiod_group
    lab var `generate' "EIOD age/sex demographic group"

    * ======================================================================== *
    * STEP 7. Report
    * ======================================================================== *
    qui count if mi(`generate')
    local nmiss = r(N)
    di as txt _n "{bf:eiod_demogroup}  created {res}`generate'{txt}" ///
                 cond(`nmiss', " ; {res}`nmiss'{txt} missing (age or sex not observed)", "")
    tab `generate', m
end
* ---------------------------------------------------------------------------- *
