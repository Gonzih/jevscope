# jevscope

**Jev-driven macOS desktop control, in Swift.**

Jev is [TypeSafe's System One model](https://docs.typesafe.ai/concepts/system-one).
It takes text in and returns typed, bounded answers — `choice`, `noul`, `score`
— with calibrated probabilities. It does not write text, and it cannot see.

That last constraint shapes everything here. **Jev accepts text only, so pixels
never leave your machine.** The entire perception layer is the macOS
Accessibility (AX) tree, serialized to text; the model's bounded answer maps to
a deterministic AX action.

```
   AX tree  ──►  element table  ──►  Jev (text only)  ──►  bounded decision
   (real UI)     ranked, capped      two phases          gated, fail-closed
```

## Status

This is **early**. `doctor`, `tree` and `decide` work against real
Accessibility trees and the live API. `apply` is deliberately **not implemented
yet**: there is no code path in this repository that can change anything on your
machine. See [What this will not do](#what-this-will-not-do).

```bash
git clone https://github.com/Gonzih/jevscope && cd jevscope
cp .env.example .env      # add TYPESAFE_API_KEY
swift build && swift test

.build/debug/jevscope doctor
.build/debug/jevscope tree --app com.apple.Safari --goal "search"
.build/debug/jevscope decide --app com.apple.finder --goal "switch to list view"
```

## Why it is built this way

Three findings drove the design. All are measured, not assumed.

**1. The confidence fields mean what the docs say — once you measure them.**
Choice confidence is `(p_max − 1/n)/(1−1/n)`; Score uses the modal level. An
early version of this spec reported the Score formula as broken. It wasn't — my
analysis fed it the mean instead of the mode. Over 24 live samples the correct
formula reproduces to **max error 0.020**. `Noul` is the exception: it returns
**no** confidence field at all, so it needs its own two-sided gate.

**2. A symmetric confidence gate is not safe.**
Measured on 15 benign and 15 destructive goals: a Noul risk gate refuses
`force quit the app` at 0.16 while admitting `toggle dark mode` at 0.18 — the
overlap sits in the unsafe direction. Risk is therefore gated by a **Score**
with a permissive-only rule (`score ≤ 0.20` **and** `confidence ≥ 0.85`), which
passes 15/15 benign and refuses 15/15 destructive.

**3. The Accessibility API cannot close the check-to-use race.**
An `AXUIElement` is a `CFTypeRef` owned by the process that created it. It
cannot be persisted or reopened, and there is no transaction combining snapshot
verification with the target's action. Same-role substitution, virtualized row
reuse, and selection changes under an unchanged control are **not detectable**.

So v1 ships no generic execution. When `apply` exists it will be a narrow
allowlist behind a single-use approval record, and the residual race will be
disclosed rather than papered over. `SPEC.md` §6.5 is explicit about this.

## What this will not do

- **No submit, send, or delete.** The risk gate refuses all 15 destructive goals
  measured. Excluding them is evidence-driven, not an oversight.
- **No screenshots, no OCR, no coordinate clicking.** Pixels never leave the
  machine, because Jev never sees them.
- **No unattended operation.** v1 requires an explicit operator approval.
- **No password fields.** macOS has no AX classification that reliably
  distinguishes a secure field from an ordinary one, so `setValue` treats
  uncertainty as refusal.

## Honesty about the premise

**The concept is not novel.** At least six projects already drive macOS from
Jev — most closely [`savka777/jev-use`](https://github.com/savka777/jev-use),
a Swift MIT app doing almost exactly this. This repository does not claim to be
first.

What it does claim is narrower: an **open spec**, a **reproducible evaluation
harness**, **verified confidence semantics**, and an honest account of what the
AX API cannot promise. Every number in `SPEC.md` and `evidence/` was measured
on a real machine; where something is claimed but unverified, it says so.

## Evidence

`evidence/` holds the measurements, not the conclusions:

| File | What it shows |
|---|---|
| `score-confidence-findings.md` | 24 live samples; the mode-vs-mean correction |
| `noul-polarity.md` | 6 live cases; polarity is 1.0 = yes |
| `risk-gate-calibration.md` | 15 benign vs 15 destructive |
| `token-budget-bound.md` | the byte policy, and that it is empirical, not proved |
| `ax-secure-text-field.md` | secure fields are a **subrole**, not a role |
| `ax-role-constants.md` | 58 roles, 37 subroles, counted from the SDK |
| `ax-walk-latency.md` | walk cost varies ~100× between apps |
| `ax-quality-macos27.txt` | real AX tree coverage |

## Security

Read [SECURITY.md](SECURITY.md) before running this. Two authorities are
separate and must be revoked independently: the TypeSafe API key, and macOS
Accessibility permission. Screen content — window titles, control labels, text
field values — is sent to a third-party API.

```bash
python3 scripts/check-secrets.py        # 27 adversarial assertions
python3 scripts/test_check_secrets.py
```

## Licence

MIT. No code was copied from any prior project.