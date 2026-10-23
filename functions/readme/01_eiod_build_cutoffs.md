# `eiod_build_cutoffs.do` — the reference dataset, and exactly how exact it is

**Builds** `eiod_cutoffs.dta` (616 rows) from `eiod_cutoffs.csv`
**Source** [Intake-EIOD-Methods-Paper-Jan2026-Final.pdf](https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf) — Table 3 and Tables 4a–4g
**Verified by** `eiod_validate.do` Parts A and B

This page answers four questions that have been asked about the numbers: what the two value columns mean, how eutrophication is handled, where the Table 5a/5b cut-offs are, and whether the stored values are really the published ones.

> **Changed 2026-10-22.** Intake corrected the eight Table 3 eutrophication thresholds: the published PDF prints them in kilograms, and both cut-off tables are meant to be in grams. **Those eight rows no longer match the PDF**, and are flagged by the new `value_source` column. The unit conversion `eiod_absolute` used to apply is gone with them. §2 has the detail.
>
> *(Changed 2026-10-14: the build stopped rescaling the 80 Table 4f rows, and the `value_published` and `scale_to_db_unit` columns were dropped.)*

---

# 1. What is in the file

616 rows, long format — one row per **metric × indicator × demographic group × row**.

| Column | What it is |
|---|---|
| `metric` | `abs` = Table 3; `rel` = Tables 4a–4g |
| `table` | the source table in the paper |
| `indicator`, `indicator_label`, `unit` | the seven EIOD indicators |
| `demogroup` 1–8, `demogroup_label`, `sex`, `age_min`, `age_max` | the published columns |
| `row_order`, `percentile` | for `rel`: which decile row. `percentile` is missing on printed row 10 |
| **`value_published_str`** | **the cut-off as literal text, exactly as printed** |
| **`value`** | the same number parsed to `double` — **nothing is rescaled here** |
| **`value_source`** | `published`, or `intake correction 2026-10` for the eight corrected rows |

`unit` is what that table is printed in - the same across both tables for every indicator. `value_source` is `published` for 608 rows and `intake correction 2026-10` for the eight Table 3 eutrophication thresholds, which are the only rows that do not match the PDF. See §2.

## Row counts

| | |
|---|---|
| `abs` | 7 indicators × 8 groups = **56** |
| `rel` | 7 indicators × 8 groups × 10 rows = **560** |
| **total** | **616** |

Of the 10 `rel` rows per group, only **nine** are cut-points — P10 … P90. Printed row 10 repeats P90 as a lower bound and carries a missing `percentile`, which is how `eiod_relative` filters it out before asserting it has found 72 cut-points per indicator.

---

# 2. Eutrophication: eight cut-offs corrected by Intake

**Everything in this file is the cut-off exactly as received — nothing is rescaled.** For 608 rows "as received" means "as printed in the methods paper". The remaining **eight** are corrections Intake supplied by email in October 2026, and `value_source` marks them:

```stata
. list demogroup_label value value_source if value_source != "published", noobs
```

The build asserts both facts:

```stata
assert value == real(value_published_str)
cap confirm variable scale_to_db_unit
assert _rc != 0                         // the rescaling column must not come back
count if value_source != "published"
assert r(N) == 8
```

## What was wrong

The paper prints the **Table 3 eutrophication** row in **kilograms** PO₄³⁻eq, while Table 4f — and the EIOF country databases — use **grams**:

| | value for Male 10+, as printed | unit |
|---|---:|---|
| Table 3 (`metric == "abs"`) | 0.0267453228 | **kg** PO₄³⁻eq |
| Table 4f (`metric == "rel"`, P10) | 18.4448415122 | **g** PO₄³⁻eq |

A ratio of about **690**, which is a unit difference and not a difference in environmental standard. Intake confirmed that both tables are intended to be in grams, and supplied corrected Table 3 values.

## What changed, and what did not

**The quantity did not change.** The corrected values are the printed ones × 1000, carried to full precision:

| Demographic group | PDF (kg) | shipped (g) |
|---|---:|---:|
| Male 0–1.9 yr | 0.0076827204 | 7.6827203674384066 |
| Male 2–4.9 yr | 0.0119198764 | 11.919876448673117 |
| Male 5–9.9 yr | 0.0164158298 | 16.415829847434384 |
| Male 10+ yr | 0.0267453228 | 26.745322780673799 |
| Female 0–1.9 yr | 0.0074439228 | 7.4439228426109629 |
| Female 2–4.9 yr | 0.0110398856 | 11.039885569912013 |
| Female 5–9.9 yr | 0.0150718438 | 15.071843778053791 |
| Female 10+ yr | 0.0215133770 | 21.51337701058506 |

