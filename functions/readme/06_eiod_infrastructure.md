# `eiod_fn_00_helper.do`, `eiod_fn_06_batch.do`, `eiod_fn_07_check.do` — infrastructure

Three files that compute no metric. They decide **where the cut-offs come from**, **how you name your variables**, and **whether your inputs are fit to use**.

---

# `eiod_fn_00_helper.do` — locating the cut-off dataset

**Defines** `_eiod_cutfile`, `_eiod_try` (both internal; the underscore means do not call them in an analysis)

Every metric command resolves the cut-off file through this one program, so the search rule exists in exactly one place.

## Search order — first hit wins

| # | Source | Notes |
|---:|---|---|
| 1 | the `cutoffs()` option | per-call override. If given and unresolvable → **error**, never a silent fallback |
| 2 | `$EIOD_REF` | **the one to set** |
| 3 | `$EIOD_CUTOFFS` | accepted alias, so older scripts keep working |
| 4 | `$EIOD_HOME` | tries `$EIOD_HOME/eiod_cutoffs.dta` then `$EIOD_HOME/outputs/eiod_cutoffs.dta` |
| 5 | current working directory | `./eiod_cutoffs.dta` |
| 6 | the adopath | via `findfile` |

Any of 1–5 may be given as **a file or a folder**. A path ending `.dta` is taken as a file; anything else is taken as a folder and `/eiod_cutoffs.dta` is appended.

```stata
global EIOD_REF "D:/shared/eiof"                    // folder
global EIOD_REF "D:/shared/eiof/eiod_cutoffs.dta"   // file — same result
```

The resolved path and the route taken are returned in `s(path)` and `s(via)`, which is what the loader prints.

## Two parsing traps this file handles

