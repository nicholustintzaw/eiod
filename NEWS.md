# eiod 0.1.0

First public release. 2026-10-14.

Nine commands implementing Tables 3, 4a–4g, 5a and 5b of the Intake Environmental Impacts of
Diets methods paper (January 2026), as Stata do-files.

* `eiod_demogroup` builds the eight age × sex groups every cut-off is scaled by.
* `eiod_absolute` (Table 3) and `eiod_relative` (Tables 4a–4g) for all seven indicators, with
  `threshvar()` and `cutvar()` to return the cut-off each respondent was judged against.
* `eiod_hesd` (Table 5a) and `eiod_hdlei` (Table 5b), each returning the two criteria as
  separate sub-indicators as well as the combined measure.
* `eiod_absolute_all` and `eiod_relative_all` apply a metric across several indicators in one
  call, with one option per indicator holding **your** variable name. Supply any subset.
* `eiod_check_impact` and an automatic pre-check inside the metric commands catch the storage
  and scale faults that destroy impact data silently.
* 616 cut-offs ship as `functions/dta/eiod_cutoffs.dta`, built from the same CSV the companion
  R package `reiod` reads, so the two cannot drift at the data layer.

## Known limitations

* **Incomplete EIOF coverage is an upstream responsibility.** Not every food has an impact
  factor; a food without one contributes nothing to the day total, so the total is understated.
  These commands receive one number per respondent-day and cannot detect it - the aggregation
  discarded the evidence. Count the share of consumed weight carrying a factor when you
  aggregate, and report it with any prevalence. See README section 5b and
  `functions/readme/06_eiod_infrastructure.md`.

* **The eutrophication unit reading is an inference.** The paper states no unit for Tables
  4a–4g; the package reads Table 4f as grams and Table 3 as kilograms. See
  `functions/readme/01_eiod_build_cutoffs.md` §2 for the evidence. The question is with Intake.
* **No automated test run in CI.** Stata is licensed software and GitHub's runners do not have
  it, so `validate/eiod_validate.do` is run locally and its result recorded. The CI workflow
  checks structure only — see `.github/workflows/checks.yml`.
* **`.do` files, not `.ado`.** Load them with `eiod_load_functions.do` before your analysis.
  A conversion to `.ado` with `.sthlp` help files is planned; see the package plan.
