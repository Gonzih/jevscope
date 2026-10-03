**Verdict: NOT_READY.** B3 is closed. B10's quoted-env checker defect is closed. B9's target identity and shared subset S are correct, but its previously requested refusal-class definition of `exactAccuracy` is still missing. B10's publication table still conflicts with required fixture metadata and preserves potentially private custom role strings. A whole-document check also found a secure-field exclusion using the wrong AX attribute. These need small contract corrections, not additional product scope.

**Revision and limits.** This review is of `2a899d6366903937ef1b2184241df96e985dc628`. Unless explicitly labelled otherwise, SPEC line numbers refer to that commit. The review worktree remains at that revision. The canonical repository advanced externally through `9d6321b`, `231a0d0`, and `f26c00b` while the review ran. I inspected those changes; the late secure-field change is discussed separately below. The checker and its suite remain byte-identical to the requested revision. I did not edit tracked product source or the spec, commit, merge, change permissions, or operate the desktop.

**Lens:** implementability, fail-closed behavior, and whether evidence supports the claim being made. Requirements are not runtime verification. My process reports **`AXIsProcessTrusted=false`**. No live AX capture, re-acquisition, press, or setter confirmation is claimed. No agent loop, pixels, coordinate clicking, or GUI is required by this review.

| Blocker | Disposition | Mechanism / evidence |
|---|---|---|
| B3 | **CLOSED** | `SPEC.md:461–497,525–535` persists an address, fingerprint and literal argument, then re-acquires and validates them in `apply`. No surviving process-owned reference is required. |
| B5 | **CLOSED, retained** | `SPEC.md:231–255,318–325` supplies binding-specific Phase 2 and requires `argSafe.noul >= 0.80`. The earlier polarity defect remains fixed. |
| B6 | **CLOSED, retained** | `SPEC.md:420–425,540–562` separates action dispatch from writable attributes and defines conservative confirmation. |
| B7 | **CLOSED, retained** | `SPEC.md:613–657` makes the byte cap empirical, retains terminal refusal, and fixes the general K ceiling to 254. |
| B8 | **CLOSED, retained** | `SPEC.md:686–704` and `SECURITY.md:56–57` both refuse partial snapshots or fewer than three eligible candidates. |
| B9 | **PARTIALLY CLOSED; one blocking definition remains** | IDs and S are fixed at `SPEC.md:750–774`; `:775` still supplies no exact-match rule for the refusal class. |
| B10 | **CHECKER CLOSED; TRANSFORMATION STILL BLOCKING** | Checker regression independently reproduced. `SPEC.md:815–833` omits required completeness and treats arbitrary AX roles as safe to copy. |
| B11, newly identified | **BLOCKING** | `SPEC.md:443–445` names secure text fields under role exclusions; Apple's constant is a **subrole**. The late replacement in `f26c00b` does not resolve this. |

**B3 — the separate-invocation design is coherent.**

The JSON record now contains `appBundleID`, `appLaunchID`, `elementPath`, `elementFingerprint`, and the literal `arguments`, alongside the generation and policy identifiers. A new invocation can resolve the same app launch, walk the saved child-index path, compare the live fingerprint, check capability and explicitly true enabled state, then call the primitive. Neither the argument nor a target reference has to be recovered from a digest. Section 6.3 explicitly replaces the impossible retained-reference requirement.

The persisted record supplies the original binding; `apply` must not create a new ranked map and interpret an old `eNN` in it. The fingerprint is an equality guard, not proof of object identity. Replacement at the same path with the same fingerprint remains possible and is covered by the disclosed limitations in §6.5. A changed child order can cause conservative refusal; that is acceptable.

The single-use marker remains an implementable at-most-once mechanism: successful exclusive creation before dispatch means a later invocation cannot dispatch the token again. A killed process cannot itself print `unknownOutcome`, and a marker alone does not prove that dispatch occurred. That recovery wording is a non-blocking precision issue, not a retained-context defect. Persisted generation allocation and record encoding still need implementation, but no daemon or surviving AX object is needed to implement this contract.

**B10 checker — verified closed, including attempts to break the fix.**

