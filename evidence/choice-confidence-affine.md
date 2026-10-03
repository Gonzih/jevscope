# Choice confidence is affine in p_max — verified 2026-10-02

SPEC §4.4 warns that `confidence` is an **affine normalization** of `p_max`, not
`p_max` itself, so a probability threshold is not interchangeable with a
confidence threshold. Codex was asked to check this specifically.

## Verification

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

**max error 0.0150, mean 0.0068** across 18 samples — consistent with the
two-decimal rounding of published probabilities. **CONFIRMED.**

The spec's concrete example holds exactly: **n = 3, p_max = 0.80 → confidence
0.70**, not 0.80.

## Why this matters operationally

The affine map depends on `n`, so a fixed confidence threshold means a
different probability threshold at every option count:

| n | confidence ≥ 0.85 ⟺ p_max ≥ | n | confidence ≥ 0.85 ⟺ p_max ≥ |
|---|---|---|---|
| 2 | 0.85 | 5 | 0.7125 |
| 3 | 0.900 | 255 | 0.3367 |

Inverting: `p_max = confidence · (1 − 1/n) + 1/n`.

Consequences for the spec:
1. jevscope gates on `confidence` and **never** substitutes a `p_max` value
   for a confidence threshold.
2. A fixed confidence threshold is **not** a fixed probability bar — with 24
   candidates, confidence 0.85 admits `p_max` ≥ 0.3975, far weaker than the
   0.85 a two-option question would demand.
3. The corpus (§9) must record **both** the confidence and the full
   probability vector, because the two are not interchangeable and only the
   vector is comparable across different candidate counts.