**`syntax` with `(string)` keeps the quotes.** An option typed `cutoffs("refdata")` arrives in the called program as the *nine*-character string `"refdata"`, quotes included. A caller that then re-wraps it in a compound quote produces `` `""refdata""' ``, and the backtick-apostrophe pair expands as an undefined macro — **silently empty**. The helper therefore reads its argument with

```stata
local path : copy local 0
```

which copies the contents verbatim without expansion, then strips quote characters and one enclosing compound-quote pair. A file path never contains a double quote, so nothing legitimate is lost. Apostrophes elsewhere are left alone — folder names legitimately contain them.

**An empty forwarded option is the two-character string `""`, not nothing.** Stripping quote characters makes that case read correctly as "not supplied" rather than as a file named `""`.

---

# `eiod_fn_06_batch.do` — name your own variables

**Defines** `eiod_absolute_all`, `eiod_relative_all`

## The problem these solve

`eiod_absolute` takes one indicator and one `value()` variable. Running seven means seven near-identical calls, and the obvious shortcut is

```stata
foreach i in landtotal ghg biodiv { eiod_absolute `i', value(`i') ... }
```

which works **only if your variables happen to be named** `landtotal`, `ghg`, `biodiv`. They will not be. An earlier version of the demo did exactly this, which made it look as though the package required those names. It never did — but the pattern it taught did.

## The fix: one option per indicator, holding your variable

```stata
eiod_absolute_all , group(dgroup)   ///
    landtotal(land_ado)             ///
    ghg(ghg_ado)                    ///
    biodiv(biodiv_ado)
```

Supply as few or as many as you hold. Indicators you do not name are simply not computed — no placeholder variables, no warnings, no need to fabricate a column.

The seven option names must be typed **in full**: `landtotal`, `landarable` and `landpasture` share a stem, so abbreviating would be ambiguous and Stata refuses it.

## Output names come from the indicator, not from your variable

| Command | Creates | Default prefix |
|---|---|---|
| `eiod_absolute_all` | `abs_landtotal`, `thr_landtotal`, … | `prefix(abs_)`, `threshprefix(thr_)` |
| `eiod_relative_all` | `rel_landtotal`, `mid_landtotal`, `rel_landtotal_lt30` | `prefix(rel_)`, `midprefix(mid_)` |

So `biodiv(biodiv_ado)` produces `abs_biodiv` whatever the input was called. That keeps results comparable across datasets whose inputs are named differently. Set `prefix()` if it clashes.

## No new logic

Both wrappers do nothing but loop and call the single-indicator command. Every threshold comparison, band assignment, missing-value rule and label still happens in `eiod_absolute` / `eiod_relative` exactly once. The demo asserts the equality:

```stata
eiod_absolute_all, group(dgroup) prefix(sub_) ghg(ghg_ado)
eiod_absolute ghg, value(ghg_ado) group(dgroup) generate(one_ghg)
assert sub_ghg == one_ghg
```

**Returns** `r(n_ind)`, `r(indlist)`, `r(varlist)`.

---

# `eiod_fn_07_check.do` — input QC

**Defines** `eiod_check_impact` (standalone report), `_eiod_precheck` (internal; run automatically by `eiod_absolute` and `eiod_relative` before anything is computed)

## Why, and what was actually measured

The indicators span 15 orders of magnitude — water around 600 litres, biodiversity around 8×10⁻¹³ PDF·year. A storage type that is harmless for one could be destructive for another, and Stata says nothing.

The risk was **measured** on 200,000 simulated respondent-days against the real cut-offs, not assumed:

| Condition | Result |
|---|---|
| `float` storage → absolute classification flips | **0 of 200,000** (biodiv, ghg, water, landtotal) |
| `float` storage → relative band changes | **1 of 200,000** (water) |
| largest relative error from float-storing a cut-off | 5.5 × 10⁻⁸ |
| cut-offs that underflow in float | **0** |
| **float underflow** at ~10⁻⁴⁰ | **200,000 of 200,000 flushed to exactly zero** |
| **integer** storage of ghg | **200,000 changed; mean 3.836 → 3.336, a 13% bias** |

**The headline is not the expected one.** Plain `float` at EIOF magnitudes is very nearly harmless — biodiversity at 10⁻¹³ sits comfortably inside float range, whose smallest normal value is about 1.2×10⁻³⁸. What is destructive is:

- **integer storage**, which truncates every value toward zero and biases the mean by double digits, silently;
- **underflow**, when the variable is `float` *and* the values are far below EIOF scale — which happens as soon as biodiversity is expressed per gram rather than per kilogram, or is left at ingredient level before summing to the day.

## The grading

| Check | Condition | Grade |
|---|---|---|
| storage | `byte` / `int` / `long` | **error** |
| storage | `float`, all values exactly zero | **error** |
| storage | `float`, smallest non-zero < 10⁻³⁷ | **error** |
| storage | `float` with some exact zeros | **error** |
| storage | `float`, otherwise | note |
| storage | `double`, all values exactly zero | **error** |
| sign | any negative value | **error** |
| scale | median > 10⁴ × or < 10⁻⁴ × the published cut-off median | warning (usually a unit mismatch) |

An "error" prints and lets the command continue by default, so an existing script does not break; add `strict` to make it stop with `r(459)`. `nocheck` skips the check entirely.

**The all-zero case needs its own test.** The obvious check — look at the smallest non-zero value — sees nothing once *every* value has already been flushed to zero. That gap was found by a test, not by inspection, and is now covered.

## Standalone use

```stata
eiod_check_impact land_ado ghg_ado biodiv_ado
eiod_check_impact biodiv_ado , indicator(biodiv) strict
```

Prints a type/range/zero-count table and then the graded findings.

## What it cannot check

- that the **unit** matches the EIOF database (m²·year, kg CO₂eq, kg PO₄eq, litres, PDF·year)
- that the value is a respondent-**day** total, already summed across every ingredient
- **that every consumed food was costed at all** — see below

### Incomplete EIOF coverage, and why no check can reach it

Not every food has an impact factor. The EIOF country databases mark foods with no available estimate, and such a food contributes **nothing** to the day's total — so a respondent who ate one has an impact understated by an unknown amount.

**This is not a gap in the check suite; it is outside what any check could observe.** `eiod_check_impact` and `_eiod_precheck` receive a variable holding one number per respondent-day. Whether that number was summed over five costed foods or four costed and one missing is not a property of the number. The aggregation discarded the evidence one step before the command was called.

The only detectable case is the degenerate one: if *every* food for a respondent lacked a factor and the upstream code produced `0` rather than missing, the zeros count in the standalone table shows it, and the `float with some exact zeros` rule above grades it. That rule exists for exactly this family of upstream faults — a diet that was consumed cannot have zero impact. **Partial coverage produces a perfectly ordinary number and leaves no trace.**

It matters more for these metrics than for most, because each respondent is compared against a **fixed external cut-off** rather than against the rest of the sample: uneven coverage shifts classifications with nothing in the output looking wrong.

**Handle it where the evidence still exists** — in the aggregation step that builds the day-level variable. Count the consumed items with no factor, or better the **share of consumed weight** that carries one, and report it with any prevalence. A share of the food list is not the same as a share of intake, and the two can differ by a lot in either direction.

Neither is inferable from the numbers alone. The scale check catches gross unit errors; it cannot catch a factor of three.

*Last updated 2026-10-05.*