| Command / fixture | Observed result |
|---|---|
| `python3 scripts/test_check_secrets.py` | Exit **0**, **27/27** assertions. |
| `python3 scripts/check-secrets.py`, canonical repository | Exit **0**, **33 index files** at the recorded verification point, zero reported credential material. The index changed externally during this review; this count describes that run. |
| Same checker command in the review worktree, which has no `.env` | Exit **2**, `.env not found`; this is expected and is not the canonical-repository scan. |
| Unknown-shape key, bare / single-quoted / double-quoted, each followed by a comment | All exit **1** when the bare key is staged; none discloses it. |
| Hash inside quoted value; unquoted hash without preceding whitespace | Full configured values detected, exit **1**. |
| Configured key and a different recognized credential in the same filename | Exit **1**, both redacted. |
| Staged secret subsequently deleted from the working tree | Exit **1**. |
| Empty or missing `.env` value | Exit **2**, with the checker actually installed and executed. |
| Quoted-comment fixture using `00d2094` checker | Exit **0**: reproduced the old false negative. |
| Same fixture using `2a899d6` checker | Exit **1**: reproduced the repair. |

`scripts/check-secrets.py:78–86` now stops at the closing quote before handling outside comments. An internal `#` remains data. The bare branch removes whitespace-then-`#`, as specified. The regression uses a key outside the recognized credential shapes, so a regex fallback cannot hide a broken exact match.

The independent Executor ran a broader 21-case matrix. I inspected its harness and found one false pass in its evidence: the absent-`.env` case had not installed the checker, so Python's missing-script exit 2 was mistaken for the checker's exit 2. The Executor corrected it. My own ten-case witness independently exercises the real checker, including this case and the before/after regression. The repository suite also covers it correctly. This was a test-harness defect, not a newly discovered checker defect.

No new defect was established in the supported single-line syntax. This is not a claim of full shell/dotenv parsing, historical-Git scanning, or arbitrary personal-data detection. The latter remains the transformer's responsibility. Checker SHA256: `5e94ac09260a313f121bf93c77cff5519301f5a1daaf62d11336db5a3da3444e`.

**B9 — identity and S are fixed; exact refusal scoring is not.**

`SPEC.md:750–759` now identifies an oracle target by the handle from that case's own snapshot. With two controls named `Open`, selecting `e01` when the expected target is `e00` fails. Repeating a label no longer makes a wrong target correct. The existing prohibition on renumbering emitted handles preserves identity under pruning. Both the selected target and the expected target must remain in that same case namespace.

S is well defined for concrete action cases: take the `act` cases whose **final gated** operation equals the expected operation. The numerator counts correct target IDs **and arguments within S**; the denominator is `|S|`. A right target paired with a wrong operation contributes to neither. A witness with one operation-correct/wrong-target case and one operation-wrong/right-target case gives S size 1 and target accuracy 0. Empty S yields null under `:782`. These changes close the two issues singled out in the user's identity question.

The remaining defect is `SPEC.md:775`: `exactAccuracy` counts a correct operation/target/argument triple over **all cases**, while `:763–765` gives refusal cases an expected refusal code. It never defines their contribution to exact accuracy. For one correct act case and one correctly refused case, counting only action triples gives 1/2; class-aware exact matching gives 2/2. The implementer still has to choose the metric's policy. This was explicitly requested in the v3 review and was not addressed by changing target labels to IDs.

**Required B9 correction:** define exact match by class: for `act`, the expected operation plus an accepted target ID plus exact arguments; for `refuse`, the exact expected refusal code and no action. Divide the sum by all cases. State the result for a two-case all-correct example. This is one definition, not a new metric project.

Non-blocking metric precision: if `acceptableTargetIds` permits several targets, `targetPrunedRate` currently checks only `expect.targetId`. Say whether this intentionally measures the primary target's pruning or whether it should count only when **all acceptable IDs** are unavailable. Also keep “acted” clearly tied to the final action decision in this evaluation; it is not a measured physical application success rate.

**B10 transformation — the exhaustive-table claim is false as written.**

The useful changes are real: name, description, help, identifier, and value now have explicit replacement rows. Real goals and accuracy oracles are omitted, and original responses are discarded. Re-recording responses against the transformed state avoids reusing answers to different input. Replay need not retain real goals or produce accuracy scores; the synthetic-case split is acceptable.

Two concrete problems remain:

