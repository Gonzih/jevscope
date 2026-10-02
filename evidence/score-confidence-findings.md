# Confidence semantics — corrected, verified 2026-10-02

Measured live against `POST https://api.typesafe.ai/v1/systemone`, model
`jev-latest` (resolved `jev-1.13.0`). Raw samples: `score-confidence-samples.json`
(24 states, one 3-level `score` question).

## Correction to an earlier claim

An earlier revision of this file reported that the documented Score confidence
formula "does not reproduce". **That was an error in the analysis, not in the
API.** The formula's `m` term is the **most likely level (mode = argmax of the
probabilities)**, not the returned mean `score`. Substituting the mean produced
a spurious max error of 0.287.

| `m` used | max err | mean err | verdict |
|---|---|---|---|
| returned mean `score` | 0.2867 | 0.1063 | **wrong input** |
| `argmax(p)` (correct) | **0.0200** | **0.0083** | **confirmed** |

Residual error is consistent with two-decimal rounding of the published
probabilities. The discrepancy was found by the Codex spec review.

## Verified formulas

All three primitives are now backed by live samples, not doc-reading alone.

| Primitive | Confidence | Status |
|---|---|---|
| **Choice** | `(p_max − 1/n) / (1 − 1/n)` | **confirmed**, max err 0.005 over 8 samples |
| **Score** | `max(0, 1 − Σ p_i·\|i − argmax(p)\| / MAD_unif)`, `MAD_unif = (1/n)Σ\|i − (n−1)/2\|` | **confirmed**, max err 0.020 over 24 samples |
| **Noul** | `\|2p − 1\|`, **derived client-side — not returned** | field is absent from every live response |

Per-sample, with the corrected `m` (server vs formula):

```
server=0.97 formula=0.955   server=0.09 formula=0.085   server=0.18 formula=0.190
server=0.11 formula=0.130   server=0.13 formula=0.130   server=0.36 formula=0.370
server=0.16 formula=0.160   server=0.00 formula=0.010   server=0.34 formula=0.340
server=0.59 formula=0.595   server=0.00 formula=0.000   server=0.29 formula=0.295
server=0.82 formula=0.835   server=0.96 formula=0.940   server=0.90 formula=0.895
```

## Polarity — verified live

High `noul` = **YES** (0 = no, 1 = yes), matching the docs. 6/6 cases correct,
including the negative-polarity probe ("send my password…" / "Is this action
safe?" → 0.02). See `noul-polarity.md`.

## Decision for jevscope

Gate on the server's `confidence` for **Choice** and **Score** — both are
verified reproducible and safe to trust.

For **Noul** there is no confidence field to gate on, so jevscope applies its
own explicit two-sided thresholds, and the whole probability is recorded in the
trace. Because `noul` is a probability rather than a confidence, the gate is:

- `noul ≥ hiThreshold` ⇒ **yes** branch
- `noul ≤ loThreshold` ⇒ **no** branch
- otherwise ⇒ **refuse** (`ambiguousNoul`)

Thresholds are per-question, configurable, and recorded. Defaults: `lo = 0.20`,
`hi = 0.80`; destructive questions raise `hi` to 0.95 per the canonical
worked example.