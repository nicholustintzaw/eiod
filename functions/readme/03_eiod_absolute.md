# `eiod_fn_02_absolute.do` — Table 3, absolute threshold metrics

**Defines** `eiod_absolute`
**Source** [Intake-EIOD-Methods-Paper-Jan2026-Final.pdf](https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf), Table 3 (p. 16); method p. 3
**Reads** `eiod_cutoffs.dta`, rows where `metric == "abs"`
**Verified by** `eiod_validate.do` Parts A, C, D, I

---

## 1. The original table

Table 3, *"Cut-Offs by Demographic Group for Absolute Threshold Metrics"* — **7 indicator rows × 8 demographic columns**, one number per cell:

| Indicator | Unit | M 0–1.9 | M 2–4.9 | … | F 10+ |
|---|---|---|---|---|---|
| Total land use | m²·year | < … | < … | | |
| Arable land use | m²·year | | | | |
| Pasture land use | m²·year | | | | |
| GHG emissions | kg CO₂eq | | | | |
| Eutrophication | kg PO₄³⁻eq | | | | |
| Water use | litres | | | | |
| Biodiversity loss | PDF·year | | | | |

Each cell is that group's share of the **per capita daily planetary boundary**, following Moberg et al. (2020) and Hallström et al. (2022), assuming a 7.7 billion population and converted to an average per capita *daily* threshold.

**This is a pass/fail against a planetary boundary.** It is not a statement about how a diet compares with other diets — that is `eiod_relative`, Tables 4a–4g.

## 2. The workflow

```
 STEP 1   validate the indicator keyword              one of 7, else exit 198
 STEP 2   validate output names; group ∈ 1..8         else exit 459
 STEP 2b  QC the input variable                       storage, sign, underflow, scale
 STEP 3   read the 8 thresholds into a temporary FRAME
 STEP 3b  put the USER'S values on this table's unit  ← eutrophication only
 STEP 4   apply the threshold, group by group    ← THE CALCULATION
 STEP 5   value-label the result
 STEP 6   report and return
```

### STEP 3b — the one unit conversion in the package

**Six of the seven indicators pass through untouched.** The EIOF database, the
methods paper and both cut-off tables agree on their units, so `convfac` is 1
and nothing happens.

**Eutrophication is the exception**, because the EIOF country databases report
it as `Eutr. (g PO43-e/kg)` — in grams — while Table 3 is printed in
kilograms:

```stata
tempvar vcmp
local convfac = 1
local convnote ""
if "`ind'" == "eutroph" {
    local convfac = 0.001
    local convnote "eutroph: your values divided by 1000 (g -> kg PO4(3-)eq) to match Table 3"
}
qui gen double `vcmp' = `value' * `convfac'
```

### The converted value is kept, not discarded

A conversion the user cannot see is a conversion the user has to take on trust. So the command leaves **`<yourvar>_kg`** behind — for `eutr_ado` you get `eutr_ado_kg` — and the whole chain reads off one table:

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

grams → kilograms → the published Table 3 threshold → the result.

**The comparison uses that very variable**, not a parallel copy, so what you see is literally what was tested. The demo asserts it:

```stata
assert reldif(eutr_ado_kg, eutr_ado / 1000) < 1e-12 if !mi(eutr_ado)
assert abs_eutroph == (eutr_ado_kg < thr_eutroph)   if !mi(eutr_ado_kg)
```

Housekeeping: the name is honoured by `replace`, a collision without `replace` is an error like any other `generate`, and a name longer than 32 characters is refused with a message telling you to shorten the input variable. `r(convvar)` returns the name, `r(convfac)` the multiplier.

In the R package the vector API means there is no dataset to write into, so the same information lands in the detail frame: `eiod_absolute_threshold(..., details = TRUE)` returns a `value_kg` column alongside `value`, `cutoff` and `below`.

### Three things about this are deliberate

1. **It converts the user's value, never the published cut-off.**
   `eiod_cutoffs.dta` holds exactly what the paper prints for all 616 rows, so
   it can be checked line by line against the PDF. Before 2026-10-14 the 80
   Table 4f rows were stored pre-divided and matched nothing in the source
   document.
2. **It is announced in the output**, every time, under `unit:`. It is the only
   place in the package where a number you supplied is altered before use, and
   it should be visible in your log.
3. **It is one local in one file.** If Intake confirms a different reading, the
   fix is `local convfac` and nothing else — the reference data needs no change,
   because it was never adjusted.

`eiod_relative` has no equivalent step: Table 4f is printed in grams, so a gram
input needs no conversion there.

> **Supply eutrophication in GRAMS.** See
> `01_eiod_build_cutoffs.md` §2 for the evidence, and note that the unit
> reading is an inference Intake has not yet confirmed.

### STEP 3 — eight numbers, asserted

```stata
qui keep if metric == "abs" & indicator == "`ind'"
if _N != 8 { ... exit 459 }
qui isid demogroup
```

Read in a `frame`, so the analyst's data in memory is never touched. If the cut-off file does not hold exactly eight thresholds for the indicator — one per group, no duplicates — the command stops rather than computing against a partial table.

### STEP 4 — the comparison

```stata
qui gen byte `generate' = .

forvalues g = 1/8 {
    qui replace `generate' = (`value' < `thr`g'') ///
        if `group' == `g' & !mi(`value')
}
```

**Strictly `<`, and that is deliberate.** The published cut-offs carry a "<" sign, so a diet sitting *exactly on* the threshold is **not** below it and is coded 0. `eiod_validate.do` Part C tests a value placed precisely on each threshold.

**The `!mi()` guard is load-bearing.** In Stata missing sorts *above* every real number, so `. < threshold` evaluates to **0** — a respondent with no impact data would be silently coded as *exceeding* the boundary. The guard leaves them missing instead. Part D tests this.

### Output coding

| Value | Meaning |
|---|---|
| 1 | Below threshold |
| 0 | At or above threshold |
| . | impact or group not observed |

`threshvar()` optionally stores the threshold each respondent was compared against, so a reader can see the number without opening the cut-off file.

## 3. Syntax

```stata
eiod_absolute INDICATOR , Value(varname) Group(varname) GENerate(name)
    [ THRESHvar(name) CUToffs(string) replace strict nocheck ]
```

| Keyword | Unit |
|---|---|
| `landtotal` `landarable` `landpasture` | m²·year |
| `ghg` | kg CO₂eq |
| `eutroph` | kg PO₄³⁻eq |
| `water` | litres |
| `biodiv` | PDF·year |

The keyword picks the **cut-off row**. Your variable goes in `value()` and may be named anything.

**Returns** `r(N)`, `r(N_miss)`, `r(pct)`, `r(ind)`, `r(unit)`.

## 4. The input must already be a respondent-DAY total

`value()` is the impact of everything the person ate that day, **already summed across every ingredient**. The command cannot tell a per-ingredient value from a daily total — it will happily compare a single ingredient against a whole-day planetary boundary share and report a very high pass rate. The scale check in STEP 2b catches gross cases; it cannot catch a factor of three.

## 5. Related

- `eiod_fn_03_relative.do` — the same seven indicators, positioned in a global distribution
- `eiod_fn_04_hesd.do` — calls this command for the biodiversity criterion of Table 5a
- `eiod_fn_06_batch.do` — `eiod_absolute_all` runs this across several indicators at once

*Last updated 2026-10-05.*