1. **The whitelist rejects metadata required elsewhere.** `SPEC.md:696–697` requires the completeness flag in **every corpus case**. The allegedly exhaustive emitted-field table at `:820–833` has no completeness field. Dropping it violates §8.2; emitting it violates §10.1. The table also is not a complete replay envelope for the scripted transitions and recorded normalized result required by `:706–713,720–722,793–795`. “Recorded Jev responses” is a category, not a recursive field schema. This need not become an enormous table: distinguish the captured AX payload whitelist from a closed, synthetic replay-envelope schema and list the necessary metadata there. At minimum, resolve completeness explicitly.
2. **Being an AX role string does not make a value safe to publish.** `SPEC.md:829` preserves `role` unchanged on the premise that it is not user content. The installed SDK's `AXAttributeConstants.h:187–197` permits either a standard role or an application-defined string. A role such as `CustomRole_PRIVATE_SENTINEL` survives the specified transform unchanged; nothing in eligibility normalizes it to a standard enum. A field whitelist cannot prevent content leakage through an allowed string field. Custom action names likewise must not be assumed to be a closed enum merely because they are actions.

**Required B10 correction:** close the replay envelope, including completeness; keep only explicitly allowed standard role/action constants unchanged and replace or omit other strings. Apply rejection of unknown fields recursively. Fix placeholder numbering in one sentence—first appearance in the frozen pre-transform order, with a stated per-fixture scope—and preserve that order/handle assignment rather than re-ranking placeholder names. Goals and accuracy oracles should remain absent from captured replay fixtures.

The current jitter cannot promise preserved spatial order: x positions `[0,1,2,3]` become `[0,3,6,4]`. If “order preserved” means array order, say so. This is a bounded clarification; replay-only frames do not have to model live geometry faithfully.

The sentence that `scripts/` already asserts the whitelist is not implementation evidence. The tracked scripts are the secret checker and its tests; there is no fixture-schema validator yet. That is expected at spec stage and is **not**, by itself, an extra blocker. Describe the assertion as a required verification, and make its proposed schema consistent enough to implement.

**B11 — secure-field exclusion checks the wrong attribute; the late edit substitutes an unsupported conclusion.**

At the requested revision, `SPEC.md:443–445` places `AXSecureTextField` among excluded **roles**. The installed macOS SDK instead declares:

- `AXRoleConstants.h:360` — `kAXTextFieldRole` is `AXTextField`.
- `AXRoleConstants.h:408` — **`kAXSecureTextFieldSubrole` is `AXSecureTextField`**.
- `AXAttributeConstants.h:214–243` — `kAXSubroleAttribute` supplies the finer classification.
- AppKit `NSAccessibilityConstants.h:573` — `NSAccessibilitySecureTextFieldSubrole` is also declared.

A fixture with role `AXTextField`, subrole `AXSecureTextField`, an ordinary label, and a writable value bypasses a role-only comparison against `AXSecureTextField`. Model risk/argument checks are not a replacement for the declared unconditional destination exclusion.

**Required B11 correction:** state the predicate on **`AXSubrole`**, compare it with `kAXSecureTextFieldSubrole`, and require refusal before dispatch when it matches. Include that normalized subrole in the fake-backend test so a secure-field fixture cannot fall through as an ordinary text field. Do not claim that every application reports it correctly; absence is not proof that a destination is non-secure.

**Late diff, `f26c00b`:** the external edit removes the role check, claims AX cannot distinguish password fields, and adds refusal for focused setter targets. It does not close B11. The existence of the documented SDK subrole refutes the categorical “no standard attribute/convention” claim in the new `evidence/ax-secure-text-field.md:16–18,36–38`. Testing two nonexistent symbol names and observing equal broad roles does not test the subrole. Its own admission that subroles were not tested limits its evidence. The new prose also says a pre-focused field can still be written while the new rule says focused targets refuse; those sentences conflict.

I did not accept that external change as part of the authorized review lane. The lane was explicitly read-only outside its evidence directory. The review reports the actual late diff rather than relying on its commit title or the Executor's scope-compliance claim. No further source change was requested.

My own unattached `NSSecureTextField` probe returned `AXUnknown`/nil and trust=false, so it supplies **no live secure-field classification evidence**. The finding above rests on the SDK's declared role/subrole contract and a literal guard counterexample, not on that inconclusive probe.

**The non-toggle press rule is acceptable for v1.**

`SPEC.md:549–562` preserves a useful, narrow meaning for `applied`: setter read-back equals the intended text, or a supported radio/checkbox value changes. Ordinary button/menu presses can dispatch under approval but remain `unknownOutcome`; they are never automatically retried. That limits confirmation coverage without making `applied` empty. Do not promote an AX return code or a readable unchanged label into proof of an effect.

