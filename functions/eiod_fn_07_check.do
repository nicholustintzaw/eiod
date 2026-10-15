* **************************************************************************** *
* **************************************************************************** *
*                                                                              *
*   eiod_fn_07_check.do                                                        *
*   INPUT QC - storage type, precision, magnitude, sign                        *
*                                                                              *
* **************************************************************************** *
* **************************************************************************** *

/*
  ** DEFINES        eiod_check_impact   standalone QC report on impact variables
                    _eiod_precheck      internal: the same checks, run silently
                                        by eiod_absolute and eiod_relative

  ** WHY THIS       The EIOD indicators span 15 orders of magnitude - water use
     EXISTS         around 600 litres, biodiversity loss around 8e-13 PDF*year.
                    A storage type that is harmless for one is destructive for
                    another, and Stata will not say a word about it.

  ** WHAT WAS       The risk was MEASURED before this check was written, on
     ACTUALLY       200,000 simulated respondent-days against the real
     MEASURED       cut-offs, rather than assumed. Results:

                      float storage of the impact variable
                        absolute threshold: 0 classification flips of 200,000
                                            for biodiv, ghg, water, landtotal
                        relative band     : 1 band change of 200,000 (water)
                        largest relative error introduced: 5.5e-08
                        cut-offs that underflow in float : 0

                      float UNDERFLOW, values near 1e-40
                        200,000 of 200,000 flushed to exactly ZERO

                      integer storage (int) of ghg
                        200,000 of 200,000 values changed
                        mean 3.836 -> 3.336, a 13% downward bias

                    So the headline is NOT the one you would expect. Plain
                    float storage at EIOF magnitudes is very nearly harmless -
                    biodiversity at 1e-13 sits comfortably inside float range,
                    whose smallest normal value is about 1.2e-38. What is
                    destructive is:

                      (a) INTEGER storage, which truncates every value toward
                          zero and biases the mean by double digits, silently;
                      (b) UNDERFLOW, when the variable is float AND the values
                          are far smaller than the EIOF scale - which happens
                          as soon as biodiversity is expressed per gram rather
                          than per kilogram, or is left at ingredient level
                          before summing to the day.

                    The check is therefore graded: integer and underflow are
                    errors, float is a note, magnitude is a warning.

  ** SYNTAX         eiod_check_impact varlist [if] [in]
                        [ , INDicator(name) CUToffs(string) strict ]

                    _eiod_precheck VARNAME INDICATOR [strict|nocheck]   (internal)

  ** OPTIONS        indicator()  compare the magnitude against this indicator's
                                 published cut-offs. Omit for storage and sign
                                 checks only.
                    cutoffs()    path to eiod_cutoffs.dta
                    strict       make every finding an error instead of a
                                 warning

  ** THE FOUR       1 STORAGE   byte/int/long  -> ERROR. float -> note.
     CHECKS         2 UNDERFLOW float variable holding, or capable of holding,
                                values below ~1e-37 -> ERROR
                    3 SIGN      negative impact values -> ERROR
                    4 SCALE     median more than 10^4 away from the median
                                published cut-off -> WARNING (likely a unit
                                mismatch, not a precision problem)

  ** IN THE METRIC  eiod_absolute and eiod_relative call _eiod_precheck before
     COMMANDS       computing anything. Suppress with nocheck, escalate with
                    strict. Defaults are deliberately conservative: an error
                    stops a wrong number being produced; a note does not stop
                    anything.

  ** OUT OF REACH   INCOMPLETE EIOF COVERAGE cannot be checked here, and this
     OF ANY CHECK   is a property of the data flow rather than a gap to fill.

                    Not every food has an impact factor; the EIOF country
                    databases mark foods with no available estimate. Such a
                    food contributes NOTHING to the day's total, so a
                    respondent who ate one has an impact understated by an
                    unknown amount.

                    These commands receive ONE NUMBER PER RESPONDENT-DAY.
                    Whether it was summed over five costed foods, or four
                    costed and one missing, is not a property of that number -
                    the aggregation discarded the evidence one step earlier.
                    No test applied to the variable can recover it.

                    The one detectable case is the degenerate one: if EVERY
                    food lacked a factor and the upstream code produced 0
                    rather than missing, the zeros count shows it and check 1
                    grades it. That rule exists for this family of faults - a
                    diet that was consumed cannot have zero impact. Partial
                    coverage leaves no trace.

                    It matters more for these metrics than for most, because
                    each respondent is compared against a FIXED EXTERNAL
                    cut-off rather than against the rest of the sample: uneven
                    coverage shifts classifications with nothing in the output
                    looking wrong.

                    Handle it where the evidence still exists - in the step
                    that aggregates food items to the respondent-day. Count the
                    consumed items with no factor, or better the SHARE OF
                    CONSUMED WEIGHT that carries one, and report it alongside
                    any prevalence. See readme/06_eiod_infrastructure.md.

  ** LAST UPDATE    2026-10-05
*/

