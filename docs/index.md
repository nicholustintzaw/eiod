# eiod

**Intake dietary environmental impact metrics, as Stata commands.**

Tables 3, 4a–4g, 5a and 5b of
[*Methods for Assessing Healthy, Environmentally Sustainable Diets Globally*](https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf)
(Intake, 2026), implemented as plain do-files.

[Repository on GitHub](https://github.com/nicholustintzaw/eiod) ·
[R companion: reiod](https://github.com/nicholustintzaw/reiod)

---

## If you are reviewing this

Start here.

| | |
|---|---|
| **[The reference dataset](01_eiod_build_cutoffs.html)** | all 616 cut-offs: how they were transcribed, how exact they are, and **the eutrophication unit question** — the one open point that affects the numbers |
| `eiod_cutoffs_wide_check.csv` | in the repository under `functions/dta/` — the cut-offs laid out group-by-group for direct comparison against the printed tables. **The most reviewable artefact here** |
| [Issues](https://github.com/nicholustintzaw/eiod/issues) | where open points are raised and answered. There is a template for a methods or cut-off query |

---

## If you are using it

| | |
|---|---|
| **[README](readme.html)** | installation, the nine commands, worked examples, where files live |
| **[Changelog](news.html)** | what changed, and whether it affects your results |

### The documentation, in reading order

| | |
|---|---|
| [01 — the reference dataset](01_eiod_build_cutoffs.html) | the 616 cut-offs, the precision guarantees, and the two-unit eutrophication question |
| [02 — `eiod_demogroup`](02_eiod_demogroup.html) | the eight age × sex groups every cut-off is scaled by |
| [03 — `eiod_absolute`](03_eiod_absolute.html) | Table 3, and the one unit conversion in the package |
| [04 — `eiod_relative`](04_eiod_relative.html) | Tables 4a–4g, **the band rule step by step** — the one to read if you read only one |
| [05 — the composites](05_eiod_composites.html) | Tables 5a and 5b, the sub-indicators, and why HDLEI is nested inside HESD |
| [06 — infrastructure](06_eiod_infrastructure.html) | path resolution, the loader, the batch wrappers, the input QC |

Each page gives the original table it implements and a line-by-line account of what the code
does, so the calculation can be checked without reading Stata.

---

## Three things to know before reporting any result

1. **HESD and HDLEI are nested, not independent.** The HDLEI environmental cut-off is uniformly
   1.52× stricter, so every HDLEI diet is also a HESD diet. One cell of the 2×2 is structurally
   empty.
2. **A low relative band is not evidence of sustainability.** For greenhouse gases even band 1
   exceeds the planetary boundary; for water even band 10 sits below it. The two metric
   families answer different questions.
3. **Eutrophication is printed in two different units** — kg in Table 3, grams in Table 4f.
   Supply your data in grams, as the EIOF database gives it to you. **This reading is an
   inference and has not been confirmed by Intake** — see
   [the reference dataset](01_eiod_build_cutoffs.html), section 2.

---

## What this is not

**It does not contain the EIOF database.** It ships the published metric *cut-offs* and applies
them to impact values you have already derived. Matching food items to impact factors, applying
the edible-portion, processing and cooking-yield adjustments, and summing to the respondent-day
is upstream work this package starts after.

It also does not calculate the Global Diet Quality Score — the composite metrics take a GDQS
value as an input.

---

## Acknowledgements

The metric definitions and all 616 cut-off values are **Intake's**, from
[*Methods for Assessing Healthy, Environmentally Sustainable Diets Globally*](https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf)
(Intake — Center for Dietary Assessment, 2026). This package implements them; it did not derive them.

The code, documentation and verification suite were written with the assistance of **Claude
(Anthropic)**, used as a coding and writing assistant throughout development. All
methodological decisions, the reading of the methods paper, the verification of every result,
and responsibility for the contents are the author's.

---

*MIT licensed code. The cut-off values are Intake's; see the repository `LICENSE`.*
