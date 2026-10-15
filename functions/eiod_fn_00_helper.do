* **************************************************************************** *
* **************************************************************************** *
*                                                                              *
*   eiod_fn_00_helper.do                                                       *
*   INTERNAL HELPER - locate the cut-off dataset                               *
*                                                                              *
* **************************************************************************** *
* **************************************************************************** *

/*
  ** DEFINES        _eiod_cutfile

  ** PURPOSE        Find eiod_cutoffs.dta and return its path in s(path).
                    Every eiod_* function calls this, so the search rule lives
                    in exactly one place.

  ** SEARCH ORDER   highest priority first. The first one that resolves to an
                    existing file wins; nothing below it is consulted.

                      1. the cutoffs() option passed by the caller
                      2. global EIOD_REF          <- the one to set
                      3. global EIOD_CUTOFFS      <- accepted alias, kept so
                                                     older scripts keep working
                      4. global EIOD_HOME, trying
                           $EIOD_HOME/eiod_cutoffs.dta
                           $EIOD_HOME/outputs/eiod_cutoffs.dta
                      5. eiod_cutoffs.dta in the current working directory
                      6. anywhere on the adopath

  ** FILE OR        Every path-like source above may be given as either
     DIRECTORY        a FILE      .../somewhere/eiod_cutoffs.dta
                      a DIRECTORY .../somewhere
                    A path ending in .dta is taken as a file; anything else is
                    taken as a directory and /eiod_cutoffs.dta is appended. A
                    directory that happens to be named *.dta would be
                    misread - do not do that.

  ** WHY SO MANY    Because the package has to work from any working directory,
     ROUTES         in any project, without the analyst editing a do-file. Set
                    one global once and never think about it again; override
                    per call only when comparing two cut-off vintages.

  ** CALLED BY      eiod_absolute, eiod_relative, eiod_hesd, eiod_hdlei,
                    eiod_absolute_all, eiod_relative_all

  ** NOT FOR        direct use in an analysis. The leading underscore marks it
                    internal; it is documented here only so a reader can audit
                    how the cut-off file is resolved.

  ** LAST UPDATE    2026-10-05
*/

