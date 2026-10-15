# Open questions

Four things this package cannot settle on its own. Each is filed as a GitHub issue so it can
be answered in one place, by the people who know, with the answer permanently attached to the
code it affects.

**Questions 1 and 2 are for Intake and affect the numbers.** Questions 3 and 4 are
administrative but gate publication.

---

## 1. Eutrophication: is Table 4f printed in grams?

**Affects:** every absolute-threshold eutrophication result, in this package and in `reiod`.
**Status:** open. The package currently assumes **yes**.

Tables 4a–4g carry no unit anywhere in the paper. For eutrophication, Table 4f's benchmarks
are about **690×** the Table 3 threshold for the same demographic group:

| Male 10+ | value | source |
|---|---:|---|
| Table 3, absolute threshold | 0.0267453228 | stated on p.29 to be kg PO₄³⁻eq |
| Table 4f, 10th percentile | 18.4448415122 | no unit given |

That reconciles exactly if **Table 3 is in kilograms and Table 4f is in grams**. Four things
point the same way:

1. **The EIOF country databases report eutrophication in grams** — the column is
   `Eutr. (g PO43-e/kg)` in the Burkina Faso, Ethiopia, Ghana and Viet Nam files, while every
   other indicator matches the paper's unit (`m2/kg`, `kg CO2e/kg`, `L/kg`).
2. **The kilogram reading is physically impossible** — 18.4 kg PO₄³⁻eq per person per *day* is
   6.7 tonnes a year, more than the mass of food a person eats.
3. **The gram reading reconciles the two tables in all eight demographic groups.** Converted to
   grams, the Table 3 threshold lands between P40 and P50 of Table 4f every time, across a 3.5×
   spread of values — where the total-land and pasture-land thresholds also sit. Unconverted it
   falls below P10, a position only greenhouse gases occupy and which the paper documents for
   greenhouse gases alone.

   | group | Table 3 ×1000 (g) | lands at |
   |---|---:|:---:|
   | Male 0–1.9 | 7.68 | P40–P50 |
   | Male 2–4.9 | 11.92 | P40–P50 |
   | Male 5–9.9 | 16.42 | P40–P50 |
   | Male 10+ | 26.75 | P40–P50 |
   | Female 0–1.9 | 7.44 | P40–P50 |
   | Female 2–4.9 | 11.04 | P40–P50 |
   | Female 5–9.9 | 15.07 | P40–P50 |
   | Female 10+ | 21.51 | P40–P50 |

4. **The two tables come from different sources** — Table 3 from the planetary-boundary work of
   Moberg et al. (2020) and Hallström et al. (2022), who work in kg; Tables 4a–4g from the WWF
   Planet-Based Diets Database.

**What the package does meanwhile.** Nothing in `eiod_cutoffs.dta` is rescaled — every one of
the 616 values is exactly what the paper prints. The user supplies eutrophication in grams, and
`eiod_absolute` divides by 1000 before comparing against Table 3, keeping the converted value
as `<yourvar>_kg` so the chain can be checked by eye. The adjustment is one local in one file,
so a different answer costs one line.

**The question:** can you confirm that Table 4f is printed in grams PO₄³⁻eq and Table 3 in
kilograms?

---

## 2. `#VALUE!` cells in the EIOF country databases

**Affects:** any analysis built on the country EIOF files, not this package directly.
**Status:** open.

Each of the four country databases we hold contains **537 `#VALUE!` cells in each of the seven
impact columns** — 3,759 per file, 8.4% of the 6,361-row food list:

| File | rows | `#VALUE!` cells |
|---|---:|---:|
| Burkina Faso EIOF Database 052726.csv | 6,361 | 3,759 |
| Ethiopia EIOF Database 052726.csv | 6,361 | 3,759 |
| Ghana EIOF Database 052726.csv | 6,361 | 3,759 |
| Viet Nam EIOF Database 052726.csv | 6,361 | 3,759 |

The practical consequence is that **every impact column imports as text**, not as a number. In
R, `as.numeric()` then returns `NA` with a warning that is easy to miss, and those foods drop
silently out of every impact total.

**The question:** should `#VALUE!` be read as "no impact factor available for this food", or is
it a formula error in the export that will be corrected?

---

## 3. Licence to redistribute the transcribed cut-off values

**Status:** open. **Gates** an SSC submission and a Zenodo DOI.

Both this package and `reiod` ship the 616 cut-off values transcribed from Tables 3 and 4a–4g,
so that a user can apply the metrics without re-typing them. Intake is credited as the source
in the README, in `CITATION.cff` and in `LICENSE`.

Two distinct things are involved: **the code**, which is MIT-licensed and ours, and **the
cut-off values**, which are not ours. The MIT licence explicitly does not extend to them —
see `LICENSE`.

**The question:** is there any licence condition or restriction we should observe in
redistributing these values in an open-source package, and in publishing them on GitHub and
later on the SSC archive?

---

## 4. Preferred citation form

**Status:** open.

`CITATION.cff` currently cites *Methods for Assessing Healthy, Environmentally Sustainable
Diets Globally* (Intake, 2026) as the source of the definitions and the cut-offs.

**The question:** is that sufficient, or should the EIOF database be cited separately from the
methods paper? Is there an acknowledgement wording you would prefer?

Whatever you tell us goes into both the Stata and the R package at the same time.

---

*Answers will be recorded in the issue thread and in this file. Last updated 2026-10-14.*
