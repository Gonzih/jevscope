# jevscope specification review v6

**READY. B10 and B12 are closed at the specification level.** The remaining findings below are explanatory or evidentiary corrections, not a dispatch bypass or a captured-content publication path.

Reviewed `287d22ecb13b7368bfe479a0081fbcb588e9fbff` against the committed v5 review and the actual diff. The review checkout and `/Users/feral/mydev/jevscope` contain identical SPEC bytes at that commit. This report is written only in `/private/tmp/worktrees/prompt-1790990298830-6954-0/`; no shared-repository files were edited.

Lens: implementability, enforcement ordering, and the boundary between observations and claims. This is specification readiness, not implementation certification. A direct Swift trust probe in this reviewer process returned **`AXIsProcessTrusted=false`**. No live AX behavior or desktop mutation was verified.

| Item | Status | Contract evidence |
|---|---|---|
| B3/B5/B6/B7/B8/B9/B11 | CLOSED, retained | No relevant regression in the v6 diff. |
| B10 actions | CLOSED | `SPEC.md:895` admits declared standard action values only; custom entries become placeholders. |
| B10 envelope | CLOSED | `SPEC.md:907–935` supplies required metadata and a closed synthetic envelope; response values are constrained by §5. |
| B12 | CLOSED | `SPEC.md:530,562–573` places live semantic validation before successful token consumption and dispatch; required-read failures refuse. |

**B12: the previously missing guard is on the dispatch path.**

`SPEC.md:551–561` first requires re-acquisition, generation, capability and an explicitly enabled element. `:562–565` then requires the live §6.1b predicate immediately before consumption and dispatch, explicitly including the setter's secure-subrole and focused-state tests. The reference to the whole §6.1b predicate also retains its label and ancestor-menu exclusions (`:435–450`); the setter example does not replace them.

The successful transition at `:530` requires **all preconditions** to pass. Atomic consumption at `:535–538` therefore cannot authorize an earlier dispatch that skips the new check. The v5 witness—same target and fingerprint, focus changes before apply—now fails the live predicate and dispatches nothing.

There is one necessary distinction in the requested token-order check: `:531` explicitly spends the token when **any** precondition fails. Such a terminal refusal may consume it before later checks are reached. Thus “no earlier step can ever consume the token” is not literally true, but “no successful dispatch can consume it before the live predicate passes” is true. Early spending on refusal neither authorizes an action nor bypasses B12; it preserves the documented one-attempt lifecycle.

`SPEC.md:569–573` prohibits treating failed, missing or malformed required reads as unchanged state. `:750` includes `preflightReadFailed` in refusal precedence. `:756–763` requires both the focus-change case and the read-error case, with empty action logs. These are required tests, not tests already executed in this repository. The residual interval after final preflight remains disclosed at `:610–619`.

**B10: membership and the publication boundary are now concrete.**

The selected SDK's `AXActionConstants.h:40` declares `kAXPressAction` with value `AXPress`; `:59` only mentions `kAXAcceptAction` in a comment. The rule is membership in the **declared string values**, not a prefix match, occurrence of an identifier in header text, or a numeric count.

Applying that contract to the prior witness gives:

```text
AXPress                                         -> AXPress
Name:PRIVATE_SENTINEL Target:0x1 Selector:doAction -> <ACTION_NN>
AXAccept                                        -> <ACTION_NN>
```

No custom action text survives. I independently checked the actual declarations and this membership example; this is a contract probe, not a test of a production sanitizer.

The totality claim is now supportable **as a publication contract**. Read `SPEC.md:880–883` together with the explicit extension at `:919–935`: the permitted union is the captured-payload fields, mandatory metadata, and the closed envelope. Unknown fields are invalid. The old responses are discarded (`:900`); `recordedResponses[]` retains the §5 typed fields after transformation (`:926`). §5 supplies the permitted operation/target choices, probability-map keys and numeric validation (`:225–229,270–295`), so the map is not an arbitrary captured-string escape. Normalized expectations use an argument digest (`:927`), and deliberately authored human notes are expressly distinct from copied captured content (`:928,934–935`).

Counts-only `transitions[]` are summaries; they do not encode arbitrary AX mutations or prove a backend test ran. That limitation does not require a new publication field: §8.4's required scenarios can be implemented in the scripted test backend using synthetic data. The spec separates published real-capture replay fixtures from hand-authored synthetic cases (`:871–872`). Requiring a general serialized AX scripting language would expand the requested correction. Clarifying the word “sequence” at `:925` would improve presentation; it is not a surviving B10 privacy defect.

The canonical [TypeSafe HTTP API reference](https://docs.typesafe.ai/api) supports the typed answer structure used here. The published fixture is a projection of those answers, not a promise to retain the entire HTTP response. Only `docs.typesafe.ai` was used for this external check.

**The two requested consistency fixes landed.** `SPEC.md:840` defers `exactAccuracy` to the per-class rules at `:821–834`. `:407–408` names both `applied` and `argSafe` as Noul uses and keeps risk as Score.

**The effect-evidence correction is right, with residual overstatement.**

`evidence/ax-effect-predicate.md:23–30` correctly retracts the inference that unreadable `AXValue` proves no confirmation predicate exists. The samples show that an AXValue-only rule cannot cover every sampled menu button; they do not exclude another readable attribute or an operator-registered predicate. The normative fallback at `SPEC.md:599–606` is sound: use a specified predicate, otherwise report `unknownOutcome`.

Two qualifications remain non-blocking:

- `evidence/ax-effect-predicate.md:19–22` still calls press confirmation on radios **and checkboxes** established. The table at `:5–16` contains static radio observations, no checkbox row, and no pre/post press experiment. It supports comparable radio state, not demonstrated checkbox support or demonstrated action confirmation.
- “A generic AXValue predicate is unavailable for that role” at `:26–27` should be understood as unavailable **across the sampled menu buttons**, not proof that every AXMenuButton implementation lacks a usable value. Comparing different roles in different apps also does not isolate application variation. No stronger negative claim is needed.

One fresh explanatory error is also non-blocking: `SPEC.md:566–567` says focus **and subrole** are outside the fingerprint. `:497` explicitly includes subrole. Focus is the missing fingerprint component; the extra live subrole check remains valid. This false rationale does not weaken the normative guard.

The present-tense claims that `scripts/` already validates fixture shape (`:882,908`) remain implementation aspirations: tracked scripts contain the secret checker and its tests, with no production transformer, actuator or fixture validator. Their absence is normal at this specification stage. No end-to-end sanitizer, replay or dispatch test is claimed.

**Verification record:** `git rev-parse HEAD` → `287d22e…`; `git diff 7c02c83 287d22e` inspected; byte comparison of both SPEC copies against `git show 287d22e:SPEC.md` → equal; selected-SDK declaration/membership probe → exit 0; Swift trust probe → exit 0, false. Product files remain unchanged. The review did not rerun unrelated secret-checker tests or issue fresh Jev inference requests.

The read-only AX evidence lane was assigned through the [takeoff skill](/Users/feral/.codex/skills/takeoff/SKILL.md); addressed replies are handled under [radar](/Users/feral/.codex/skills/radar/SKILL.md). The Creator independently inspected the cited spec, evidence file and SDK declarations. The task and evidence ledger are `.atc/spec-review-v6/task.md` in this worktree.
