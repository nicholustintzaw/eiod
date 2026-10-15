* **************************************************************************** *
* **************************************************************************** *
*                                                                              *
*   eiod_fn_06_batch.do                                                        *
*   BATCH WRAPPERS - map YOUR variable names onto the indicators, in one call  *
*                                                                              *
* **************************************************************************** *
* **************************************************************************** *

/*
  ** DEFINES        eiod_absolute_all     Table 3,      many indicators at once
                    eiod_relative_all     Tables 4a-4g, many indicators at once

  ** THE PROBLEM    THESE SOLVE
                    eiod_absolute and eiod_relative each take ONE indicator and
                    one value() variable. That is correct and they remain the
                    primitives. But running seven of them means seven near
                    identical calls, and the obvious way to shorten that is

                        foreach i in landtotal ghg biodiv ... {
                            eiod_absolute `i', value(`i') ...
                        }

                    which only works if your variables happen to be NAMED
                    landtotal, ghg, biodiv. They will not be. The old demo did
                    exactly this, which made it look as though the package
                    required those names. It never did - but the pattern it
                    taught did.

  ** THE FIX        One option per indicator, holding YOUR variable name:

                        eiod_absolute_all , group(dgroup)      ///
                            landtotal(land_ado)                ///
                            ghg(ghg_ado)                       ///
                            biodiv(biodiv_ado)

                    Supply as few or as many as you have. Indicators you do not
                    name are simply not computed - no placeholder variables, no
                    warnings, no need to fabricate a column you do not hold.

  ** SYNTAX         eiod_absolute_all , Group(varname)
                        [ landtotal(varname) landarable(varname)
                          landpasture(varname) ghg(varname) eutroph(varname)
                          water(varname) biodiv(varname)
                          PREfix(name) THRESHprefix(name)
                          CUToffs(string) replace noheader strict nocheck ]

                    eiod_relative_all , Group(varname)
                        [ <same seven indicator options>
                          PREfix(name) MIDprefix(name) BELow(#)
                          CUToffs(string) replace noheader strict nocheck ]

  ** OPTION NAMES   The seven indicator options are the EIOD indicator keys and
                    must be typed in full - landtotal, landarable and
                    landpasture share a stem, so abbreviating them would be
                    ambiguous and Stata will refuse it.

  ** OUTPUT NAMES   Built from the indicator key, not from your variable name,
                    so that results are comparable across datasets:

                      eiod_absolute_all   `prefix'landtotal        default abs_
                                          `threshprefix'landtotal  default thr_
                      eiod_relative_all   `prefix'landtotal        default rel_
                                          `midprefix'landtotal     default mid_
                                          `prefix'landtotal_lt30   if below(30)

                    So biodiv(biodiv_ado) produces abs_biodiv, whatever the
                    input was called. Set prefix() if that clashes.

  ** RETURNS        r(n_ind)   number of indicators processed
                    r(indlist) the indicator keys processed, space separated
                    r(varlist) the output variables created

  ** NO NEW LOGIC   Both wrappers do nothing except loop and call the single
                    indicator command. Every threshold comparison, band
                    assignment, missing-value rule and label still happens in
                    eiod_absolute / eiod_relative exactly once. If the wrapper
                    and the primitive ever disagreed, that would be a bug in
                    the loop, not two competing implementations.

  ** LAST UPDATE    2026-10-05
*/