Divide any shipped value by 1000 and you recover the printed figure to the ten decimals the PDF gives. The build and `eiod_validate.do` both assert exactly that, so the two can never silently part company.

**No classification moves.** Tested on 400,000 simulated gram-scale values, the old behaviour (divide the user's grams by 1000, compare against the PDF's kilograms) and the new one (compare grams directly) agreed everywhere. They can differ only within about one ULP of a cut-off — and there the new path is the more exact, because it no longer divides before comparing.

## How to use it

**Supply eutrophication in grams, as the EIOF database gives it to you, and convert nothing.** Every indicator now uses one unit across both tables:

```
Table 3 - absolute threshold  eutroph (g PO4(3-)eq per capita per day)
  created abs_eutroph
  note: the Table 3 eutrophication thresholds were CORRECTED BY INTAKE
         in Oct 2026 and DIFFER FROM THE PUBLISHED PDF, which prints them
         in kg. Both tables are in grams; supply grams, convert nothing.
  below threshold:  54.4% of 3000 diets
```

> **If you have a script written before October 2026 that divided eutrophication by 1000 before calling `eiod_absolute`, remove the division.** The command used to do it for you and no longer does; dividing now would make results wrong by a factor of a thousand in the other direction.

## How the problem was found

Worth recording, because the same reasoning applies to any reference table shipped without units.

The paper states no unit for Tables 4a–4g anywhere. The decisive test was that the ratio between the two tables is **constant across all eight demographic groups** — a methodological difference would vary by group, a unit difference cannot. Comparing that ratio across indicators put eutrophication three orders of magnitude outside the range of the other six:

| Indicator | Table 4 P10 ÷ Table 3 threshold |
|---|---:|
| Pasture land use | 0.026 |
| Total land use | 0.285 |
| Water use | 0.346 |
| Biodiversity loss | 0.548 |
| Arable land use | 0.688 |
| Greenhouse gas emissions | 1.449 |
| **Eutrophication (as published)** | **689.647** |
| **Eutrophication ÷ 1000** | **0.690** |

Supporting evidence: the EIOF databases report `Eutr. (g PO43-e/kg)` while every other column matches the paper's unit, and the kilogram reading implies a 10th-percentile adult diet of 18.4 kg PO₄³⁻eq **per day**. That analysis was put to Intake as a technical note; the correction above is their reply.

**For the other six indicators there is no correction and no conversion**, and both tables use the same unit.

---

# 3. Where are the Table 5a and 5b cut-offs?

**They are not in the file, and they should not be.** Tables 5a and 5b define no new cut-offs. Each reuses a cut-off that is already there:

| Composite | Diet-quality criterion | Environmental criterion | Where that number comes from |
|---|---|---|---|
| **HESD** (5a) | GDQS ≥ 23 | biodiversity < absolute threshold | **Table 3, `biodiv`, `metric == "abs"`** |
| **HDLEI** (5b) | GDQS ≥ 23 | biodiversity < P30 | **Table 4g, `biodiv`, `metric == "rel"`, `percentile == 30`** |

So to check what HESD compared a respondent against:

```stata
use eiod_cutoffs.dta, clear
keep if metric == "abs" & indicator == "biodiv"
list demogroup value_published_str value, noobs
```

and for HDLEI:

```stata
keep if metric == "rel" & indicator == "biodiv" & percentile == 30
```

The GDQS cut-off of **23** is not in the dataset either — it is a scalar, not a table, and lives as the `gdqscut(23)` default of both composite commands.

## Why the code has no copy of these numbers

`eiod_hesd` and `eiod_hdlei` do not re-implement the comparison. They **call** the standalone command:

