# jevscope specification review v5

**NOT_READY. Two bounded corrections remain:** finish the replay publication contract (B10), and recheck live semantic exclusions before dispatch (new B12). The requested B9 definition and B11 subrole correction are closed. The remaining presentation and evidence-language issues below do not independently block readiness.

Reviewed the requested **171b4a1** and the externally landed **7c02c83**. The latter changes only `SPEC.md:877` and adds `evidence/ax-role-constants.md`, correcting 57 roles to 58. All other cited SPEC line numbers are unchanged. The canonical repository was clean before this review. No product source, specification, security policy, contributing instructions, index, or Git history was changed by this review.

**Lens:** implementability, explicit refusal coverage, and claims supported by evidence. This is specification readiness, not implementation certification. The reviewer process returned **`AXIsProcessTrusted=false`**. I claim no independent live AX verification, password-field observation, or desktop mutation. No agent loop, pixels, coordinate clicking, or GUI is required.

| Item | Status | Evidence |
|---|---|---|
| B3 | CLOSED, retained | `SPEC.md:485–560` supplies persisted arguments, an address/fingerprint, re-acquisition, expiry and atomic single-use consumption. |
| B5 | CLOSED, retained | `SPEC.md:231–255,322–327` gates the selected binding and requires a confidently safe argument. |
| B6 | CLOSED, retained | `SPEC.md:426–429,573–595` separates action/setter capabilities and requires observable confirmation. |
| B7 | CLOSED, retained | `SPEC.md:646–690` calls the cap empirical, bounds the retry ladder, and retains terminal refusal. |
| B8 | CLOSED, retained | `SPEC.md:719–730` and `SECURITY.md:56–57` reject partial snapshots or fewer than three eligible candidates. |
| B9 | **CLOSED** | `SPEC.md:804–817` defines exact correctness for both classes, including refusal-code equality. |
| B10 | **PARTIALLY CLOSED** | Role normalization and mandatory metadata are specified; action names and the replay envelope remain unresolved. |
| B11 | **CLOSED** | `SPEC.md:317–320,451–469` checks the correct secure-text subrole. |
| B12 | **OPEN** | `SPEC.md:496,549–562` does not recheck the focus-dependent refusal at apply time. |

**B11: the API correction and the hedge are right.**

The SDK selected by `xcrun --show-sdk-path` is the Xcode macOS SDK. Its headers establish:

- `AXRoleConstants.h:408` — `kAXSecureTextFieldSubrole` is `AXSecureTextField`.
- `AXAttributeConstants.h:243` — `kAXSubroleAttribute` is `AXSubrole`; line 46 is an inventory reference, not its definition.
- AppKit `NSAccessibilityConstants.h:573` — `NSAccessibilitySecureTextFieldSubrole` exists.
- `AXRoleConstants.h:425` — `kAXSearchFieldSubrole` is `AXSearchField`.

A Swift probe importing AppKit and ApplicationServices compiled and exited 0. Both `NSAccessibility.Subrole.secureTextField.rawValue` and `kAXSecureTextFieldSubrole` printed `AXSecureTextField`; trust remained false. This verifies constants and bridging without requiring live AX permission.

The composition table now explicitly refuses `setValue` when the target's subrole equals the secure-text subrole. A role of `AXTextField` no longer defeats that comparison. The fingerprint also includes subrole, so changing that reported subrole between decision and re-acquisition is a mismatch.

The reported TextEdit `AXSearchField` observation supports the narrow claim that applications expose readable subroles. It does not establish that any particular password field exposes `AXSecureTextField`. `SPEC.md:458–466` and `evidence/ax-secure-text-field.md:41–53` make that distinction correctly. The evidence Executor reported trust=true and a TextEdit observation from its different process; I did not reproduce that live observation in mine. **Specific secure-field population remains unverified.**

The focused-field refusal is an additional heuristic, not proof that every unfocused field is nonsecure. The corrected text does not claim reliable detection of all password fields. That hedge is appropriate. B12 below concerns enforcement of the rule already chosen, not a demand for a stronger password detector.

**B9: exact accuracy is implementable now.**

`SPEC.md:783–792` retains case-scoped target handles and the accepted-target rule. `:800–802` defines the same set S for the conditional target metric's numerator and denominator. `:804–817` supplies the missing exact-match policy:

- An `act` case must match operation, accepted target ID and arguments.
- A `refuse` case must finish with a refusal whose code string equals `expectRefusal`.
- `no_action` is never exact-correct on a refusal case.

One correct action plus one exact expected refusal scores **2/2**. Replacing that refusal with a different code or `no_action` scores **1/2**. No metric policy has to be invented for these cases.

The table row at `:823` still describes only the action triple. Replace its numerator with “exactly correct under the per-class rules above.” This is stale summary text, **not another B9 blocker**: the new explicit definition settles the intended behavior. Likewise, clarify whether `targetPrunedRate` deliberately measures the primary ID's absence when alternative accepted IDs remain. Its current primary-ID formula is defined; the concern is interpretation.