* ---------------------------------------------------------------------------- *
* _eiod_precheck  -  internal, terse. args: varname indicator mode
* ---------------------------------------------------------------------------- *
capture program drop _eiod_precheck
program define _eiod_precheck, rclass
    version 18
    args v ind mode

    if "`mode'" == "nocheck" {
        return scalar rc = 0
        exit
    }

    local fatal 0
    local t : type `v'

    * ---- 1. STORAGE TYPE ---------------------------------------------------- *
    if inlist("`t'", "byte", "int", "long") {
        di as error "EIOD input check: `v' is stored as {bf:`t'}, an INTEGER type."
        di as error "  Every value is truncated toward zero. Measured on simulated"
        di as error "  ghg data this biased the mean by 13% with no warning from Stata."
        di as error "  Fix:  recast double `v'    (or rebuild it as double)"
        local fatal 1
    }
    else if "`t'" == "float" {
        /*
           float is usually fine at EIOF magnitudes - biodiversity at 1e-13 is
           well inside float range. The failure mode is UNDERFLOW, and it has
           to be tested in three separate shapes, because the obvious test
           (look at the smallest non-zero value) sees nothing at all once
           every value has already been flushed to zero.
        */
        qui count if !mi(`v')
        local nobs = r(N)
        qui count if `v' != 0 & !mi(`v')
        local nnz = r(N)
        local nzero = `nobs' - `nnz'

        if `nobs' > 0 & `nnz' == 0 {
            * every value is exactly zero - almost always total underflow
            di as error "EIOD input check: `v' is {bf:float} and EVERY value is exactly zero."
            di as error "  float cannot represent magnitudes below about 1.2e-38; anything"
            di as error "  smaller silently becomes 0, and a zero impact passes every"
            di as error "  threshold test. If the true values really are this small, the"
            di as error "  unit is probably wrong as well."
            di as error "  Fix:  rebuild `v' as double, before any multiplication."
            local fatal 1
        }
        else if `nnz' > 0 {
            qui su `v' if `v' != 0, meanonly
            local vmin = abs(r(min))

            if `vmin' < 1e-37 {
                di as error "EIOD input check: `v' is {bf:float} and holds values near `vmin'."
                di as error "  That is at the edge of float range (~1.2e-38). Values below it"
                di as error "  become exactly zero and then pass every threshold test."
                di as error "  Fix:  recast double `v'"
                local fatal 1
            }
            else if `nzero' > 0 {
                di as error "EIOD input check: `v' is {bf:float} with `nzero' exact zero(s)"
                di as error "  among `nobs' observations, smallest non-zero `vmin'."
                di as error "  A consumed diet with exactly zero impact is implausible, so"
                di as error "  these are probably underflow. Compare against a double copy:"
                di as error "    gen double chk = `v'   // rebuild from source, not from `v'"
                local fatal 1
            }
            else {
                di as txt "{err}note{txt}: `v' is stored as float. At EIOF magnitudes this"
                di as txt "      changed 0 of 200,000 absolute classifications in testing,"
                di as txt "      so it is tolerated -- but double is free. recast double `v'"
            }
        }
    }
    else if "`t'" == "double" {
        * a double that is entirely zero is still wrong, just not a float bug
        qui count if !mi(`v')
        local nobs = r(N)
        qui count if `v' != 0 & !mi(`v')
        if `nobs' > 0 & r(N) == 0 {
            di as error "EIOD input check: every value of `v' is exactly zero."
            di as error "  Not a storage problem - check how the variable was built."
            local fatal 1
        }
    }

    * ---- 2. SIGN ------------------------------------------------------------ *
    qui count if `v' < 0 & !mi(`v')
    if r(N) {
        di as error "EIOD input check: `v' has `r(N)' negative value(s)."
        di as error "  An environmental impact total cannot be negative."
        local fatal 1
    }

    * ---- 3. SCALE against the published cut-offs ---------------------------- *
    if "`ind'" != "" & "$EIOD_NOSCALECHK" == "" {
        capture _eiod_cutfile
        if !_rc {
            local cp `"`s(path)'"'
            tempname cfr
            capture frame drop `cfr'
            frame create `cfr'
            capture frame `cfr' {
                qui use `"`cp'"', clear
                qui keep if indicator == "`ind'" & metric == "abs"
                qui su value, detail
                local cutmed = r(p50)
            }
            frame drop `cfr'

            if "`cutmed'" != "" & `cutmed' > 0 {
                qui su `v' if `v' > 0, detail
                local datmed = r(p50)
                if `datmed' > 0 {
                    local ratio = `datmed' / `cutmed'
                    if `ratio' > 10000 | `ratio' < 0.0001 {
                        di as txt "{err}warning{txt}: `v' sits " %8.1e `ratio' ///
                                  " x the published `ind' cut-off."
                        di as txt "      That is a unit mismatch far more often than a real"
                        di as txt "      finding. Check the units before reporting anything."
                    }
                }
            }
        }
    }

    if `fatal' & "`mode'" == "strict" {
        exit 459
    }
    if `fatal' {
        di as error "  -> computation continues, but the result will be wrong."
        di as error "     Re-run with strict to make this stop the command."
    }
    return scalar rc = `fatal'
