# `eiod_fn_03_relative.do` — Tables 4a–4g, relative benchmark metrics

**Defines** `eiod_relative`
**Source** [Intake-EIOD-Methods-Paper-Jan2026-Final.pdf](https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf), Tables 4a–4g (pp. 17–19), method p. 3
**Reads** `eiod_cutoffs.dta`, rows where `metric == "rel"`
**Verified by** `eiod_validate.do` Part E (all 10 bands × 8 groups) and Part I

> This is the function most worth checking line by line, because the band rule is easy to state and easy to get wrong at the boundaries. Everything below can be reproduced by hand from the published tables.

---

## 1. What the original table looks like

Each of Tables 4a–4g covers one indicator. The printed table has **8 demographic columns × 10 rows**. Table 4c (arable land, m²·year) in outline:

| Row | Band | M 0–1.9 | M 2–9.9 | … | F 20+ |
|---|---|---|---|---|---|
| 1 | < 10th percentile | < 0.153 | < 0.398 | … | < 0.372 |
| 2 | 10th to < 20th | 0.153–0.155 | … | | |
| … | … | | | | |
| 9 | 80th to < 90th | … | | | |
| 10 | 90th to 100th | ≥ 1.93 | … | | |

**Row 10 is not a separate cut-point.** It repeats P90 as a lower bound. So each column contains **nine** cut-points — P10, P20, …, P90 — and ten bands between and around them.

That is why the function asserts

```stata
8 groups × 9 cut-points = 72 rows
```

and errors if it finds anything else. The cut-off dataset stores the ten rows per group, with row 10 carrying a missing `percentile`; the function filters those out with `!mi(percentile)`.

## 2. Where the reference distribution comes from — a stated limitation

The percentiles are built from **Food Balance Sheet** data: country-level availability averages, not individual consumption (paper p. 5). A band therefore says where a diet sits relative to **national average availability patterns**, not relative to other individuals or other days. That belongs in any methods section that reports these numbers.

---

## 3. The workflow, step by step

```
         ┌────────────────────────────────────────────┐
 STEP 1  │ validate the indicator keyword             │  one of 7, else exit 198
         └────────────────────────────────────────────┘
 STEP 2  │ validate output names; group ∈ 1..8        │  else exit 459
         └────────────────────────────────────────────┘
 STEP 2b │ QC the input variable                      │  storage, sign, underflow, scale
         └────────────────────────────────────────────┘
 STEP 3  │ read 72 cut-points into a temporary FRAME  │  analyst's data untouched
         └────────────────────────────────────────────┘
 STEP 4  │ assign the band  ← THE CALCULATION         │
         └────────────────────────────────────────────┘
 STEP 5  │ value-label the 10 bands                   │
 STEP 6  │ optional midpoint  = band × 10 − 5         │
 STEP 7  │ optional below(N) flag = band ≤ N/10       │
 STEP 8  │ report and return                          │
```

### STEP 3 — why a frame

The cut-offs are read in a `frame`, not by `preserve`/`use`/`restore`. The analyst's data in memory is never touched, so the command is safe to run inside a loop or after `preserve` has already been used by the caller.

### STEP 4 — the band rule, in full

```stata
qui gen byte `generate' = .

forvalues g = 1/8 {
    qui replace `generate' = 1 if `group' == `g' & !mi(`value')

    forvalues k = 1/9 {
        qui replace `generate' = `generate' + 1 ///
            if `group' == `g' & !mi(`value') & `value' >= `p`g'_`k''
    }
}
```

**In words:** start every observation at band 1, then add 1 for each of the nine cut-points the impact value **equals or exceeds**.

| Impact value | Cut-points cleared | Band |
|---|---:|---:|
| below P10 | 0 | 1 |
| ≥ P10, below P20 | 1 | 2 |
| ≥ P20, below P30 | 2 | 3 |
| … | | |
| ≥ P80, below P90 | 8 | 9 |
| ≥ P90 | 9 | 10 |

**Check it by hand.** Take Table 4c, group "M 2–9.9", a diet of 0.40 m²·year. P10 = 0.398, so the first cut-point is cleared; if P20 = 0.52 then nothing further is. Band = 1 + 1 = **2**, i.e. "10th to < 20th". That matches the printed row.

### Boundary convention: `>=`, and it is deliberate

The printed bands read "10th to < 20th" — closed below, open above. A value sitting **exactly on** P20 therefore belongs to band 3, not band 2. The `>=` in the loop produces exactly that. `eiod_validate.do` Part C tests a value placed precisely on each cut-point.

### The missing-value guard is load-bearing

```stata
... & !mi(`value') & `value' >= `p`g'_`k''
```

In Stata **missing sorts above every real number**, so `. >= P90` is *true*. Without the `!mi()` guard every respondent with no impact data would clear all nine cut-points and land in **band 10 — the highest-impact band** — silently. The guard leaves them missing instead. Part D of the validator tests this.

### STEP 6 — the midpoint, and why to be careful with its mean

`midpoint = band × 10 − 5` gives 5, 15, 25, …, 95.

The paper reports "the mean relative benchmark percentile is between the 10th and 20th percentile", which this supports. **But** averaging the band index treats the bands as equally spaced on the impact scale, and they are not: in Table 4c the P10–P20 gap is 0.002 m²·year while the P80–P90 gap is 1.5 m²·year. The mean band is a legitimate summary of *position in the reference distribution*; it is **not** a summary of impact. For a mean impact, average the impact variable.

### STEP 7 — `below(N)`

```stata
local kband = `below' / 10
gen byte `belowvar' = (`generate' <= `kband') if !mi(`generate')
```

Band *k* covers percentiles up to *k*×10, so "below the Nth percentile" is "band ≤ N/10". `below(30)` reproduces the **HDLEI environmental criterion** of Table 5b, and `eiod_fn_05_hdlei.do` obtains it by calling this command rather than re-implementing it.

---

## 4. Syntax

```stata
eiod_relative INDICATOR , Value(varname) Group(varname) GENerate(name)
    [ MIDpoint(name) BELow(#) BELOWvar(name)
      CUToffs(string) replace strict nocheck ]
```

| Indicator keyword | Unit |
|---|---|
| `landtotal` | m²·year |
| `landarable` | m²·year |
| `landpasture` | m²·year |
| `ghg` | kg CO₂eq |
| `eutroph` | kg PO₄³⁻eq |
| `water` | litres |
| `biodiv` | PDF·year |

The keyword selects the **cut-off table**. Your variable goes in `value()` and may be called anything.

**Returns** `r(N)`, `r(N_miss)`, `r(ind)`, `r(unit)`, and `r(pct_below)` when `below()` is used.

## 5. Related

- `eiod_fn_02_absolute.do` — Table 3, the same seven indicators against a fixed planetary-boundary share
- `eiod_fn_05_hdlei.do` — calls this command with `below(30)`
- `eiod_fn_06_batch.do` — `eiod_relative_all` runs this across several indicators in one call

*Last updated 2026-10-05.*