* ---------------------------------------------------------------------------- *
* eiod_absolute_all  -  Table 3 across however many indicators you hold
* ---------------------------------------------------------------------------- *
capture program drop eiod_absolute_all
program define eiod_absolute_all, rclass
    version 18
    syntax , Group(varname numeric)                                           ///
           [ landtotal(varname numeric)   landarable(varname numeric)         ///
             landpasture(varname numeric) ghg(varname numeric)                ///
             eutroph(varname numeric)     water(varname numeric)              ///
             biodiv(varname numeric)                                          ///
             PREfix(name) THRESHprefix(name) CUToffs(string)                  ///
             replace noheader strict nocheck ]

    local INDS "landtotal landarable landpasture ghg eutroph water biodiv"

    if "`prefix'"       == "" local prefix       "abs_"
    if "`threshprefix'" == "" local threshprefix "thr_"

    /*
       Normalise cutoffs() before forwarding it.

       syntax option type (string) keeps whatever quoting the user typed, so
       cutoffs("refdata") arrives here as the 9-character string "refdata"
       WITH its quotes. Re-wrapping that in a compound quote when calling
       eiod_absolute produces `""refdata""', and the backtick-apostrophe pair
       then reaches the helper and expands as an undefined local macro -
       silently empty. Strip to the bare path here and add exactly one level
       of quoting at the call site.
    */
    local cutpath = subinstr(`"`cutoffs'"', `"""', "", .)
    local cutpath = strtrim(`"`cutpath'"')

    * nocheck creates a local named `check'; forward it under its own name
    local qcoff ""
    if "`check'" != "" local qcoff "nocheck"

    * ---- which indicators did the user actually supply? -------------------- *
    local supplied ""
    foreach i of local INDS {
        if "``i''" != "" local supplied "`supplied' `i'"
    }
    local supplied = strtrim("`supplied'")
    local n : word count `supplied'

    if `n' == 0 {
        di as error "no indicator supplied."
        di as error "  name at least one of the seven, each holding YOUR variable:"
        di as error "    eiod_absolute_all, group(`group') ghg(my_ghg_var)"
        di as error "  available: `INDS'"
        exit 198
    }

    * syntax noheader creates a local named `header', holding "noheader" when
    * the option was typed and empty when it was not
    if "`header'" == "" {
        di as txt _n "{hline 78}"
        di as txt "{bf:Table 3 - absolute threshold metrics}   `n' indicator(s)"
        di as txt "{hline 78}"
    }

    * ---- loop ---------------------------------------------------------------- *
    local made ""
    foreach i of local supplied {
        eiod_absolute `i', value(``i'') group(`group')                        ///
            generate(`prefix'`i') threshvar(`threshprefix'`i')                ///
            cutoffs("`cutpath'") `replace' `strict' `qcoff'
        local made "`made' `prefix'`i' `threshprefix'`i'"
    }

    return scalar n_ind   = `n'
    return local  indlist "`supplied'"
    return local  varlist = strtrim("`made'")
end
* ---------------------------------------------------------------------------- *


* ---------------------------------------------------------------------------- *
* eiod_relative_all  -  Tables 4a-4g across however many indicators you hold
* ---------------------------------------------------------------------------- *
capture program drop eiod_relative_all
program define eiod_relative_all, rclass
    version 18
    syntax , Group(varname numeric)                                           ///
           [ landtotal(varname numeric)   landarable(varname numeric)         ///
             landpasture(varname numeric) ghg(varname numeric)                ///
             eutroph(varname numeric)     water(varname numeric)              ///
             biodiv(varname numeric)                                          ///
             PREfix(name) MIDprefix(name)                                     ///
             BELow(numlist integer min=1 max=1 >=10 <=90)                     ///
             CUToffs(string) replace noheader strict nocheck ]

    local INDS "landtotal landarable landpasture ghg eutroph water biodiv"

    if "`prefix'"    == "" local prefix    "rel_"
    if "`midprefix'" == "" local midprefix "mid_"

    * normalise cutoffs() before forwarding - see the note in eiod_absolute_all
    local cutpath = subinstr(`"`cutoffs'"', `"""', "", .)
    local cutpath = strtrim(`"`cutpath'"')

    * nocheck creates a local named `check'; forward it under its own name
    local qcoff ""
    if "`check'" != "" local qcoff "nocheck"

    local supplied ""
    foreach i of local INDS {
        if "``i''" != "" local supplied "`supplied' `i'"
    }
    local supplied = strtrim("`supplied'")
    local n : word count `supplied'

    if `n' == 0 {
        di as error "no indicator supplied."
        di as error "  name at least one of the seven, each holding YOUR variable:"
        di as error "    eiod_relative_all, group(`group') biodiv(my_biodiv_var)"
        di as error "  available: `INDS'"
        exit 198
    }

    if "`header'" == "" {
        di as txt _n "{hline 78}"
        di as txt "{bf:Tables 4a-4g - relative benchmark metrics}   `n' indicator(s)"
        di as txt "{hline 78}"
    }

    local belowopt ""
    if "`below'" != "" local belowopt "below(`below')"

    local made ""
    foreach i of local supplied {
        eiod_relative `i', value(``i'') group(`group')                        ///
            generate(`prefix'`i') midpoint(`midprefix'`i') `belowopt'         ///
            cutoffs("`cutpath'") `replace' `strict' `qcoff'
        local made "`made' `prefix'`i' `midprefix'`i'"
        if "`below'" != "" local made "`made' `prefix'`i'_lt`below'"
    }

    return scalar n_ind   = `n'
    return local  indlist "`supplied'"
    return local  varlist = strtrim("`made'")
end
* ---------------------------------------------------------------------------- *
