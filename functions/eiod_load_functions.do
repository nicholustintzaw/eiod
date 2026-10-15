* **************************************************************************** *
* **************************************************************************** *
*                                                                              *
*   eiod_load_functions.do                                                     *
*   LOADER - run once per Stata session, before any eiod_* command             *
*                                                                              *
* **************************************************************************** *
* **************************************************************************** *

/*
  ** PURPOSE        Load the EIOD metric commands into memory. Nothing else.

  ** USAGE          Simplest - from anywhere, naming the package folder once:

                        global EIOD_HOME "<folder holding this file>"
                        do "$EIOD_HOME/eiod_load_functions.do"

                    Or load only what you need:

                        do "$EIOD_HOME/eiod_load_functions.do" absolute hesd

                    Or, if your working directory is already the package
                    folder, just:

                        do eiod_load_functions.do

  ** SELECTIVE      Pass any of these keywords as arguments:
     LOADING
                        demogroup   eiod_demogroup
                        absolute    eiod_absolute
                        relative    eiod_relative
                        hesd        eiod_hesd      (needs absolute)
                        hdlei       eiod_hdlei     (needs relative)
                        batch       eiod_absolute_all, eiod_relative_all
                        all         everything (the default)

                    Dependencies are pulled in automatically: ask for hesd and
                    you get absolute too, because hesd calls it. The internal
                    helper is always loaded.

                    Honestly: loading everything costs a few milliseconds and
                    these are small programs, so `all' is a perfectly good
                    default. Selective loading exists because you asked for the
                    option, not because the full load is expensive.

  ** !! IMPORTANT   `clear all' DROPS ALL PROGRAMS FROM MEMORY.
                    If your analysis begins with `clear all', this loader must
                    run AFTER it. Plain `clear' is safe. Every function file
                    starts with `capture program drop', so re-running the
                    loader at any time is harmless.

  ** WHAT THIS      It does NOT set, overwrite or validate the cut-off path.
     FILE NO        An earlier version did, with
     LONGER DOES
                        global EIOD_CUTOFFS "$EIOD_OUT/eiod_cutoffs.dta"

                    which silently overwrote whatever the analyst had set, and
                    then refused to load anything at all if no file sat at that
                    exact location - even for eiod_demogroup, which never reads
                    the cut-offs. Both behaviours are gone. The cut-off file is
                    resolved per call, at the moment it is needed, by
                    _eiod_cutfile in eiod_fn_00_helper.do. See the README.

  ** LAST UPDATE    2026-10-05
*/

* ---------------------------------------------------------------------------- *
version 18
set more off
set varabbrev off          // abbreviations can silently resolve to the wrong variable

* ============================================================================ *
* STEP 1. Where are the function files?
* ============================================================================ *
/*
   Resolution order, first hit wins. No absolute path is hardcoded anywhere,
   so the package can be copied to any machine or any project folder.

     1. global EIOD_FN    - the folder holding the eiod_fn_*.do files
     2. global EIOD_HOME  - the package folder. Since the 2026-10-14
                            reorganisation this loader sits INSIDE that folder
                            alongside the function files, so "$EIOD_HOME"
                            itself is normally the hit. The "/functions"
                            candidate is kept for anyone still pointing
                            EIOD_HOME one level up, at the old layout.
     3. global EIOD_ROOT  - legacy; <root>/outputs/functions
     4. ./functions       - if the working directory is one level up
     5. ./                - if the working directory IS the package folder
*/
local FN ""

if `"$EIOD_FN"' != "" {
    capture confirm file `"$EIOD_FN/eiod_fn_00_helper.do"'
    if !_rc local FN `"$EIOD_FN"'
}
if `"`FN'"' == "" & `"$EIOD_HOME"' != "" {
    foreach c in "$EIOD_HOME/functions" "$EIOD_HOME" "$EIOD_HOME/outputs/functions" {
        if `"`FN'"' == "" {
            capture confirm file `"`c'/eiod_fn_00_helper.do"'
            if !_rc local FN `"`c'"'
        }
    }
}
if `"`FN'"' == "" & `"$EIOD_ROOT"' != "" {
    capture confirm file `"$EIOD_ROOT/outputs/functions/eiod_fn_00_helper.do"'
    if !_rc local FN `"$EIOD_ROOT/outputs/functions"'
}
if `"`FN'"' == "" {
    foreach c in "functions" "." {
        if `"`FN'"' == "" {
            capture confirm file `"`c'/eiod_fn_00_helper.do"'
            if !_rc local FN `"`c'"'
        }
    }
}

if `"`FN'"' == "" {
    di as error "cannot find the eiod function files."
    di as error "  set the package folder once, then re-run this loader:"
    di as error `"    global EIOD_HOME "<folder holding eiod_load_functions.do>""'
    di as error "  (looked under EIOD_FN, EIOD_HOME, EIOD_ROOT, ./functions and ./)"
    exit 601
}

* publish it, so a later call can reuse the resolved path
global EIOD_FN `"`FN'"'

* ============================================================================ *
* STEP 2. Which pieces were asked for?
* ============================================================================ *
local want = strtrim(lower(`"`0'"'))
if `"`want'"' == "" local want "all"

local valid "all demogroup absolute relative hesd hdlei batch"
foreach w of local want {
    if !`: list w in valid' {
        di as error `"unknown component: `w'"'
        di as error "  valid: `valid'"
        exit 198
    }
}

