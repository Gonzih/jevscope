# Choice confidence is an affine normalization of p_max — verified & corrected

SPEC §5.4 warns that `confidence` and `p_max` are **not interchangeable**
numbers. Codex was asked to check this specifically.

## Verification of the forward map

Choice questions with 2, 3, and 5 options, six states each (18 samples):

| n | p_max | confidence | (p_max − 1/n)/(1 − 1/n) | err |
|---|---|---|---|---|
| 2 | 0.91 | 0.820 | 0.820 | 0.000 |
| 2 | 0.80 | 0.590 | 0.600 | 0.010 |
| 2 | 0.75 | 0.490 | 0.500 | 0.010 |
| 3 | 0.86 | 0.780 | 0.790 | 0.010 |
| 3 | 0.79 | 0.690 | 0.685 | 0.005 |
| 3 | 0.81 | 0.720 | 0.715 | 0.005 |
| 5 | 0.86 | 0.820 | 0.825 | 0.005 |
| 5 | 0.78 | 0.720 | 0.725 | 0.005 |
| 5 | 0.67 | 0.580 | 0.588 | 0.008 |

**max error 0.0150, mean 0.0068** — consistent with two-decimal rounding.
**CONFIRMED.** The spec's example holds exactly: **n = 3, p_max = 0.80 →
confidence 0.70**, not 0.80.

## What the map actually does

`confidence = (p_max − 1/n) / (1 − 1/n)` maps **uniform (1/n) → 0** and **1 → 1**.
It is a **normalization over the option count**, and that is its purpose.

Inverting, `p_max = confidence · (1 − 1/n) + 1/n`. At `confidence ≥ 0.85`:

| n | 2 | 3 | 5 | 12 | 24 | 100 | 255 |
|---|---|---|---|---|---|---|---|
| implied `p_max ≥` | 0.925 | 0.900 | 0.880 | 0.863 | **0.85625** | 0.852 | 0.851 |

The implied probability lies in **[0.851, 0.925]** across the entire legal
option range — essentially constant. So a fixed confidence threshold is
**already candidate-count independent**, which is exactly what a normalization
should deliver.

## Correction

An intermediate revision of SPEC §5.4 claimed that at 24 options a 0.85
confidence threshold "would admit `p_max ≈ 0.40` — a genuinely ambiguous
answer", and added a `p_max ≥ 0.80` floor on that basis. **That arithmetic was
wrong**: the correct value at n = 24 is **0.85625**, comfortably above 0.80, so
the added floor was **redundant**. Codex caught the error; the floor has been
removed rather than left in as decorative defense.

The valid part of the warning is retained: the two numbers are not equal and
must never be substituted for one another. SPEC §5.2 rule 9 therefore recomputes
`p_max` from `probabilities` rather than deriving it from `confidence`, and the
corpus records both.

## Note on Score

This normalization is a **Choice** property only. Score confidence uses the
separate MAD formula (`argmax`-based, `evidence/score-confidence-findings.md`),
and Noul returns no confidence at all.