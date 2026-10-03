**Verdict: NOT_READY.** B6 is closed. B3, B5, B7, B8, B9 and B10 still need contract corrections. The residual-race disclosure, primitive separation, corrected Noul polarity, corrected Score-confidence formula, and offline/live evaluation split are real improvements. This verdict does not require an agent loop, pixels, coordinate clicking, or a GUI.

**Reviewed revision:** `2398d65d26bf583f550018d12bb3f2a8f09fa586` in `/Users/feral/mydev/jevscope`, 2026-10-02. The worktree began at `d2bd607`; I incorporated target changes through `528a0d2`, `e252b0e`, `57509ff` and `2398d65`. The fractional-risk hole, unknown-enabled apply check, and incorrect inverse-Choice arithmetic were fixed during this review and are **not current blockers**. Both 528a0d2 and 2398d65 are preserved under `.atc/spec-review-v2/`. For stable evidence pointers, unqualified SPEC line references below refer to the preserved **528a0d2** text; current changes are explicitly identified as **2398d65**. Unchanged findings were checked against the final revision.

**Lens:** implementability and fail-closed behavior at the decision/dispatch boundary. A written invariant counts as a requirement, not proof of implemented behavior. I checked concrete counterexamples rather than requiring the unfinished product to exist. Source files were not rewritten, committed, or merged.

**Blocker disposition**

| Prior blocker | Status | Evidence and disposition |
|---|---|---|
| B3 | **STILL-BLOCKING** | `SPEC.md:380–389` honestly discloses the residual race. `:351–358` names a digest and asserts consumption, but does not define the state/lifetime that makes separate `decide`/`apply` invocations single-use or preserves their retained bindings. |
| B5 | **STILL-BLOCKING** | `SPEC.md:250` closes the fractional Score hole. `:256–259` rejects capability-incompatible pairs. But independently evaluated questions cannot implicitly consume each other's selected answers (`:186–216`), and the exact request, argument extraction, semantic allowlist and response contract still leave safety choices to the implementer. |
| B6 | **CLOSED** | `SPEC.md:338–347` distinguishes AXPress from setting AXValue, checks the appropriate capability, supplies a text origin, defines whole-value replacement, and excludes implicit submission. `:369–378` applies the no-retry/outcome contract to mutations generally. |
| B7 | **STILL-BLOCKING** | Current 2398d65 `SPEC.md:449–452` replaces the disproved bytes-only bound with another empirical estimate claimed as a bound. Stable IDs and bounded refusal are improved; ranking/overflow policy details remain. |
| B8 | **STILL-BLOCKING** | Unknown-enabled is now closed: current 2398d65 `SPEC.md:368–372` requires explicit true. The remaining blocker is `SPEC.md:497` (partial AND fewer than three) versus `SECURITY.md:52` (incomplete OR fewer than three), plus truncation completeness. |
| B9 | **STILL-BLOCKING** | `SPEC.md:503–513` correctly separates replay and live evaluation. `:531` defines refusal recall under the name precision; zero-denominator behavior and the treatment of wrong actions/arguments remain incomplete. |
| B10 | **STILL-BLOCKING** | `SPEC.md:554` removes target semantics while retaining the natural-language goal; oracle/response/metadata sanitization is not specified. The checker passes ordinary tests but demonstrably misses tracked secrets and can disclose a secret in a filename. |

**B3 — disclosure is fixed; token lifecycle is not yet a complete contract.**

§6.5 does not quietly reinstate atomicity. It explicitly admits replacement, row reuse and changed selection between the check and use. §6.3 also explicitly excludes same-role substitution from detection. I accept that disclosed limitation; I am not demanding that AX provide a transaction.

The hash includes generation, app launch, primitive, handle, arguments, thresholds and question version. Those are useful bindings. However, hashing them does not consume anything. The explanation at `SPEC.md:356–358` establishes that a new generation produces a different token, not that the old token cannot be applied twice. No authoritative outstanding-decision record, atomic consume-before-dispatch rule, restart/concurrent-apply behavior, or generation lifetime is specified. The CLI at `:610–611` separates the two invocations, while `:361` requires a retained backend reference. The owner and lifetime connecting those statements are missing.

The token also lacks a defined canonical encoding and a defined binding from generation to the complete immutable snapshot/handle map and operation context. A generation can supply that binding; it need not duplicate every snapshot field in the hash. But the spec must say what generation identifies and when that identity expires. A hash of concatenated values without framing is not by itself an unambiguous tuple encoding.