**B10: two parts are fixed; publication still has an actual leak path.**

The role membership rule at `SPEC.md:877` closes the custom-role leak. The selected SDK contains **58 distinct role declarations**, including `kAXTextAreaRole`, whose declaration uses a tab after `#define`. The 57 count at the requested revision was wrong; the subsequent `7c02c83` correction is confirmed. Literal set membership is the relevant rule, not an `AX` prefix. These values use mixed case; “uppercase” is imprecise prose.

`SPEC.md:889–899` now requires all seven requested metadata fields: `schemaVersion`, `transformationVersion`, `sourceClass`, `snapshotComplete`, `generation`, `id`, and `createdAt`. In particular, the missing completeness requirement is repaired. The malformed blockquote/table markers are presentation debt, not missing requirements.

However, `SPEC.md:878` still copies `elements[].actions` unchanged on the claim that it is an enumerated vocabulary. That claim is false. AppKit's `NSAccessibilityCustomAction.h:19,26–27` permits an application-supplied name. Mozilla's primary implementation record describes custom actions appearing in `AXUIElementCopyActionNames` as strings containing the custom name, target and selector. [Mozilla implementation evidence](https://bugzilla.mozilla.org/show_bug.cgi?id=1994030#c1).

A concrete publication witness is:

```json
{"actions":["AXPress","Name:PRIVATE_SENTINEL Target:0x1 Selector:doAction"]}
```

The specified unchanged transform preserves `PRIVATE_SENTINEL`. Role normalization does not touch it; the secret checker expressly does not detect arbitrary private text. This is a contract counterexample, not a claim that I observed such a live control.

**Required correction:** retain only explicitly enumerated standard action values; replace, omit or reject every other action string. Validate this at each action entry. An input containing a custom name must not publish that name. The exact placeholder spelling is secondary to the closed content boundary.

There is also a remaining envelope contradiction from v4. `SPEC.md:863–866` says every emitted field is listed and unlisted fields are bugs. The new metadata resolves completeness, but the transition list and recorded normalized result required by `:739–746,753–755,840–844` still have no permitted envelope fields. “Recorded Jev responses” at `:882` is a category, not a recursive field definition.

**Required correction:** distinguish the captured AX payload whitelist from a closed, synthetic replay envelope for transitions, responses and normalized expected results. Reject unknown captured fields recursively. This can be a short schema/reference, not an implementation project. It must be possible to serialize the required replay information without violating the publication whitelist or inventing exceptions to it.

The repository currently contains the secret checker and its tests, not a fixture-schema validator. The present-tense claim that `scripts/` already enforces the fixture contract is not implementation evidence. A validator being future work is normal at this stage and is not an additional blocker.

**B12: one documented refusal can be bypassed before dispatch.**

`SPEC.md:318,467` refuses `setValue` on a focused element. The saved fingerprint at `:496` contains role, subrole, identifier, title and description. It does not contain focus. The apply-time checks at `:549–562` recheck identity/address, generation, capability and enabled state, but omit focus.

The counterexample needs no identity substitution:

1. `decide` selects an enabled, writable, unfocused ordinary field. All model gates pass and an approval record is issued.
2. Before `apply` starts, that same field becomes focused. Its app launch, path, fingerprint and setter capability remain unchanged.
3. Every enumerated apply-time check passes. The setter can dispatch despite the focused-target exclusion.

This change occurs **before final preflight**, so it is not the irreducible interval after the last check disclosed in §6.5. Focus is readable state that the listed verification simply does not inspect. This is a logical contract witness; different static observations of focused fields would not prove a live transition.

**Required correction:** re-run the live §6.1b semantic exclusions immediately before consumption/dispatch, including the focused-target check for setters. Specify no dispatch when a required guard read fails or is malformed, distinguishing that from a legitimately unsupported optional subrole. Add a scripted unfocused→focused transition asserting refusal and an empty action log. A common live semantic check also covers the existing ancestor-menu-title exclusion, which is not part of the leaf fingerprint. The residual race after that check remains disclosed; no approval redesign is needed.

**The effect predicate is falsifiable, with a sound fallback.**

The new per-target table is not an unfalsifiable escape hatch. `SPEC.md:573–595` requires a specified observable change, an operator-authored versioned predicate, and `unknownOutcome` when no predicate exists or confirmation fails. It never authorizes a retry. A registered `{attribute, from, to}` transition can be checked against observations and disproved by them. It does not establish universal application support or exclusive causation by this process.

A concise implementation clarification would bind each entry to its application/target, compare typed pre-state with `from` and post-state with `to`, require different values for a change predicate, and record the table version used. An empty table is a valid conservative starting point. No additional generic press predicate is required.

Update the abbreviated outcome-table row at `:570`: `unknownOutcome` also covers an AX call returning success without confirmation. The subsequent prose already requires that behavior.

The older evidence file has not caught up. `evidence/ax-effect-predicate.md:23–26` still infers that no reliable predicate exists from unreadable `AXValue`. That inference is unsupported. Its radio observations also do not demonstrate checkbox mutations or successful pre/post confirmation. Correct the evidence language; these are non-blocking claims corrections because the normative spec now provides the conservative fallback.

**Whole-document consistency and measured claims.**

These remaining items are non-blocking documentation debt:

- `SECURITY.md:14–15` says deleting `.env` revokes the API key. It deletes a local copy; remote credential revocation is separate.
- `SECURITY.md:19–23` says everything sent is AX screen content. `SPEC.md:198,237–243,259–264` also sends the operator's goal and extracted arguments. `argSafe` gates dispatch after the argument has reached the API; it is not a pre-egress filter.
- `SECURITY.md:77` says SHA256 comparison. `SPEC.md:944–945` and `scripts/check-secrets.py:130–155` correctly describe literal byte matching.
- `SECURITY.md:30–38` and `CONTRIBUTING.md:28–34` retain the old corpus layout and omit private approval records. Align them with replay/synthetic separation and stored approval arguments/fingerprints. `SPEC.md:926–927` should qualify “only artifact” as a published-artifact claim, since raw captures and approval records also contain element text.
- SPEC's v2 header, nonexistent “§5.2 rule 9,” “Noul only for applied” despite `argSafe`, near-tie/no-tolerance wording, and 18-test count are stale. `kAXErrorCannotComplete` in the risks table is C-header terminology; Swift uses `.cannotComplete`. Token issuance by `decide` and authorization through `apply --approve` should be described consistently.
- Frame jitter does not preserve geometric order in general; define “order preserved” as the frozen array/handle order. Placeholder numbering should retain that frozen order rather than cause reranking.
- `evidence/ax-walk-latency.md:2,20–22` turns five observations into a bound and estimates one Jev round trip despite two phases. Those measurements do not establish an expiry guarantee. `evidence/token-budget-bound.md` also retains stronger bound language than the empirical policy in SPEC. Terminal budget refusal remains sound.
- Synthetic cases are the only source of accuracy metrics (`SPEC.md:854–855`). They do not by themselves measure natural captured-desktop grounding accuracy. Keep the research claims in §1 and §14 within that measurement scope.

I independently parsed the 15 paired rows in `evidence/risk-gate-calibration.md`: the stated conjunction admits 15/15 benign samples and refuses 15/15 destructive samples. This verifies the arithmetic, not calibration of the new binding-specific prompt. No fresh inference or latency experiment was performed.

Canonical TypeSafe documentation confirms text-only input, the independent-question model and typed answer shapes. [System One](https://docs.typesafe.ai/concepts/system-one), [Primitives](https://docs.typesafe.ai/primitives), [HTTP API](https://docs.typesafe.ai/api). The documented Choice limit is 255 options, supporting K≤254 with `none`. [Choice](https://docs.typesafe.ai/primitives/choice). The SDK page lists Python and JavaScript/TypeScript; SPEC's claim that this page was not enumerated is stale. [Client SDKs](https://docs.typesafe.ai/sdk).

The model page distinguishes versioned IDs from the alias listing and documents separate total-request and state-plus-longest-question budgets. The observed approximately 32.8k edge is not a universal total-request ceiling. [Models](https://docs.typesafe.ai/models). These documentation checks used only `docs.typesafe.ai` for TypeSafe claims.

**Verification and evidence record.**

| Command/check | Reviewer-observed result |
|---|---|
| `python3 scripts/test_check_secrets.py` | Exit 0; **27/27** assertions. |
| `python3 scripts/check-secrets.py` in canonical repo | Exit 0; **37 indexed files**, zero reported credential material. |
| `git diff --quiet 171b4a1 -- scripts/check-secrets.py scripts/test_check_secrets.py SECURITY.md CONTRIBUTING.md` | Exit 0; these files unchanged from requested baseline. |
| Swift constant/trust probes | Exit 0; both secure-subrole values match; **trust=false**. |
| Exact diff from `171b4a1` to `7c02c83` | Role-count correction and its evidence file only. |

There is no production actuator, evaluator or transformer here to verify end to end; their absence is not a spec-readiness objection. The assertions above distinguish requirements, source inspection, recorded observations and direct measurements.

This review used a bounded evidence lane through the [takeoff skill](/Users/feral/.codex/skills/takeoff/SKILL.md), with handoff verification under [radar](/Users/feral/.codex/skills/radar/SKILL.md). The Creator checked the actual files and reran the relied-upon checker commands. An Executor action-count claim was rejected after header inspection; it is not repeated as evidence. The final judgment is this Creator evidence record. Task, findings and handoff records are under `.atc/spec-review-v5/` in the review worktree, with Executor evidence under that directory in the canonical repo.
