# `eiod_fn_04_hesd.do` and `eiod_fn_05_hdlei.do` — Tables 5a and 5b

**Defines** `eiod_hesd` (Table 5a), `eiod_hdlei` (Table 5b)
**Source** [Intake-EIOD-Methods-Paper-Jan2026-Final.pdf](https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf), Tables 5a–5b (p. 20); method p. 4; Annex 1 Part II (p. 17)
**Verified by** `eiod_validate.do` Parts B, G, H, J

Documented together because they are the same construction with one criterion swapped — and because **they are nested, not independent**. See §5; it changes how they may be reported.

---

## 1. The two original tables

Both cross a **diet-quality** criterion with an **environmental** criterion into four categories:

| Category | Table 5a (HESD) | Table 5b (HDLEI) |
|---:|---|---|
| 1 | Healthy **and** environmentally sustainable | Healthy **and** low environmental impact |
| 2 | Not healthy but environmentally sustainable | Not healthy but low impact |
| 3 | Healthy but not environmentally sustainable | Healthy but not low impact |
| 4 | Neither | Neither |

Category numbering follows the **printed row order** of the tables.

Both print **six** demographic columns, not eight: the paper restricts the composites to ages 2 and over, because the GDQS has not been adapted or validated below age 2.

## 2. The criteria

| | Diet quality | Environment |
|---|---|---|
| **HESD** (5a) | GDQS ≥ 23 | biodiversity loss **< the Table 3 absolute threshold** |
| **HDLEI** (5b) | GDQS ≥ 23 | biodiversity loss **below P30 of the Table 4g distribution** |

The diet-quality criterion is **identical** in both. Only the environmental criterion differs: HESD asks "is this within the planetary boundary share?", HDLEI asks "is this in the lowest-impact 30% of the global reference distribution?".

Biodiversity loss is the paper's proxy for total environmental impact (p. 4). The GDQS cut-off of 23 is its "healthy diet" criterion.

## 3. The decomposed sub-indicators

Each command writes **four** variables, not one. With the default prefix:

| Variable | Type | What it is |
|---|---|---|
| `hesd_healthy` | 0/1 | the GDQS criterion alone — **sub-indicator** |
| `hesd_envsust` | 0/1 | the biodiversity criterion alone — **sub-indicator** |
| `hesd_cat` | 1–4 | the four categories |
| `hesd` | 0/1 | dichotomous: category 1 against everything else |

and for HDLEI: `hdlei_healthy`, `hdlei_lowimpact`, `hdlei_cat`, `hdlei`.

The sub-indicators exist so that a disappointing composite can be attributed. A low HESD driven by `hesd_healthy` is a diet-quality story; one driven by `hesd_envsust` is an environmental story; they call for different responses.

## 4. No duplicated logic — the environmental criterion is delegated

```stata
* in eiod_hesd
eiod_absolute biodiv, value(`biodiversity') group(`group') ///
    generate(`envall') cutoffs(`cutoffs')

* in eiod_hdlei
eiod_relative biodiv, value(`biodiversity') group(`group') ///
    generate(`bandall') below(`percentile') belowvar(`lowall') cutoffs(`cutoffs')
```

Neither composite re-implements its threshold. Each **calls** the standalone command, so `hesd_envsust` is identical by construction to the Table 3 biodiversity metric, and `hdlei_lowimpact` to the Table 4g `below(30)` flag. There is no second copy that could drift. `eiod_validate.do` Part H asserts the equality.

## 5. The two composites are NESTED — do not present them as a 2×2

This is the most important thing on this page.

The HDLEI environmental cut-off is **uniformly 1.52× stricter** than the HESD one, in every demographic group. Proved algebraically and asserted in `eiod_validate.do` Part J. Therefore:

$$\texttt{hdlei} = 1 \implies \texttt{hesd} = 1$$

always. They are not two independent dimensions of sustainability; HDLEI is a tighter version of HESD. A 2×2 of the two will have a structurally empty cell, and reporting them as separate findings double-counts the same respondents.

## 6. The age restriction changes every denominator

```stata
tempvar elig
qui gen byte `elig' = inlist(`group', 2, 3, 4, 6, 7, 8)
```

All four output variables are left **missing** for groups 1 and 5 (under-2s), and the number affected is reported. If your sample contains under-2s, decide explicitly whether they belong in the analysis sample — leaving them in makes every composite prevalence a proportion of a different denominator than the other tables.

## 7. Syntax

```stata
eiod_hesd  , BIODiversity(varname) GDQS(varname) Group(varname)
    [ PREfix(name) GDQScut(#) CUToffs(string) replace ]

eiod_hdlei , BIODiversity(varname) GDQS(varname) Group(varname)
    [ PREfix(name) GDQScut(#) PERCentile(#) CUToffs(string) replace ]
```

`gdqscut()` defaults to 23 and `percentile()` to 30. Change either only with a documented reason — they are the published criteria, and moving them makes the result incomparable with other EIOD work.

## 8. Related

- `eiod_fn_02_absolute.do`, `eiod_fn_03_relative.do` — the commands these delegate to
- `eiod_validate.do` Part B — shows the Table 5 cut-offs tracing back to Tables 3 and 4g

*Last updated 2026-10-05.*