**Required change:** specify one local approval record/lifetime, canonical binding to the immutable decision and snapshot context, non-reused generation identity, and atomic consumption before dispatch, including replay after failure/restart. Explain how `apply` reaches the retained binding. Unknown, consumed or expired records must refuse. A short state transition table is enough; this does not require a new autonomous agent or cryptographic signing system. Correct `:327–328`, which says the flag mints the token, to agree with §6.2.

**B5 — pair capability checks work, but decision semantics still have holes.**

For the requested composition walk: give `operation=setValue` confidence 0.97 and a press-only button target confidence 0.96. Individually they pass. §5.3 then consults §6.1, finds AXValue is not settable, and returns `unsupportedAction`. That particular original defect is **closed**.

A different problem remains: the request asks risk about the selected operation and target about that operation, while asking all four questions together. TypeSafe evaluates each question independently against the shared state; one answer is not another question's input. A risk answer about an inferred benign action is not automatically a risk answer about the operation/target/arguments that the application ultimately combines. A press on a Send button also passes the AXPress capability table; excluding the operation string `send` does not exclude that effect. The only label filter specified applies to menu items and its regex is not supplied. [Canonical question-composition contract](https://docs.typesafe.ai/primitives).

`SPEC.md:189–219` remains a skeleton with ellipses, prose question descriptions, and no goal field in the illustrated state. `:339` says text comes from the goal but does not distinguish the full goal string from an extracted quoted argument. For `set the search field to "cats"`, those interpretations write different values. These are policy/contract choices, not Swift implementation details.

Validation also needs primitive-specific rules. Score has indexed probability keys, whereas its criteria are an array; Noul has no probability map. §5.2 must scope its rules accordingly, validate finite/in-range Score values, and require exact Choice argmax identity rather than saying an option key equals an argmax “within 0.02.” The new top-tie rule correctly stops rejecting merely tied losing options. `SPEC.md:374` needs an outcome predicate: a successful read of an unchanged label does not confirm the requested effect. When a mutation was dispatched but its effect cannot be confirmed, preserve `unknownOutcome`.

**Required change:** supply the actual versioned request/decision schema and deterministic text-argument rule; make the risk judgment explicitly concern the exact candidate binding (for example, a follow-up request with that binding, or per-binding questions built before dispatch); specify the semantic exclusions across target roles; finish type-specific answer checks and the confirmation predicate. Keep the current permissive-only risk gate.

**Risk-gate recheck:** the latest rule requires `score <= 0.20 AND confidence >= 0.85`. It rejects the original problematic fractional values, including the supplied score 1.57/confidence 0.36, and our new live score 1.96/confidence 0.94. Recalculating the 30 rows in `evidence/risk-gate-calibration.md` gives **15/15 benign pass and 15/15 destructive refuse**, as claimed. That is arithmetic on supplied observations, not independent reproduction of their prompts/runs.

The supporting explanation is still wrong: confidence 0.66 cannot pass a 0.85 minimum. Confidence alone would admit **erase all local data at 0.87**, not force quit at 0.66. The evidence file also writes `0.87 < 0.85`, which is false. Score alone separates every case in this small table, so it does not demonstrate that both conditions were necessary for this sample. Keeping both checks is reasonable; fix the explanation. The stated sample-size and text-only limitations are appropriate. The reported risk-Noul overlap does not prove that all possible Noul prompts fail, but it supports rejecting that particular risk question.

**B6 — closed at the primitive-contract level.**

The setter no longer depends on an offered named AX action; its capability is `AXUIElementIsAttributeSettable`. Replacement and submission are distinguished. Installed `AXUIElement.h:188–223,283–331` confirms the separate APIs and the action-timeout caveat. The new read-only survey queries settability and checks the AX return code (`evidence/axsettable.swift:26–30`). It is evidence about those elements, not proof that arbitrary settable attributes accept strings. Restricting the setter to suitable text/value types belongs in the B5 schema completion. The §7 named-action eligibility filter may still discard a valid setter-only element; that is a conservative coverage limitation, not the old unsafe actuator conflation.

**B7 — stable IDs improve; the bound and reproducibility claims overreach.**

