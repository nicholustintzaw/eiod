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
| Eutrophication | **g** PO₄³⁻eq (corrected; the PDF prints kg) | | | | |
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
 STEP 4   apply the threshold, group by group    ← THE CALCULATION
 STEP 5   value-label the result
 STEP 6   report and return
```

### STEP 3b — no unit conversion, for any indicator

**There used to be one here, and its removal is the main change of October 2026.**

Between July and October the command divided eutrophication values by 1000 before comparing, because the published Table 3 printed that row in **kilograms** while Table 4f and the EIOF databases use **grams**. The converted value was kept as `<yourvar>_kg` so the step was visible.

**Intake confirmed that both tables are in grams** and supplied corrected Table 3 thresholds. Those now ship in `eiod_cutoffs.dta`, flagged by `value_source`, and the division is gone:

```stata
* nothing between reading the thresholds and applying them
forvalues g = 1/8 {
    qui replace `generate' = (`value' < `thr`g'') ///
        if `group' == `g' & !mi(`value')
}
```

**Supply eutrophication in GRAMS and convert nothing.** The command reports that these thresholds differ from the PDF, every time it is run on this indicator:

```
Table 3 - absolute threshold  eutroph (g PO4(3-)eq per capita per day)
  created abs_eutroph
  note: the Table 3 eutrophication thresholds were CORRECTED BY INTAKE
         in Oct 2026 and DIFFER FROM THE PUBLISHED PDF, which prints them
         in kg. Both tables are in grams; supply grams, convert nothing.
```

> **If you have a script written before October 2026** that divided eutrophication by 1000 before calling this command, **remove the division.** The command no longer does it for you, so dividing now makes results wrong by a factor of a thousand in the other direction.

**The quantities did not change** — the corrected thresholds are the printed ones × 1000 — so no classification moves. See `01_eiod_build_cutoffs.md` §2 for the evidence, the per-group table, and how the discrepancy was found.

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