* ---------------------------------------------------------------------------- *
* _eiod_try  -  internal: does this path resolve to a readable .dta?
*               Accepts a file or a directory. Returns s(found) = the file.
* ---------------------------------------------------------------------------- *
capture program drop _eiod_try
program define _eiod_try, sclass
    version 18
    args raw

    sreturn clear
    local raw = subinstr(`"`raw'"', `"""', "", .)
    local raw = strtrim(`"`raw'"')
    if `"`raw'"' == "" exit

    * a path ending .dta is a file; anything else is a directory
    local lower = lower(`"`raw'"')
    if substr(`"`lower'"', -4, 4) == ".dta"  local cand `"`raw'"'
    else                                     local cand `"`raw'/eiod_cutoffs.dta"'

    capture confirm file `"`cand'"'
    if !_rc {
        sreturn local found `"`cand'"'
        exit
    }

    * tolerate a directory that was given WITH a trailing slash, and a file
    * path that was given without the .dta extension
    capture confirm file `"`raw'"'
    if !_rc {
        sreturn local found `"`raw'"'
        exit
    }
end
* ---------------------------------------------------------------------------- *


* ---------------------------------------------------------------------------- *
capture program drop _eiod_cutfile
program define _eiod_cutfile, sclass
    version 18

    /*
       Take the raw argument rather than parsing it with
       `syntax [anything(name=path everything)]'.

       Stata's syntax option type (string) does NOT strip the quotes the user
       typed, so a caller doing

           syntax , [ CUToffs(string) ]
           _eiod_cutfile `"`cutoffs'"'

       forwards a value that is already quoted, and the quotes then arrive
       here nested one level deeper than anything() expects. Reading `0'
       directly and stripping every quote character is immune to how many
       layers of forwarding the value has been through. A file path never
       contains a double quote, so nothing legitimate is lost.
    */
    * `: copy local 0' takes the contents verbatim. Plain `0' would EXPAND any
    * backtick-apostrophe pair that a caller's quoting left behind, turning a
    * forwarded path into an undefined macro reference and then into nothing.
    local path : copy local 0

    sreturn clear

    * ---- 1. Explicit path from the caller ---------------------------------- *
    * A caller that forwards an option the user never set arrives here as the
    * two-character string "" rather than as nothing at all. Stripping the
    * quote characters makes that case correctly read as "not supplied".
    local clean = subinstr(`"`path'"', `"""', "", .)
    local clean = strtrim(`"`clean'"')
    * a caller may have wrapped the value in a compound quote; remove one such
    * enclosing pair, but never strip apostrophes elsewhere - folder names
    * legitimately contain them
    if substr(`"`clean'"', 1, 1) == "`" & substr(`"`clean'"', -1, 1) == "'" {
        local clean = substr(`"`clean'"', 2, length(`"`clean'"') - 2)
        local clean = strtrim(`"`clean'"')
    }

    if `"`clean'"' != "" {
        _eiod_try `"`clean'"'
        if `"`s(found)'"' != "" {
            sreturn local path `"`s(found)'"'
            sreturn local via  "cutoffs() option"
            exit
        }
        * an explicit path that does not exist is an error, not a reason to
        * fall through and silently use a different file
        di as error `"cutoffs() does not resolve to a file: `clean'"'
        di as error  "  give either the .dta itself or the folder holding it"
        exit 601
    }

    * ---- 2-3. The globals, in order of preference --------------------------- *
    foreach g in EIOD_REF EIOD_CUTOFFS {
        if `"${`g'}"' != "" {
            _eiod_try `"${`g'}"'
            if `"`s(found)'"' != "" {
                sreturn local path `"`s(found)'"'
                sreturn local via  "global `g'"
                exit
            }
            di as error `"global `g' is set but does not resolve to a file:"'
            di as error `"  ${`g'}"'
            exit 601
        }
    }

    * ---- 4. Derived from EIOD_HOME ------------------------------------------ *
    * "/dta" was added 2026-10-14 when the package folders were reorganised and
    * the reference dataset moved to <home>/dta/. The bare "" and "/outputs"
    * branches are kept so scripts written against the old flat layout, and
    * anyone pointing EIOD_HOME at the repository root, still resolve.
    if `"$EIOD_HOME"' != "" {
        foreach sub in "/dta" "" "/outputs" "/outputs/dta" {
            _eiod_try `"$EIOD_HOME`sub'"'
            if `"`s(found)'"' != "" {
                sreturn local path `"`s(found)'"'
                sreturn local via  "global EIOD_HOME"
                exit
            }
        }
    }

    * ---- 5. The current working directory ----------------------------------- *
    _eiod_try "eiod_cutoffs.dta"
    if `"`s(found)'"' != "" {
        sreturn local path `"`s(found)'"'
        sreturn local via  "current directory"
        exit
    }

    * ---- 6. Anywhere on the adopath ------------------------------------------ *
    capture findfile eiod_cutoffs.dta
    if !_rc {
        sreturn local path `"`r(fn)'"'
        sreturn local via  "adopath"
        exit
    }

    * ---- Give up with instructions, not a bare error code -------------------- *
    di as error "cannot locate eiod_cutoffs.dta"
    di as error "  set ONE of these once, at the top of your do-file:"
    di as error `"    global EIOD_REF  "<folder holding eiod_cutoffs.dta>""'
    di as error `"    global EIOD_HOME "<folder holding the eiod package>""'
    di as error "  or pass it per call with the cutoffs() option."
    di as error "  If the file does not exist yet, build it with eiod_build_cutoffs.do."
    exit 601
end
* ---------------------------------------------------------------------------- *