The full-request byte cap and bounded overflow refusal are implementable as a conservative **size policy**. They are not a proved token bound. A request sent to `https://api.typesafe.ai/v1/systemone` contained **93 UTF-8 bytes** and returned **270 input tokens**, HTTP 200, model `jev-1.13.0`. The server adds model framing not present in the HTTP serialization. The original `evidence/token-budget-bound.md` sampled a few large, one-Choice requests; those observations could not establish a universal upper bound. The latest version adds small requests and acknowledges framing. It now adopts `requestBytes + 512 <= 30,000`, but current 2398d65 `SPEC.md:449–452` again claims this bounds tokens. Seven observations cannot establish the variable-part bound for arbitrary text or the four-question template. The evidence itself calls the allowance empirical, not contractual. Also, its attribution of 139 bytes / 304 tokens to this review is inaccurate: this review measured 93 / 270; the 139 / 304 record is supplied author evidence. Canonical limits are 64k per request and 32k for state plus the longest question. [Canonical model limits](https://docs.typesafe.ai/models).

This counterexample does **not** prove that either the original 28KB cap or the new bytes-plus-512 policy exceeds the live context limit. The new policy covers my two successful request samples too. On server rejection, no decision exists to execute, and bounded retry/refusal remains fail-closed. Call the adopted policy an empirical cap and retain that fallback; a tokenizer project is unnecessary.

Pruning preserves IDs as written: assign IDs from one fixed ranking, then keep prefixes without renumbering. K=24 and K=12 give the shared first twelve candidates the same handles. Escaping and explicit `none` are also improvements. These are confirmed properties of the proposed contract, not tested product behavior.

The remaining deterministic choices are small but real: define the stopword set, path/tie ordering, and when to stop dropping action descriptions (including their duplicate in target criteria). Resolve whether cap 24 includes `none`; K=24 candidates plus `none` produces 25 options. Define valid configurable K and K/2 rounding/minimum. `SPEC.md:96–99` says the token error is non-retryable while `:440–441` permits one retry. K=1 also conflicts with the minimum-three rule in SECURITY.md.

**Required change:** remove the proved-bound claim, fix those few constants/serialization rules, and state one overflow/minimum-candidate policy. Keep immutable handles and terminal refusal.

**B8 — unknown-enabled is closed; completeness policy still contradicts itself.**

Capture already required `enabled == true` and dropped absence. The initial apply rule permitted `enabled != false`; running Swift with `let x: Bool? = nil` confirmed that expression is **true**. Commit e252b0e fixes it. Current 2398d65 `SPEC.md:368–372` requires explicit true and refuses nil as `enabledUnknown`; `:493` drops absence during capture. **No remaining unknown-to-enabled path was found in this revised contract.** This requested B8 subcheck is closed.

`SPEC.md:476` refuses only **partial AND fewer than three**. `SECURITY.md:52` forbids **incomplete OR fewer than three**. Consequently a partial snapshot with four candidates, and a complete snapshot with one candidate, pass the former condition and fail the latter. Depth/node-limit termination also needs to set the partial flag, not merely increment a counter (`SPEC.md:474`).

**Required change:** choose one completeness/minimum-candidate predicate and use it in the spec, security policy and pruning ladder; mark actual traversal truncation partial. Keep the corrected successful, well-typed enabled check. The normalized fake backend and zero/one action-log assertions are otherwise adequate improvements.

**B9 — reproducibility is corrected; headline metric semantics are not.**

The offline/live split removes the prior impossible equality requirement. Pinning should mean sending the resolved immutable model ID on every live request, not just recording the first response's ID; §9.2 can make that explicit.

`refusalPrecision = correct refusals / oracle refusals` is recall. Consider 100 cases, 20 requiring refusal, and a system refusing every case with the appropriate refusal class. The advertised metric is **20/20 = 1.0**, although actual refusal precision is **20/100 = 0.20**. Coverage reports 0, so the whole metric vector exposes this system; it can still win the mislabeled headline metric. `:536` also does not say whether “zero refusals” refers to predicted or oracle refusals. `falseActRate` and conditional target accuracy have undefined 0/0 cases.

The proposed false-act metric ignores wrong targets on action-required cases. `exactAccuracy` omits setValue arguments. Target names can collide, and it is unclear whether the targetAccuracy numerator is restricted to the same operation-correct subset as its denominator. These omissions affect what the harness reports as correct.

**Required change:** either rename the refusal metric to recall and add precision, or use predicted refusals as its precision denominator; define null on every empty denominator; use the final gated decision and explicit case classes; define wrong-target/wrong-argument scoring and stable oracle identities. Always report coverage beside selective metrics. No arbitrary minimum accuracy target is required by this review.

**B10 — publication classes are reconciled, but transformation and checker are incomplete.**

The three documents now agree that raw captures are private and a sanitized corpus is committed. The location conflict and key/TCC conflation are closed. However, `SPEC.md:554` replaces all labels/values with opaque placeholders while retaining a goal such as `switch to list view`; the example oracle still expects `target_name: "list view"` (`:517–522`). The input label and expected label no longer match, and the model loses the semantics needed for the goal. Rewriting only the oracle does not restore those semantics. Replaying answers recorded before transformation also does not measure decisions on the transformed state.

No common transformation is specified for window titles, identifiers, descriptions/help, goals containing private values, expected/acceptable targets, recorded responses, or action arguments. Frame jitter can also change the ranking/eligibility oracle unless its order and seed are fixed. Traces contain a decision/action log but do not define whether that includes raw setValue arguments; an API key supplied as goal text could be written there despite the blanket “never written” claim.

**Required change:** define one field-level corpus/trace schema and deterministic transformation, with goal/oracle/recorded-response consistency. Use a declared semantic-preserving sanitized or controlled synthetic corpus, or explicitly limit opaque-placeholder cases to offline replay. Do not claim that a current-key scanner detects arbitrary private screen data.

**Secret-check execution results.** The production checker was not modified. Synthetic cases ran in disposable git repositories with the exact script bytes. The wrapper captured stdout/stderr and redacted the synthetic credential before saving evidence; no real credential was printed or placed in command arguments.

| Test | Actual result |
|---|---|
| Clean target checkout at 528a0d2 | Exit **0**, scanned 24 tracked files, no credential disclosed |
| Clean disposable fixture | Exit **0** |
| Exact configured secret in ordinary tracked file | Exit **1**, only the harmless path reported |
| Harmless documentation containing an OAuth prefix alone | Exit **1**: false positive |
| Exact secret appended in a comment in check-secrets.py | Exit **0**: missed |
| Exact secret in a tracked file larger than 8MiB | Exit **0**: missed |
| Exact secret staged, then removed from working copy | Exit **0**: staged leak missed |
| .env assignment with an inline comment; exact key planted | Exit **0**: parser included the comment in the needle |
| Tracked file absent from disk | Exit **0**, file silently skipped |
| Secret in both tracked filename and contents | Exit **1**, **secret appeared in stdout via filename** |
| Different synthetic credential with same prefix as configured key | Exit **0**: prefix check disabled for that prefix |

Mechanisms: `scripts/check-secrets.py:61–62` excludes its entire source; `:64–68` silently skips oversized/unreadable files; `:43–48,66` lists tracked paths but reads working-copy bytes, not staged blobs; `:30–36` implements only a partial dotenv parser; `:54` disables a fragment found inside the current key; `:77` prints unredacted filenames. There is **no digest comparison**: `:70` performs byte-substring matching. That approach is fine in principle and keeps the configured key out of the script's git argv (`:43`); the digest claim in SPEC/SECURITY is simply false.

**Required change:** scan the exact key in every tracked file including the checker; fail with a non-clean status on unscannable inputs; cover the publication surface promised by the check, including staged content if used as a pre-PR gate; parse the supported env format correctly or reject it; redact paths as well as contents; match credential shapes rather than bare prefixes. Exempting prefix literals in the scanner must not exempt its exact-key scan. Add the above small fixtures to the checker verification. Hashing every substring is not required.

**Claim verification ledger**

| Claim | Disposition |
|---|---|
| B1: high Noul means yes; no separate confidence | **CONFIRMED.** Canonical [Noul contract](https://docs.typesafe.ai/primitives/noul); live red/blue test returned 0.96/0.01, no confidence field. §§4.4/5.4 consistently use that polarity and completion meaning. |
| B2: Score confidence is centered on the mode, not returned mean | **CONFIRMED.** Recomputed all 24 supplied samples: max error **0.020000**, mean **0.008333**. [Canonical confidence formula](https://docs.typesafe.ai/confidence). Latest risk gate correctly thresholds the mean score separately from its confidence. |
| §4.4 affine example, n=3 and p_max=0.8 gives confidence 0.7 | **CONFIRMED numerically.** `(0.8−1/3)/(1−1/3)=0.7`. |
| §5.4 inverse-threshold table and K=24 claim | **CORRECTED during review.** The 528a0d2 table was refuted; current 2398d65 `SPEC.md:271–287` contains the correct rounded values and removes the redundant floor. Exact minima are n=2: **0.925**; n=3: **0.900**; n=5: **0.880**; n=24: **0.85625**; n=255: **0.850588**; 24 candidates plus none gives n=25: **0.856**. The remaining phrase “candidate-count independent” should distinguish using the same confidence threshold from imposing the same probability threshold: the latter still depends on n. This is non-blocking wording. |
| Current risk gate classifies all 30 supplied cases correctly | **CONFIRMED by recalculation**, not a fresh reproduction of their measurements. The 0.66/0.85 and 0.87/0.85 explanatory claims are **REFUTED**. |
| Token upper bounds | Original bytes-only claim **REFUTED** by 93 bytes → 270 input tokens and withdrawn. The new bytes-plus-512 universal bound is **UNVERIFIED**, although it covers the supplied samples. Exact four-question maximum and original 799/800 boundary remain **UNVERIFIED**. |
| Checker passes clean and fails an ordinary planted key | **CONFIRMED** by execution. Universal non-disclosure and complete tracked-key detection are **REFUTED** by the fixture results. No-secret-in-argv mechanism is **CONFIRMED by source inspection**. |
| Official documented SDK list lacks Swift | **CONFIRMED** for the current [SDK index](https://docs.typesafe.ai/sdk), which lists Python and JavaScript/TypeScript. |
| /v1/models lists a versioned model alongside aliases | **REFUTED literally.** Live GET returned only `jev-latest` and `jev-preview`; POST resolved to `jev-1.13.0`. This matches the current [model-list documentation](https://docs.typesafe.ai/models). Correct §4.3 wording; not a readiness blocker. |
| This reviewer can reproduce live AX reads/setters/survey | **UNVERIFIABLE here.** `AXIsProcessTrusted()` returned **false**. macOS 27.0.1 and Swift 6.4 were confirmed. No permissions changed and no desktop mutation attempted. |
| Original eight Choice samples / all eighteen new affine samples | **UNVERIFIABLE as complete datasets.** The original inputs are absent; the new evidence displays nine of eighteen rows. Formula arithmetic is independently checkable without them. |

The latest `evidence/answer-validation-probe.md` adds six normal Choice observations, not malformed-response tests. It also claims a low-confidence `none` becomes `lowConfidence`, while current §5.3 returns `Decision(action: .none)` before confidence checks. Choose that precedence explicitly and align the evidence; no dispatch occurs in either case.

**Other non-blocking precision:** replace the setter survey's universal “sufficient” wording with what its three observed text controls establish; keep the verified API distinction. Clarify that deleting `.env` removes a local credential copy, not revokes an issued API key (`SECURITY.md:14–15`). The older `evidence/score-confidence-findings.md` still recommends raising a destructive Noul hi-threshold; mark that superseded by the current Score-risk policy. The prior-art universal claims, star counts and research percentages were not re-audited and do not support this verdict.

**Evidence and scope:** `.atc/spec-review-v2/` in `/private/tmp/worktrees/prompt-1790985452250-94863-0` contains `live-api.json`, `score-recalculation.json`, `late-revision-arithmetic.json`, `checker-results.json`, `final-tree-secret-check.json`, `ax-check.swift`, `ax-check-result.txt`, the installed AX header, downloaded canonical TypeSafe documentation, contract witnesses, task notes and the preserved reviewed revision. API requests used synthetic text only and read the configured credential in-process. Python arithmetic and fixture harnesses exited 0; individual checker statuses are tabulated above. The Swift read-only trust/optional comparison probe exited 0. No production package or corpus exists to run an end-to-end implementation test; their absence is expected at spec stage and is not itself a blocker.

**Late-revision verification:** `git diff 528a0d2..2398d65` was inspected. The checker, SECURITY.md and CONTRIBUTING.md are unchanged across that interval, so the checker fixture results still apply. No product source was changed by this review.

Final clean-tree check at 2398d65: `python3 scripts/check-secrets.py` exited **0**, scanned **25** tracked files, disclosed no credential. Both checkouts have only the new review file untracked; tracked reviewed sources are unchanged.