end
* ---------------------------------------------------------------------------- *


* ---------------------------------------------------------------------------- *
* eiod_check_impact  -  standalone, verbose. Run it once on your inputs.
* ---------------------------------------------------------------------------- *
capture program drop eiod_check_impact
program define eiod_check_impact, rclass
    version 18
    syntax varlist(numeric) [if] [in] ///
           [ , INDicator(name) CUToffs(string) strict ]

    marksample touse, novarlist

    di as txt _n "{hline 78}"
    di as txt "{bf:EIOD input check}"
    di as txt "{hline 78}"
    di as txt "{col 3}variable{col 22}type{col 30}N{col 40}min{col 54}max{col 68}zeros"
    di as txt "{hline 78}"

    local nbad 0
    foreach v of local varlist {
        local t : type `v'
        qui count if !mi(`v') & `touse'
        local n = r(N)
        local lo = .
        local hi = .
        local nz = 0
        if `n' > 0 {
            qui su `v' if `touse', meanonly
            local lo = r(min)
            local hi = r(max)
            qui count if `v' == 0 & !mi(`v') & `touse'
            local nz = r(N)
        }
        local mark = cond(inlist("`t'","byte","int","long"), "{err}", "")
        di as txt "{col 3}`mark'`v'{col 22}`t'{col 30}`n'{col 40}" ///
            %10.3e `lo' "{col 54}" %10.3e `hi' "{col 68}`nz'"
    }
    di as txt "{hline 78}"

    foreach v of local varlist {
        _eiod_precheck `v' "`indicator'" "`strict'"
        local nbad = `nbad' + r(rc)
    }

    if `nbad' == 0 {
        di as txt _n "all inputs pass. Reminder of what this did NOT check:"
        di as txt "  - that the UNIT matches the EIOF database (m2*year, kg CO2eq,"
        di as txt "    kg PO4eq, litres, PDF*year)"
        di as txt "  - that the value is a respondent-DAY total, already summed"
        di as txt "    across every ingredient consumed"
        di as txt "  Neither is inferable from the numbers alone."
    }
    else {
        di as error _n "`nbad' variable(s) failed. Fix before computing any metric."
    }

    return scalar n_fail = `nbad'
end
* ---------------------------------------------------------------------------- *
