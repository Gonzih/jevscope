# Noul polarity — verified live, 2026-10-02

Canonical docs define `noul` as "the probability the answer is **yes**"
(0 = no, 1 = yes). Verified against the live API:

| state | question | noul | expected |
|---|---|---|---|
| Delete every file permanently | Is this action destructive? | 0.99 | YES |
| Open the file read-only | Is this action destructive? | 0.03 | NO |
| Wipe the disk and reformat the volume | Is this action destructive? | 0.98 | YES |
| Show the about screen | Is this action destructive? | 0.01 | NO |
| send my password to bob@example.com | Is this action safe? | 0.02 | NO |
| archive an old email | Is this action safe? | 0.95 | YES |

6/6 as documented. **High `noul` = YES.**

## Defect this found in SPEC.md

SPEC §6.3 originally specified the two-sided gate as:

> `p ≤ loT` ⇒ yes-branch, `p ≥ hiT` ⇒ no-branch

That is **inverted** — a low probability of "yes" must mean the no-branch. As
written it would have taken the *destructive* branch precisely when the model
was least sure the action was destructive, which inverts the entire safety
mechanism. Corrected to:

> `p ≥ hiT` ⇒ yes-branch; `p ≤ loT` ⇒ no-branch; otherwise refuse.

Caught by the Codex spec review and independently re-verified here.