```stata
* in eiod_hesd
qui eiod_absolute biodiv, value(`biodiversity') group(`group') generate(`envall') ...

* in eiod_hdlei
qui eiod_relative biodiv, value(`biodiversity') group(`group') below(30) ...
```

That is why you found no cut-off values inside those two files — there are none to find. `hesd_envsust` is identical by construction to the standalone Table 3 biodiversity metric, and `hdlei_lowimpact` to the Table 4g `below(30)` flag. `eiod_validate.do` **Part H** asserts the equality and **Part B** traces the Table 5 criteria back to Tables 3 and 4g.

*(Those calls are run `quietly` and re-reported by the composite. Before October 2026 they were not, which is why the output showed `created __000001` — Stata's internal name for the temporary column that becomes `hesd_envsust`. It was never a naming fault, but it read like one.)*

---

# 4. Are the stored numbers exactly the published ones?

**Yes — and as of October 2026 you can check it without trusting any numeric rendering at all.**

## The two layers

| Column | Type | What it guarantees |
|---|---|---|
| `value_published_str` | `str` | the literal characters from the paper, never through a numeric type |
| `value` | `double` | the nearest IEEE 754 double to that text — **and nothing else is done to it** |

The build asserts the round trip:

```stata
gen double _vp_back = real(value_published_str)
assert _vp_back == value
```

So the numeric column reproduces the literal text exactly, for all 616 rows.

## What the display was doing, and why it looked wrong

Storage was never the problem. **The display format was.** Both numeric columns were `%10.0g`, which shows about 8 significant digits, so

| | |
|---|---|
| published | `14.2377570161` |
| shown as | `14.237757` |

That is a rendering, not a stored value. The format is now `%18.14g`, chosen because **the widest cut-off in the table needs 14 significant digits**:

| Significant digits needed | Rows |
|---:|---:|
| 8 | 4 |
| 9 | 22 |
| 10 | 57 |
| 11 | 335 |
| 12 | 122 |
| 13 | 61 |
| **14** | **15** |

`g` format drops trailing zeros, so a value needing 9 digits is not padded out to 14.

## The same fix in the metric commands

`eiod_absolute`'s `threshvar()` and `eiod_relative`'s new `cutvar()` now carry `%18.14g` too, so the threshold a respondent was compared against displays exactly as printed:

```
dgroup           thr_landtotal
Female 10+ yr    11.4525532925
Male 10+ yr      14.2377570161
```

against the published Table 3:

```
demogroup        value_published_str
Male 10+ yr      14.2377570161
Female 10+ yr    11.4525532925
```

Character for character.

> **`cutvar()` is new.** `eiod_relative` previously had no equivalent of `threshvar()`, so there was no way to see which decile boundary a diet was judged against. `cutvar()` stores the **lower bound of the assigned band** — the highest published percentile the value cleared. Band 1 is left missing, which is correct: nothing is published below P10.

## One honest caveat about binary floating point

A `double` cannot hold most decimal fractions exactly — that is true of every statistical package, not of this one. What *is* guaranteed here:

- the stored double is the **nearest double** to the published decimal;
- it **round-trips** back to that decimal;
- `value_published_str` holds the decimal itself, so the published figure is in the file as text regardless.

If an exact decimal comparison is ever needed, compare against `value_published_str`.

---

# 5. The build, step by step

| Step | What happens |
|---|---|
| 1 | import `eiod_cutoffs.csv` with `stringcols(13)` |
| 2 | parse to `double` with `real()` into `value`; keep the string as `value_published_str` |
| 3 | `assert !mi(...)` — `real()` returns missing on anything it cannot parse, so a malformed cell stops the build |
| 4 | **nothing is rescaled**; assert `scale_to_db_unit` has not come back, `value == real(value_published_str)`, and that exactly 8 rows carry a `value_source` other than `published` |
| 5 | assert the round trip text → double → text |
| 6 | structural checks: 56 `abs` + 560 `rel`; `isid` on the keys; age bands consistent |
| 7 | assert the `unit` column: one unit per indicator, except eutrophication which has two |
| 8 | label, format `%18.14g`, order, compress, save |
| 9 | write `eiod_cutoffs_wide_check.csv` — a wide rendering for eyeballing against the printed tables |

## Why `stringcols()` is not optional

`import delimited` types an 11-digit column as **float** if left to guess, and `recast double` afterwards cannot recover digits that were never read. Forcing the column to string and parsing it with `real()` is the only route that preserves the published precision. This was found the hard way — the first version of the build silently lost four significant digits on every cut-off.

---

# 6. Checking it yourself

Pick any cell of any printed table and find it:

```stata
use eiod_cutoffs.dta, clear

* Table 3, total land use, Male 10+
list value_published_str value if metric=="abs" & indicator=="landtotal" & demogroup==4, noobs

* Table 4g, biodiversity, Female 10+, the P30 row that HDLEI uses
list value_published_str value if metric=="rel" & indicator=="biodiv" ///
    & demogroup==8 & percentile==30, noobs
```

`eiod_cutoffs_wide_check.csv` lays the whole thing out group-by-group for comparison against the PDF.

*Last updated 2026-10-06.*
