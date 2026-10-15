# `eiod_fn_01_demogroup.do` — the 8 age × sex groups

**Defines** `eiod_demogroup`
**Source** Intake-EIOD-Methods-Paper-Jan2026-Final.pdf — the column headings of Tables 3, 4a–4g and 5a–5b
**Reads** nothing. No cut-off file needed.
**Verified by** `eiod_validate.do` Part F (boundary ages)

Every other `eiod_*` command needs this variable. Build it first.

---

## 1. The original grouping

Every published table has the same eight columns:

| Group | Sex | Age (years) |
|---:|---|---|
| 1 | Male | 0 to < 2 |
| 2 | Male | 2 to < 5 |
| 3 | Male | 5 to < 10 |
| 4 | Male | 10 and over |
| 5 | Female | 0 to < 2 |
| 6 | Female | 2 to < 5 |
| 7 | Female | 5 to < 10 |
| 8 | Female | 10 and over |

Tables 5a and 5b print only **six** columns — groups 1 and 5 are absent, because the GDQS has not been validated below age 2.

## 2. The intervals are half-open, and it matters

```stata
qui replace `generate' = 1 if `sex' == `malecode' & `ageyr' <   2
qui replace `generate' = 2 if `sex' == `malecode' & `ageyr' >=  2 & `ageyr' <  5
qui replace `generate' = 3 if `sex' == `malecode' & `ageyr' >=  5 & `ageyr' < 10
qui replace `generate' = 4 if `sex' == `malecode' & `ageyr' >= 10 & !mi(`ageyr')
```
…and 5–8 identically for females.

Each band is **closed below, open above**: `[0,2)`, `[2,5)`, `[5,10)`, `[10,∞)`. A child aged exactly 2.0 is in group 2, not group 1. A child of 1.99 is in group 1.

**The `!mi()` on the open-ended band is load-bearing.** Missing sorts above every real number in Stata, so an unguarded `age >= 10` would put every respondent with **no recorded age** into group 4 or 8. The guard leaves them missing.

## 3. Age in years, not months

`age()` must be in **years**, and may be fractional (2.5 = two and a half). If your data holds age in months, divide by 12 first — `eiod_demogroup` cannot detect the difference, and a sample recorded in months would place everyone over 10 months into the adult group.

## 4. The sex coding is yours to declare

```stata
eiod_demogroup, age(age_yr) sex(sex_c) generate(dgroup)              // 1=M, 2=F
eiod_demogroup, age(age_yr) sex(sex_c) generate(dgroup) malecode(0) femalecode(1)
```

Defaults are `malecode(1) femalecode(2)`. Any value that is neither is left **missing**, and the count is reported — so a third category or a "don't know" code does not get silently absorbed into one of the two.

## 5. Syntax

```stata
eiod_demogroup , Age(varname) Sex(varname) GENerate(name)
    [ MALEcode(#) FEMALEcode(#) replace ]
```

**Output** `byte` 1–8, value-labelled with the group descriptions above.
**Returns** `r(N)`, `r(N_miss)`.

## 6. What to check after running it

```stata
tab dgroup, m
```

Two things are worth a look every time: the number left missing (bad age or an unexpected sex code), and whether groups 1 and 5 are populated — if they are, the composite metrics in Tables 5a/5b will be missing for those respondents **by design**, and that changes every denominator. Decide explicitly whether under-2s belong in the analysis sample.

*Last updated 2026-10-05.*
