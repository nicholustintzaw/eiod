---
title: "eiod — Intake EIOD metrics for Stata"
subtitle: "Environmental Impact of Diets: Tables 3, 4a–4g, 5a and 5b as Stata commands"
---

# eiod

[![Documentation](https://img.shields.io/badge/docs-github.io-2f5d8a)](https://nicholustintzaw.github.io/eiod/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Stata](https://img.shields.io/badge/Stata-18-1a5f7a)](https://www.stata.com)
[![R companion: reiod](https://img.shields.io/badge/R%20companion-reiod-2d6e2d)](https://github.com/nicholustintzaw/reiod)

A small set of Stata commands implementing the metrics in **[Intake-EIOD-Methods-Paper-Jan2026-Final.pdf](https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf)**. No `.ado` installation, no SSC dependencies — plain do-files you load at the top of a session.

**Stata 18** · **v0.1.0** · **2026-10-14**

> **Reviewers:** the most directly reviewable artefact is **`functions/dta/eiod_cutoffs_wide_check.csv`**, which lays the 616 transcribed cut-offs out group-by-group for comparison against the printed tables. Known open points are raised as GitHub issues; the one that affects the numbers is the eutrophication unit reading, set out in [the reference-data documentation](https://nicholustintzaw.github.io/eiod/01_eiod_build_cutoffs.html).

> **This package does not contain the EIOF database.** It implements the published metric *cut-offs* and applies them to impact values you have already derived. Matching food items to impact factors, applying the adjustment factors, and summing to the respondent-day is upstream work this package starts after. It also does not calculate the Global Diet Quality Score; the composites take a GDQS value as input.

## Install

There is nothing to install. Clone or download, and point one global at the package folder:

```bash
git clone https://github.com/nicholustintzaw/eiod.git
```

---

# 1. Thirty-second start

```stata
clear all                                    // this drops programs, so load AFTER it

global EIOD_HOME "C:/path/to/eiod/functions" // the package folder
                                             // (the cut-offs are found in its dta/ subfolder)
do "$EIOD_HOME/eiod_load_functions.do"

eiod_demogroup, age(age_yr) sex(sex_c) generate(dgroup)

eiod_absolute_all, group(dgroup)   ///
    landtotal(land_ado)            ///
    ghg(ghg_ado)                   ///
    biodiv(biodiv_ado)
```

That is the whole setup. Two globals, one `do`, then commands. Nothing is hardcoded to a machine or a project folder.

---

# 2. The commands

| Command | Table | What it produces |
|---|---|---|
| `eiod_demogroup` | column headings | the 8 age × sex groups every other command needs |
| `eiod_absolute` | 3 | one indicator against the absolute planetary-boundary share |
| `eiod_relative` | 4a–4g | one indicator's decile band in the global reference distribution |
| `eiod_hesd` | 5a | HESD composite **+ 2 decomposed sub-indicators** |
| `eiod_hdlei` | 5b | HDLEI composite **+ 2 decomposed sub-indicators** |
| `eiod_absolute_all` | 3 | Table 3 across several indicators, **your variable names** |
| `eiod_relative_all` | 4a–4g | Tables 4a–4g across several indicators, **your variable names** |
| `eiod_check_impact` | — | QC on your input variables before you compute anything |

The seven indicators throughout:

| Keyword | Indicator | Unit |
|---|---|---|
| `landtotal` | total land use | m²·year |
| `landarable` | arable land use | m²·year |
| `landpasture` | pasture land use | m²·year |
| `ghg` | greenhouse gas emissions | kg CO₂eq |
| `eutroph` | eutrophication potential | kg PO₄³⁻eq |
| `water` | water use | litres |
| `biodiv` | biodiversity loss | PDF·year |

> **The keyword selects the cut-off table. It is not your variable name.** Your variable goes in `value()`, or in the matching option of the `_all` commands, and may be called anything.

---

# 3. Your variable names are yours

The commands never required you to rename anything — but until October 2026 the demo *looked* as though they did, because it used a loop whose indicator keyword doubled as the variable name. That pattern is gone, and the `_all` commands make the mapping explicit:

```stata
eiod_absolute_all, group(dgroup)   ///
    landtotal(land_ado)            ///
    landarable(cropland_ado)       ///
    landpasture(pasture_ado)       ///
    ghg(ghg_ado)                   ///
    eutroph(eutr_ado)              ///
    water(water_ado)               ///
    biodiv(biodiv_ado)
```

**Supply only what you hold.** Most projects have a subset:

```stata
eiod_relative_all, group(dgroup) below(30) ghg(ghg_ado) biodiv(biodiv_ado)
```

Nothing else is computed, no placeholder variables appear, and there is no warning — a partial set is the normal case, not an error.

Output names come from the **indicator key**, not your variable, so results stay comparable across datasets: `biodiv(biodiv_ado)` → `abs_biodiv`. Change with `prefix()`.

---

# 4. Where things live — no fixed directories

## Loading the commands

Resolved in this order, first hit wins. No absolute path is hardcoded anywhere.

| # | Source |
|---:|---|
| 1 | `$EIOD_FN` — the folder holding the `eiod_fn_*.do` files |
| 2 | **`$EIOD_HOME`** — the package folder. **This is the one to set.** The loader lives inside it, so `$EIOD_HOME` itself is normally the hit; `$EIOD_HOME/functions` is still tried, for anyone pointing one level up at the pre-October layout |
| 3 | `$EIOD_ROOT` — legacy, `<root>/outputs/functions` |
| 4 | `./functions` — if the working directory is one level up |
| 5 | `./` — if the working directory *is* the package folder |

## Finding the cut-offs

| # | Source |
|---:|---|
| 1 | the `cutoffs()` option — per call |
| 2 | **`$EIOD_REF`** — the one to set |
| 3 | `$EIOD_CUTOFFS` — accepted alias for older scripts |
| 4 | `$EIOD_HOME`, trying `/dta/` first, then the folder itself, then `/outputs/` and `/outputs/dta/` |
| 5 | `./eiod_cutoffs.dta` |
| 6 | the adopath |

Any of these may be **a file or a folder**:

```stata
global EIOD_REF "D:/shared/eiof"                    // folder
global EIOD_REF "D:/shared/eiof/eiod_cutoffs.dta"   // file — same result
```

A `cutoffs()` path that does not resolve is an **error**, never a silent fallback to a different file.

> **Changed in October 2026.** The loader used to overwrite `$EIOD_CUTOFFS` with its own guess and then refuse to load *anything* if no file sat at that exact spot — even `eiod_demogroup`, which never reads the cut-offs. Both behaviours are gone. The loader no longer touches the cut-off setting; the file is resolved per call, at the moment it is needed.

## Loading only part of the package

```stata
do "$EIOD_HOME/eiod_load_functions.do"                      // everything
do "$EIOD_HOME/eiod_load_functions.do" demogroup absolute   // just these
do "$EIOD_HOME/eiod_load_functions.do" hesd                 // pulls in absolute
```

Keywords: `demogroup` `absolute` `relative` `hesd` `hdlei` `batch` `all`. Dependencies are added automatically — `hesd` calls `eiod_absolute`, so asking for one gets the other.

Honestly: loading everything costs milliseconds. Selective loading exists because it was asked for, not because the full load is expensive.

> **`clear all` drops all programs.** If your do-file begins with it, load *after*. Plain `clear` is safe. Every function file starts with `capture program drop`, so re-loading at any time is harmless.

---

# 5. Input QC — and what the precision risk actually is

`eiod_absolute` and `eiod_relative` check the input variable before computing anything. The risk was **measured** on 200,000 simulated respondent-days against the real cut-offs:

| Condition | Result |
|---|---|
| `float` storage → absolute classification flips | **0 of 200,000** |
| `float` storage → relative band changes | **1 of 200,000** (water) |
| **float underflow** at ~10⁻⁴⁰ | **200,000 of 200,000 → exactly zero** |
| **integer** storage of ghg | **mean 3.836 → 3.336, a 13% bias** |

**The headline is not the expected one.** Plain `float` at EIOF magnitudes is very nearly harmless — biodiversity at 10⁻¹³ sits comfortably inside float range (smallest normal ≈ 1.2×10⁻³⁸). What is destructive is **integer storage**, which truncates silently, and **underflow**, which happens as soon as biodiversity is expressed per gram rather than per kilogram, or left at ingredient level before summing to the day.

```stata
eiod_check_impact land_ado ghg_ado biodiv_ado          // standalone report
eiod_absolute ghg, value(ghg_ado) group(dg) generate(a) strict   // stop on error
eiod_absolute ghg, value(ghg_ado) group(dg) generate(a) nocheck  // skip the check
```

By default a failed check **prints and continues**, so existing scripts do not break. `strict` makes it `exit 459`.

**What it cannot check:** that your unit matches the EIOF database, and that the value is a respondent-*day* total already summed across ingredients. Neither is inferable from the numbers.

---

# 6. Three findings that affect how you report these metrics

Read these before writing up anything.

**1. HESD and HDLEI are nested, not independent.** The HDLEI environmental cut-off is uniformly **1.52× stricter**, so `hdlei == 1` implies `hesd == 1` in every demographic group. Proved algebraically and asserted in `eiod_validate.do` Part J. Do not present them as two dimensions of a 2×2 — one cell is structurally empty and the same respondents are counted twice.

**2. The relative reference distribution is country-level.** It is built from Food Balance Sheet data — national availability averages, not individual consumption (paper p. 5). A band is a statement about position relative to *national average availability patterns*, not relative to other people or other days. Worth a sentence in any methods section.

**3. The composites exclude under-2s by design.** Tables 5a/5b print six columns, not eight: the GDQS is not validated below age 2. All four outputs are missing for groups 1 and 5. If your sample includes under-2s, decide explicitly whether they belong in the analysis sample — it changes every denominator.

**4. Eutrophication is printed in two different units — supply it in GRAMS.** Table 3 prints it in **kg** PO₄³⁻eq; Table 4f prints it in **g**. Both numbers in `eiod_cutoffs.dta` are exactly as published. The EIOF country databases report `Eutr. (g PO43-e/kg)`, so your respondent total is already in grams: `eiod_relative` needs nothing, and `eiod_absolute` divides by 1000 for you.

**You can see it happen.** The converted value is kept as `<yourvar>_kg`, so the whole chain reads off one table:

```stata
. list eutr_ado eutr_ado_kg thr_eutroph abs_eutroph in 1/4, noobs abbrev(14)

  +---------------------------------------------------------------------+
  |  eutr_ado         eutr_ado_kg   thr_eutroph             abs_eutroph |
  |---------------------------------------------------------------------|
  |  28.12399    .028123990101136    .021513377   At or above threshold |
  | 13.702354    .013702354382423    .021513377         Below threshold |
  | 10.901663    .010901662567893   .0267453228         Below threshold |
  | 54.282283    .054282282809918   .0267453228   At or above threshold |
  +---------------------------------------------------------------------+
```

grams → kilograms → compared against the published Table 3 threshold → result. **No published cut-off is ever altered**; the only thing that moved is your own value, and it is sitting there to be checked. The unit reading is an inference **not confirmed by Intake** — see `functions/readme/01_eiod_build_cutoffs.md` §2.

---

# 6b. Are the cut-offs exactly the published ones?

**Yes — every one of the 616, with nothing rescaled.** Since October 2026 the dataset carries the published number and nothing derived from it:

| Column | Type | |
|---|---|---|
| `value_published_str` | string | **the literal characters from the paper**, never through a numeric type |
| `value` | double | the nearest IEEE 754 double to that text; round-trips back to it (asserted at build) — and what the commands use |

The `value_published` and `scale_to_db_unit` columns are **gone**. Until October 2026, 80 relative eutrophication rows were stored pre-divided by 1000 so that every cut-off sat on one internal scale; it worked, but it meant 80 shipped numbers could not be found anywhere in the methods paper. The conversion now happens inside `eiod_absolute`, applied to *your* variable. **Pick any row and you will find it, character for character, in the PDF.**

The display format is `%18.14g`, because the widest cut-off in the table needs **14 significant digits**. The old `%10.0g` showed about 8, so `14.2377570161` appeared as `14.237757` — a rendering, never a stored value.

`threshvar()` on `eiod_absolute` and the new `cutvar()` on `eiod_relative` carry the same format, so the threshold a respondent was judged against prints exactly as published.

**Table 5a and 5b define no new cut-offs.** HESD reuses the Table 3 biodiversity absolute threshold; HDLEI reuses the Table 4g P30. Both composites obtain them by *calling* `eiod_absolute` / `eiod_relative`, so there is no second copy in the code and nothing extra in the dataset.

---

# 7. Files

`functions/` is the whole package: the loader, the commands, the reference data, the demo, the verification suite and the documentation sources all sit under it. **`$EIOD_HOME` is that folder.**

```
eiod/
├── README.md                            this document
├── LICENSE                              MIT for the code; NOT for the cut-off values
├── CITATION.cff                         how to cite this and the methods paper
├── NEWS.md                              changelog
├── build_docs.sh                        regenerates docs/ from the readme/ sources
├── docs/                                the GitHub Pages site (generated — do not edit)
└── functions/                           ← $EIOD_HOME
    ├── eiod_load_functions.do           the loader — the one line at the top of your script
    ├── eiod_fn_00_helper.do             locate the cut-off file
    ├── eiod_fn_01_demogroup.do          the 8 groups
    ├── eiod_fn_02_absolute.do           Table 3
    ├── eiod_fn_03_relative.do           Tables 4a–4g
    ├── eiod_fn_04_hesd.do               Table 5a
    ├── eiod_fn_05_hdlei.do              Table 5b
    ├── eiod_fn_06_batch.do              the _all wrappers
    ├── eiod_fn_07_check.do              input QC
    ├── dta/
    │   ├── eiod_build_cutoffs.do        builds eiod_cutoffs.dta from the paper
    │   ├── eiod_cutoffs.csv             the transcription, 616 rows
    │   ├── eiod_cutoffs.dta             ← found automatically; $EIOD_REF if you move it
    │   └── eiod_cutoffs_wide_check.csv  wide rendering, for eyeballing against the PDF
    ├── demo/
    │   ├── eiod_demo.do                 worked example — copy this
    │   ├── eiod_demo_data.dta           3,000 synthetic respondent-days
    │   └── eiod_demo_results.xlsx       the demo's summary tables
    ├── validate/
    │   └── eiod_validate.do             10-part verification suite
    └── readme/                          markdown sources; the rendered site is in docs/
        ├── 01_eiod_build_cutoffs.md     ← the reference numbers, and how exact they are
        ├── 02_eiod_demogroup.md
        ├── 03_eiod_absolute.md          ← Table 3, and the eutrophication conversion
        ├── 04_eiod_relative.md          ← the calculation, step by step
        ├── 05_eiod_composites.md
        └── 06_eiod_infrastructure.md
```

Read the documentation at **<https://nicholustintzaw.github.io/eiod/>** rather than opening the
markdown — the rendered pages carry the tables and worked examples properly.

`docs/` is **generated**. Edit `functions/readme/*.md` and run `./build_docs.sh`; CI fails if
the two are out of step.

**Each function has its own README** in `functions/readme/`, numbered in reading order, giving the original table it implements and a line-by-line account of what the code does — so the calculation can be checked by anyone, without reading Stata. `04_eiod_relative.md` is the most worth reading: it shows the band rule, the `>=` boundary convention and the missing-value guard, with a worked example you can verify against the printed table.

> With `$EIOD_HOME` set to `functions/`, the cut-off file is found at `dta/eiod_cutoffs.dta` without any further setting. `$EIOD_REF` is only needed if you keep the reference data somewhere else — on a shared drive, say.

---

# 8. Verification

`eiod_validate.do` runs 10 independent checks and exits non-zero if any fails:

| Part | What it proves |
|---|---|
| A | 22 hand-typed values from the printed tables match the built dataset exactly |
| B | the Table 5 cut-offs trace back to Tables 3 and 4g |
| C | boundary behaviour — a value sitting exactly on a cut-off |
| D | missing values stay missing (the guard against Stata's missing-sorts-high) |
| E | band assignment, all 10 bands × 8 groups |
| F | age/sex group boundaries |
| G | HESD / HDLEI category logic |
| H | the decomposed sub-indicators equal the standalone metrics |
| I | where each absolute threshold sits in the relative distribution |
| J | the 1.52× nesting of the two composites |

Current status: **0 errors**, all 10 parts pass.

---

# 9. Getting started

Run `functions/demo/eiod_demo.do` from its own folder — it finds the package without any path
editing. It builds synthetic data with deliberately mismatched variable names (`land_ado`,
`ghg_ado`, …), runs every command, shows the eutrophication g→kg conversion end to end, and
asserts that the batch wrappers reproduce the single-indicator commands exactly.

Then copy it and point it at your own data.

---

# 10. Licence, citation and contributing

**Code:** MIT — see [`LICENSE`](LICENSE).

**The 616 cut-off values are not covered by that licence.** They are transcribed from Tables 3
and 4a–4g of Intake's methods paper and any rights in them rest with Intake. Whether a licence
condition attaches to redistributing them has been put to Intake and is not yet answered.

**Citation:** see [`CITATION.cff`](CITATION.cff) — GitHub renders it as a "Cite this
repository" button. Please cite the methods paper as well as the package.

**Companion R implementation:** [`reiod`](https://github.com/nicholustintzaw/reiod). Both read
the same cut-off CSV, and CI checks that the two copies have not drifted apart.

**Feedback:** open an issue. There are templates for a methods query, a bug and a feature
request. If you are reviewing the numbers rather than the code, start from
[the reference-data documentation](https://nicholustintzaw.github.io/eiod/01_eiod_build_cutoffs.html)
and `functions/dta/eiod_cutoffs_wide_check.csv`.

---

# 11. Acknowledgements

The metric definitions and all 616 cut-off values are **Intake's**, from
[*Methods for Assessing Healthy, Environmentally Sustainable Diets Globally*](https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf)
(Intake — Center for Dietary Assessment, 2026). This package implements them; it did not derive them.

The code, documentation and verification suite in this repository were written with the
assistance of **Claude (Anthropic)**, used as a coding and writing assistant throughout
development. All methodological decisions, the reading of the Intake methods paper, the
verification of every result, and responsibility for the contents are the author's.

---

*Every figure in this README was read from a Stata run log; the precision measurements in §5
are from a 200,000-row simulation, not an estimate.*