* expand dependencies - hesd calls eiod_absolute, hdlei calls eiod_relative,
* and the batch wrappers call both single-indicator commands
if `: list posof "all" in want' {
    local want "demogroup absolute relative hesd hdlei batch"
}
if `: list posof "hesd"  in want' & !`: list posof "absolute" in want' {
    local want "`want' absolute"
}
if `: list posof "hdlei" in want' & !`: list posof "relative" in want' {
    local want "`want' relative"
}
if `: list posof "batch" in want' {
    if !`: list posof "absolute" in want' local want "`want' absolute"
    if !`: list posof "relative" in want' local want "`want' relative"
}

* ============================================================================ *
* STEP 3. Load, in dependency order
* ============================================================================ *
* The helper is always needed: every metric command resolves the cut-off file
* through it.
local files    "eiod_fn_00_helper eiod_fn_07_check"
local loaded   "_eiod_cutfile eiod_check_impact"

if `: list posof "demogroup" in want' {
    local files  "`files' eiod_fn_01_demogroup"
    local loaded "`loaded' eiod_demogroup"
}
if `: list posof "absolute" in want' {
    local files  "`files' eiod_fn_02_absolute"
    local loaded "`loaded' eiod_absolute"
}
if `: list posof "relative" in want' {
    local files  "`files' eiod_fn_03_relative"
    local loaded "`loaded' eiod_relative"
}
if `: list posof "hesd" in want' {
    local files  "`files' eiod_fn_04_hesd"
    local loaded "`loaded' eiod_hesd"
}
if `: list posof "hdlei" in want' {
    local files  "`files' eiod_fn_05_hdlei"
    local loaded "`loaded' eiod_hdlei"
}
if `: list posof "batch" in want' {
    local files  "`files' eiod_fn_06_batch"
    local loaded "`loaded' eiod_absolute_all eiod_relative_all"
}

foreach f of local files {
    capture confirm file `"`FN'/`f'.do"'
    if _rc {
        di as error `"missing function file: `FN'/`f'.do"'
        exit 601
    }
    run `"`FN'/`f'.do"'
}

* ============================================================================ *
* STEP 4. Confirm every program really is in memory
* ============================================================================ *
* Calling a program with no arguments returns a SYNTAX error if it is loaded
* and r(199) "unrecognized command" if it is not. Only r(199) means a failed
* load, so that is the only code treated as fatal here.
local missing ""
foreach p of local loaded {
    if !inlist("`p'", "_eiod_cutfile", "eiod_check_impact") {
        capture `p'
        if _rc == 199 local missing "`missing' `p'"
    }
}
if "`missing'" != "" {
    di as error "these programs failed to load:`missing'"
    exit 199
}

* ============================================================================ *
* STEP 5. Report - including where the cut-offs WOULD come from
* ============================================================================ *
di as result _n "{hline 72}"
di as result "Intake EIOD metric commands loaded"
di as result "{hline 72}"
foreach p of local loaded {
    if "`p'" == "eiod_check_impact"  di as txt "  eiod_check_impact    input QC       storage type, sign, scale"
    if "`p'" == "eiod_demogroup"     di as txt "  eiod_demogroup       age/sex group 1-8   (required by the rest)"
    if "`p'" == "eiod_absolute"      di as txt "  eiod_absolute        Table 3        one indicator"
    if "`p'" == "eiod_relative"      di as txt "  eiod_relative        Tables 4a-4g   one indicator"
    if "`p'" == "eiod_hesd"          di as txt "  eiod_hesd            Table 5a       HESD  + 2 sub-indicators"
    if "`p'" == "eiod_hdlei"         di as txt "  eiod_hdlei           Table 5b       HDLEI + 2 sub-indicators"
    if "`p'" == "eiod_absolute_all"  di as txt "  eiod_absolute_all    Table 3        name your own variables"
    if "`p'" == "eiod_relative_all"  di as txt "  eiod_relative_all    Tables 4a-4g   name your own variables"
}
di as txt _n "  functions: `FN'"

* a courtesy probe, NOT a requirement - eiod_demogroup needs no cut-offs
capture _eiod_cutfile ""
if _rc {
    di as txt "  cut-offs : {err}not yet resolvable{txt}"
    di as txt "             set  global EIOD_REF ""<folder holding eiod_cutoffs.dta>"""
    di as txt "             (only needed before eiod_absolute / relative / hesd / hdlei)"
}
else {
    di as txt "  cut-offs : `s(path)'"
    di as txt "             found via `s(via)'"
}
di as txt _n "  Read progressnote.md before interpreting results - three findings"
di as txt    "  there affect how these metrics should be reported."
di as result "{hline 72}"
* ---------------------------------------------------------------------------- *
