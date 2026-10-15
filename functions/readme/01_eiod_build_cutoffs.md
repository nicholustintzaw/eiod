# `eiod_build_cutoffs.do` — the reference dataset, and exactly how exact it is

**Builds** `eiod_cutoffs.dta` (616 rows) from `eiod_cutoffs.csv`
**Source** [Intake-EIOD-Methods-Paper-Jan2026-Final.pdf](https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf) — Table 3 and Tables 4a–4g
**Verified by** `eiod_validate.do` Parts A and B

This page answers four questions that have been asked about the numbers: what the two value columns mean, how eutrophication is handled, where the Table 5a/5b cut-offs are, and whether the stored values are really the published ones.

> **Changed 2026-10-14.** The build no longer rescales anything. `value` is now the cut-off **exactly as printed**, for all 616 rows, and the `value_published` and `scale_to_db_unit` columns are gone. The eutrophication unit conversion moved into `eiod_absolute`, where it is applied to the *user's* variable. §2 explains why.

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
| **`value`** | the same number parsed to `double` — **exactly as printed, nothing rescaled** |

`unit` is what **that table** is printed in. For six indicators it is the same in both tables. For eutrophication it is not: `kg PO4(3-)eq` for Table 3, `g PO4(3-)eq` for Table 4f. See §2.

## Row counts

| | |
|---|---|
| `abs` | 7 indicators × 8 groups = **56** |
| `rel` | 7 indicators × 8 groups × 10 rows = **560** |
| **total** | **616** |

Of the 10 `rel` rows per group, only **nine** are cut-points — P10 … P90. Printed row 10 repeats P90 as a lower bound and carries a missing `percentile`, which is how `eiod_relative` filters it out before asserting it has found 72 cut-points per indicator.

---

# 2. Eutrophication is printed in two different units

**Nothing in this file is rescaled.** Every one of the 616 values is the number the methods paper prints. The build asserts it:

```stata
assert value == real(value_published_str)
cap confirm variable scale_to_db_unit
assert _rc != 0                         // the column must not come back
```

But eutrophication needs explaining, because **Table 3 and Table 4f are printed in different units**:

| | value for Male 10+ | `unit` |
|---|---:|---|
| Table 3 (`metric == "abs"`) | 0.0267453228 | **kg** PO₄³⁻eq |
| Table 4f (`metric == "rel"`, P10) | 18.4448415122 | **g** PO₄³⁻eq |

A ratio of about **690**, which is a unit difference and not a difference in environmental standard.

## The evidence

1. **The EIOF database reports eutrophication in grams.** The country databases store it as `Eutr. (g PO43-e/kg)` — checked across the Burkina Faso, Ethiopia, Ghana and Viet Nam files — while every other indicator matches the paper's unit (`m2/kg`, `kg CO2e/kg`, `L/kg`).
2. **The kilogram reading is physically impossible.** 18.4 kg PO₄³⁻eq per person per *day* is 6.7 tonnes a year, more than the mass of food a person eats.
3. **The gram reading reconciles the two tables in 8 of 8 demographic groups.** Converted to grams, the Table 3 threshold lands between P40 and P50 of Table 4f every time, across a 3.5× spread of values — where the two land indicators also sit. Unconverted it falls below P10, a position only greenhouse gases occupy and which the paper documents for greenhouse gases alone.
4. **The two tables have different sources.** Table 3 from Moberg et al. (2020) / Hallström et al. (2022), who work in kg; Tables 4a–4g from the WWF Planet-Based Diets Database.

## Where the conversion lives — and why not here

**In `eiod_absolute`, applied to the user's variable.** Not in this dataset.

Until 2026-10-14 the build multiplied the 80 Table 4f rows by 0.001, so every cut-off sat on one internal scale. It was arithmetically sound and it was documented, but it meant **80 of the shipped numbers could not be found anywhere in the methods paper** — and the entire point of shipping this dataset is that a reader can check it line by line against the PDF.

So: supply eutrophication in **grams**, as the EIOF database gives it to you. `eiod_relative` needs nothing. `eiod_absolute` divides by 1000 and reports that it did:

```
Table 3 - absolute threshold  eutroph (kg PO4(3-)eq per capita per day)
  created abs_eutroph
  unit: eutroph: your values divided by 1000 (g -> kg PO4(3-)eq) to match Table 3
         supply this indicator in GRAMS, as the EIOF database reports it
         the published cut-off is NOT altered - see eiod_absolute
```

> **Still an inference, not something Intake has confirmed.** The paper never states a unit for the Table 4 series at all. The question is with Intake; until it is answered, treat any eutrophication result as carrying this assumption. If the answer differs, the fix is one `local convfac` in `eiod_fn_02_absolute.do` — **the reference data needs no change, because it was never adjusted.** That is the second reason the conversion was moved out of it.

**For the other six indicators there is no conversion anywhere**, and both tables use the same unit.

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
| 4 | **nothing is rescaled**; assert `scale_to_db_unit` has not come back, and `value == real(value_published_str)` |
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