The overstatement is “no reliable predicate exists” (`:557`), repeated in `evidence/ax-effect-predicate.md:23–26`. The read-only survey establishes unreadable AXValue on some menu controls. It does not prove that no focus, menu, selection, or window postcondition could exist. Say **“v1 defines no generic confirmation predicate for other press roles.”** The same survey shows radio values, not universal checkbox support or successful pre/post mutations. This is a claims correction, not a requirement to expand v1 confirmation coverage.

**Measured claims and cross-document consistency.**

The risk-gate arithmetic still checks out: parsing the 15 paired rows in `evidence/risk-gate-calibration.md` gives 15/15 benign passes and 15/15 destructive refusals under the adopted conjunction. Score alone separates those samples; confidence alone admits one destructive sample. These observations do not calibrate the new binding-specific prompt automatically, and they do not prove safety against adversarial screen content. SPEC now substantially acknowledges those limits.

The byte cap remains an empirical policy with server rejection as the final guard; that is implementable and fail-closed. The older `evidence/token-budget-bound.md` still uses stronger “bound” language than SPEC and misattributes a prior small-request measurement. Align it. The Choice inversion is arithmetic, not proof of identical calibration across candidate counts; the stated 0.851 lower endpoint is rounded.

Canonical TypeSafe checks were restricted to `docs.typesafe.ai`: [System One](https://docs.typesafe.ai/concepts/system-one) still specifies text input; [Primitives](https://docs.typesafe.ai/primitives) confirms independent questions and the distinct Choice/Score/Noul shapes; [Models](https://docs.typesafe.ai/models) lists Jev 1.13 and both aliases; [Client SDKs](https://docs.typesafe.ai/sdk) lists Python and JavaScript/TypeScript. Those support the integration direction. The models page distinguishes documented versioned IDs from the `/v1/models` alias listing and describes both total-request and state-plus-longest-question budgets; SPEC's approximately 32.8k observation is not a universal total-request limit. I made no fresh inference API calls and did not rerun the original latency/calibration experiments.

These documentation inconsistencies remain **non-blocking** after the specific contract defects above are fixed:

- `SECURITY.md:77` still says SHA256 comparison; `SPEC.md:878–879` and checker source correctly say literal bytes. SECURITY also says deleting `.env` revokes the credential (`:14–15`); it only deletes the local copy.
- `SECURITY.md:19–23` describes only screen content being sent, but `SPEC.md:198,237–243,259–265` also sends the operator's goal and extracted argument. The argument-secret question evaluates text **after that text is supplied to the API**. It is a dispatch gate, not a pre-egress secret filter.
- SECURITY's artifact table (`:30–34`) and CONTRIBUTING's instructions (`:28–34`) retain the old single corpus directory and do not explain the replay/synthetic split or new private approval records. `SPEC.md:860–861` cannot literally call the sanitized corpus the only artifact containing element text when raw captures and approval fingerprints also contain it. Qualify “published artifact.”
- SPEC still calls itself v2, says 18 checker assertions, refers to nonexistent “§5.2 rule 9,” and says Noul is used only for `applied` despite `argSafe`. The “no tolerance”/“near-tie is a tie” wording should use the exact-top-tie rule consistently. The `decide`/`--approve` token-minting descriptions should agree with §6.2.
- Metrics are produced only from synthetic cases. They do not, by themselves, measure accuracy on natural captured applications or establish the broad raw-AX research claim in §1/§14. Replay demonstrates deterministic handling of its fixtures; it does not establish real-desktop grounding accuracy.
- The late walk-latency note at `9d6321b` calls five-run observations a latency bound. They are samples. Its 4.2s + one Jev round-trip estimate also omits the specified two-phase decision flow and does not prove an expiry guarantee. None of this is needed to close B3.

**Evidence and handoff.** `.atc/spec-review-v4/` in the review worktree contains the task/brief, required-command outputs, ten-case checker witness script/results, metric/transform witnesses, SDK excerpts, and the AX trust/probe result. The canonical repository has the Executor's report and corrected matrix under `.atc/spec-review-v4/executor-evidence/`. The review used one bounded evidence lane through the [takeoff skill](/Users/feral/.codex/skills/takeoff/SKILL.md); its reports were checked against actual source and independently reproduced where relied upon. There is no production approval service, transformer, evaluator, or actuator here to verify end to end, and their absence is not an added spec-readiness objection.

The required corrections are: **define class-aware exact accuracy; close the replay schema and normalize retained role/action strings; explicitly exclude the secure-text subrole.** B3, the quoted-env regression, and the narrow `unknownOutcome` policy do not need another redesign.
