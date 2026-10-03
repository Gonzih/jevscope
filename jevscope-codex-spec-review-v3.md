**Verdict: NOT_READY.** B3, B9 and B10 remain blocking. B5, B7 and B8 are closed after the verified late corrections; B6 remains closed. The remaining work is a retained-context lifetime contract, unambiguous evaluation identities, and a total publication transformation plus one remaining dotenv parsing defect. No autonomous loop, pixels, coordinate clicking or GUI is required.

**Reviewed revisions.** The requested revision was `33b659109eaff1f0b94df2cbe801b93282e84052`. During review, the target repository advanced through `d21b334` (read-only effect evidence), `2d27bc4` (argSafe polarity), and `00d209432c4bc0c714b80e90119d123622c04e1e` (checker fixes). I inspected those diffs and incorporated their verified corrections. **Unless explicitly prefixed 33b6591, SPEC and scanner line references below refer to final 00d2094.** The review worktree remains at 33b6591 and preserves both SPEC versions and both scanner versions under `.atc/spec-review-v3/`. At 33b6591 alone, B5 was still blocking because its secret check was reversed; that defect is corrected, not silently omitted.

**Lens:** implementability and fail-closed behavior at selection, approval, dispatch and publication boundaries. Written requirements are not proof of implemented runtime behavior. I read the prior review, the full SPEC, SECURITY, CONTRIBUTING, checker/test sources and relevant evidence; ran the requested commands; used synthetic API requests and disposable scanner fixtures; and inspected the actual late changes. I did not rewrite the spec or production scripts, commit, merge, or mutate the desktop. An existing Executor supplied a bounded scanner evidence lane through the [takeoff skill](/Users/feral/.codex/skills/takeoff/SKILL.md); I inspected its artifacts and independently reproduced its two substantive findings. The target session also made the late commits; those changes are distinguished from this review's evidence work.

**Blocker disposition**

| Blocker | Status | Evidence |
|---|---|---|
| B3 | **STILL-BLOCKING** | `SPEC.md:461` persists approval metadata, but `:495` requires a retained backend reference and `:857–858` uses separate CLI invocations. No owner/lifetime connects them, and the record stores an argument digest rather than the text needed by the setter. Single consumption itself is improved and sound for process crashes. |
| B5 | **CLOSED, after 2d27bc4** | `SPEC.md:231–253,318–325` makes risk depend on the selected binding and uses only Phase 2 to authorize. `:270–295` separates Choice/Score/Noul checks correctly. The originally reversed argSafe gate now requires a confident safe answer. |
| B7 | **CLOSED** | `SPEC.md:580–624` withdraws a proved token bound, imposes an empirical cap, preserves a minimum of three candidates, and permits one client-level overflow retry. The effective v1 K range is safe; a contradictory general upper-limit sentence needs cleanup, not a new architecture. |
| B8 | **CLOSED** | `SPEC.md:656–659` marks enumeration/depth/node-cap/cycle truncation partial and refuses `partial OR eligibleCount < 3`; `SECURITY.md:56–57` says the same. Explicitly-true enabled checks remain. |
| B9 | **STILL-BLOCKING** | `SPEC.md:728–738` fixes precision/recall denominators, null denominators and visible coverage. But `:713–715,741–743` still identifies targets by labels, so selecting the wrong same-name element is scored correct. The conditional target numerator also needs the same subset as its denominator. |
| B10 | **STILL-BLOCKING** | `SPEC.md:759–778` correctly separates replay fixtures from scored synthetic cases, but its transformation is not a total emitted-field contract. `scripts/check-secrets.py:69–76` still misparses a quoted key followed by an inline comment, and the exact-key leak passes. Trace goal/argument suppression is now explicit. |

**B3 — walk of the approval state table.**

`SPEC.md:470–482` now supplies actual consumption state. An issued token whose preconditions pass must win exclusive creation of its `.consumed` marker before dispatch. A second caller cannot win the same creation. A precondition failure also spends the token; an unknown/expired token refuses; an already consumed token refuses. These are adequate at-most-once dispatch requirements, not an exactly-once execution promise.

I exercised the proposed OS mechanism in 16 separate Python processes: **one exclusive create succeeded, 15 returned FileExistsError**, and a subsequent attempt after the winning process exited still failed. `contract-witnesses.py` exited 0. That checks the mechanism, not a jevscope actuator implementation.

Crash boundaries are now sensible:

- Before consumption: no dispatch has occurred, so an otherwise valid token may still be consumed once.
- After successful consumption but before dispatch: the action can be lost; the token remains spent.
- During/after dispatch: the marker prevents replay even if the caller never receives a result. No automatic retry is allowed.

A killed process cannot itself print `unknownOutcome`; recovery must treat a spent token conservatively. The marker alone does not establish that a dispatch happened. This does not undermine at-most-once dispatch. I did not test machine power-loss durability, disk rollback or an implemented recovery path.

`SPEC.md:484–492` explicitly requires the 120-second expiry and a persisted, monotonically increasing generation per capture. The former is correctly described as a replay/lifetime bound, not AX atomicity. The latter is a requirement the implementation must enforce, including concurrent allocation; it is not demonstrated by existing code. I do not require an implemented counter to approve a spec, nor treat a stated invariant as measured behavior.

**The remaining blocker is ownership of the retained decision.** After `jevscope decide` exits, its AX object references and immutable candidate map disappear unless some named owner survives it. The JSON record listed at `:461–464` contains identifiers and digests; it does not explain who holds that map/reference or the original setter argument, how the subsequent `apply` obtains them, or what restart does to them. A digest cannot recover the argument. Rewalking a new tree and reusing `e00` would violate the old generation binding. Refusing every separate invocation would be fail-closed but would not implement the promised approved action path.

**Small required correction:** choose and state the owner of the immutable snapshot, retained reference and original argument across `decide`/`apply`; describe how apply reaches that owner and require stale refusal when it is gone. A short lifetime paragraph is enough. This does not require a particular daemon architecture or an agent loop.

**Token encoding.** `SPEC.md:465–466` is a sound *length-framing construction*: with fixed field names/order, a defined byte encoding and byte-count lengths, delimiters inside values do not create tuple ambiguity. A decoder reads the length and then exactly that many bytes. SHA256 is a digest of that framing; hashing is not what removes concatenation ambiguity. I checked 64 sample tuples including empty strings, Unicode and embedded separator bytes under an explicit UTF-8/decimal-byte-length refinement, with 64 distinct encodings. This is a demonstration, not a collision proof or a product codec test. Non-blocking: specify UTF-8 byte lengths, integer/time formatting and field order literally before implementing the versioned codec. No keyed signature is demanded: the local record is the stated authority.

**B5 — the second request creates a real dependency; the original new gate was reversed.**

Phase 2 is constructed only after Phase 1 selects an operation and target. It includes the chosen operation, target role/name, exact argument and goal; only its risk answer gates permission. That does resolve the old error of expecting independent questions in one request to consume each other's answers. It agrees with the canonical [question-composition contract](https://docs.typesafe.ai/primitives). This is a data-dependency correction, not evidence that model risk judgments are infallible. Keep the selected local handle/generation binding unchanged while waiting for the response, and preserve relevant target context when building the concrete versioned request.

The first-quoted-span rule resolves the important former policy choice: `set the search field to "cats"` writes `cats`; no span refuses; `"a" "b"` picks `a`. It is total under literal matching of the two specified quote-pair forms, including refusal when no complete span exists. Do not silently introduce shell/JSON escape decoding. Non-blocking precision: pin the matching expression and literal-backslash/mixed-quote cases so two implementations cannot choose different quote parsers.

The type-specific validation is now correct for the wire shapes. A fresh synthetic POST to `https://api.typesafe.ai/v1/systemone` returned HTTP **200**, model **jev-1.13.0**:

| Answer | Actual fields/values |
|---|---|
| Choice | `choice=red`, confidence `0.99`, probabilities keyed by the supplied option strings |
| Score | score `0.03`, confidence `0.95`, `legend` and `probabilities` keyed by **"0", "1", "2"** |
| Noul | red `0.93`, blue `0.01`; each contained only `type` and `noul` |

These agree with the canonical [Score response](https://docs.typesafe.ai/primitives/score) and [Noul response](https://docs.typesafe.ai/primitives/noul). §5.2 does not require a map or confidence on Noul; finite/range checks apply to its own scalar. Rejecting tied Score modes is conservative, even though a mean score could still be calculated. The Choice wording “no tolerance” and “a near-tie is a tie” should be made consistent; the stated exact-top-tie rule is implementable and conservative.

**Correction during this review:** at 33b6591 `SPEC.md:243–244` asked whether arguments were *free of secrets*, while `:314` refused values ≥0.20 and permitted lower ones. That was a genuine reversed safety gate. The live harmless `cats` argument returned **0.94**, which that gate rejected. More fundamentally, a strong “not free of secrets” answer would pass it. Commit **2d27bc4**, now `SPEC.md:246–250,321–323`, requires **argSafe ≥0.80**, with uncertainty refused. This defect is closed in the final disposition.

I also sent the corrected Phase-2 example's two question objects with their criteria and no additional instructions. The live API accepted them (HTTP **200**, risk **0.02**, confidence **0.97**, argSafe **0.94**). I therefore do **not** claim those question objects are rejected as malformed. Exact prompt strings still need freezing for reproducible evaluation; the illustrated Phase-1 ellipses should not be mistaken for a complete copy-paste request.

**B7 — the unsafe claim is withdrawn; the effective constants fail closed.**

`SPEC.md:582–602` now says the size cap is empirical and explicitly rejects the former universal-bound argument. That closes the substantive blocker. A rejected oversized request cannot mint an executable decision; the fallback terminates in refusal.

The default candidate ladder **24 → 12 → 6 → 3** never violates §8.2's minimum. `none` is explicitly additional: 24 candidates produce **25** target options. The fixed stopword list and immutable post-ranking handles close the main reproducibility gaps. §4.5 and `:620–624` agree: HTTP transport does not blindly retry a 400; the client can lower the request by one rung for `max_tokens_exceeded`, retry once, then refuse.

The constants do **not literally all agree**: `:616` says configurable K ≤255, then `:617` reserves one of the maximum 255 options for `none`, implying K ≤254. But `:618` clamps v1 to **3…24**, so no v1 request reaches the contradictory limit. Fix the sentence, and define clamped integer halving for nondefault odd K plus whether removing action descriptions also removes their duplicated target-criteria text. These are bounded precision/coverage issues; the hard cap and terminal refusal preserve correctness.

`evidence/token-budget-bound.md:3–4,42–57` retains older “bound” language and wrongly attributes the 139-byte/304-token sample to the earlier reviewer; the actual prior review measured 93/270. The authoritative SPEC now corrects the claim. Align the evidence file; do not resurrect a tokenizer or bound project.

**B8 — identical completeness predicates, including traversal truncation.**

`SPEC.md:656–659` and `SECURITY.md:56–57` now refuse the same set:

| Snapshot | Eligible candidates | Result |
|---|---:|---|
| complete | 2 | refuse |
| complete | 3 | completeness gate passes |
| partial | 2 | refuse |
| partial | 4 | refuse |

Depth >40, node-cap termination, repeated-element/cycle termination and failed child enumeration mark partial. Merely reaching a depth with no unvisited children is not evidence of actual truncation; the implementation should preserve the stated distinction. Capture drops unknown enabled values; apply requires explicitly true (`SPEC.md:499–503`). No unknown-to-enabled permission path remains in this contract.

**B9 — precision/recall fixed; target identity still lets a wrong action pass.**

The denominators now differ correctly: refusal recall divides by oracle-refusal cases; refusal precision divides by predicted refusals. Both numerators require the correct refusal code. Every empty denominator is explicitly **null**. For 100 cases, 20 requiring refusal, a refuse-everything system with correct refusal codes gets recall **1**, precision **0.20**, coverage **0**, falseActRate **null**, and conditional targetAccuracy **null**. It can have perfect recall, as it should, but cannot legitimately advertise that alone under the requirement to show precision and coverage. This part is closed.

Arguments are now included in target/exact accuracy. A wrong argument therefore fails those metrics. `falseActRate` remains specifically “action on an oracle-refusal case”; it is not a comprehensive wrong-action rate, and that is acceptable if the other metrics catch target mistakes.

**Counterexample:** give two candidate elements distinct handles `e00` and `e01`, both labelled `Open`, with the same press primitive and null arguments. The intended target is e00, but the decision selects e01. Under `SPEC.md:713–715,741–743`, both labels satisfy the oracle. The wrong target scores correct. “Stable label” does not mean unique, and synthetic cases have no uniqueness requirement; §10's equal-name mapping does not make names unique either.

The table also leaves `targetAccuracy`'s numerator outside the explicitly operation-correct denominator subset (`:726`). A literal implementation can count a right target paired with a wrong operation in the numerator but not denominator. `exactAccuracy` over all cases needs to specify how exact refusal-code matches count for the refusal class.

**Small required correction:** identify expected/acceptable targets by stable per-case element ID (or explicitly enforce unique oracle labels), restrict the conditional numerator to the denominator subset, and define exact match for each case class. A wrong-same-label-target example and a wrong-argument example make the intended rule reviewable. No minimum benchmark score is demanded.

**B10 — the corpus purpose split works; the transform still is not total.**

Replay fixtures now carry placeholders, no oracle and no accuracy contribution. Hand-authored coherent synthetic cases alone produce metrics. That resolves the old placeholder-versus-natural-goal oracle contradiction. It does not establish accuracy on natural captured UIs; results should be described as synthetic-corpus results.

`SPEC.md:768–775` specifies transformations for window title, name/description, value, frame and bundle identifier. It still does not define the complete output schema or require dropping unspecified fields. In particular, retained raw AXIdentifier/AXHelp and other metadata have no stated handling; replay goal/argument handling is not specified by the trace-only rules. The value counter, app counter and source of the replacement “own recorded responses” also lack a complete rule. The split removes the need to preserve real-goal semantics in replay: simply omit or replace private goal/argument fields and declare the response fixtures synthetic or generated from the transformed state.

The frame formula is deterministic but not generally spatially order-preserving: consecutive original x positions **0,1,2,3** become **0,3,6,4** when adding `(index×7) mod 5`. If “order-preserving” means preserving the frozen array order rather than geometry, say that and do not re-rank after replacement/jitter. Do not use this formula as a claim about preserving frame eligibility near a screen edge.

**Small required correction:** give a whitelist of emitted replay fields with transformations and omit everything else; define how replay goals/arguments and synthetic response fixtures are supplied, freeze the order before transformation, and make counters deterministic. This closes both privacy and replay reproducibility without a general-purpose privacy detector.

**Traces:** `SPEC.md:787–797` explicitly forbids request/response bodies, raw arguments and verbatim goals; goals get digest plus length; the action log has primitive/handle/outcome. This closes the original goal-to-trace path **as a requirement**. Nested decision serialization must obey the same bans. There is no trace writer yet to verify at runtime. `SECURITY.md:77` still falsely says the scanner compares SHA256 digests; the scanner uses bytes, as SPEC correctly acknowledges. SECURITY/CONTRIBUTING also retain the older corpus layout. These stale descriptions need alignment.

**Secret checks — actual execution, including attempts to break the suite.**

The requested suite initially passed **18/18**, exit **0**; the production index check exited **0**, reporting **30** tracked files and no credential material. The scanner source under test was SHA256 `95ad204102939c784cefd9ef241727f636fadeea8907e326dd71b4636b32546b`. Synthetic fixtures ran against its exact bytes in disposable repositories; raw credential-bearing stdout was not saved or printed.

| Fixture | 33b6591 checker | Final 00d2094 checker |
|---|---|---|
| Ordinary configured key of unknown shape in tracked content | exit 1; no disclosure | exit 1; no disclosure |
| Unknown-shape configured key, **unquoted** `.env` value plus inline comment; bare key planted | **exit 0: missed** | exit 1; no disclosure |
| Different recognized credential in a tracked filename | exit 1; **credential printed** | exit 1; no disclosure |
| Quoted known-shape key plus trailing inline comment, key in filename | exit 1; **configured credential printed** | exit 1; no disclosure |
| **Quoted unknown-shape key plus trailing inline comment**, bare key planted | same defective parsing mechanism | **exit 0: missed** |

At 33b6591, `parse_env` kept the comment in the exact needle. The inline-comment test happened to use a key matching a SHAPES regex, so shape detection hid the broken exact match. The original suite also checked a second credential in file contents, not its filename; redaction covered only the configured key. The Executor found the first two failures and I reproduced them independently.

Commit **00d2094** adds shape redaction and unquoted comment handling. I inspected it, reran the suite (**23/23**, exit **0**), reran the production checker (**0**, 30 index files), and reproduced the repaired cases. Its scanner SHA256 is `562c50685a1169774aa57dc6c918dc4c918122cb6f9c6dd28b617e8b9a401611`.

**Remaining counterexample:** `.env` contains `TYPESAFE_API_KEY="<opaque synthetic key>" # note`; a tracked file contains the bare synthetic key. `scripts/check-secrets.py:70` tests for matching outer quotes **before** stripping the comment, so the branch is skipped. `:73` then removes the comment but leaves the quotes in the needle; `:76` returns that incorrect needle. A key outside the shape regexes is missed and the checker prints OK, exit **0**. **Required:** parse supported quoted/unquoted values correctly, or reject unsupported syntax with exit 2. Add this quoted-plus-comment unknown-shape fixture. Merely saying unsupported syntax is forbidden while accepting it as a clean scan is not fail-closed.

The scanner's index coverage, self-scan, staged-then-deleted detection, oversized-file failure and harmless-prefix handling passed the supplied adversarial suite. Malformed-UTF-8 filename handling was **not exercised**: the attempted fixture did not enter the index. I do not label that a scanner pass or a demonstrated defect. Nor does a clean index scan prove that untracked files, all historical commits or arbitrary private screen data are secret-free; those are outside its declared scan surface.

**Risk arithmetic and effect confirmation.**

I parsed all 15 paired rows of `evidence/risk-gate-calibration.md:36–50`. The adopted `score≤0.20 AND confidence≥0.85` gate admits **15/15 benign** and refuses **15/15 destructive**. Score alone separates all 30 observations. Confidence alone would admit **erase all local data at 0.87**; 0.66 does not pass 0.85. The revised explanations at `SPEC.md:393–398` and the evidence file's `:60–75` are now true. The sample does not establish that confidence was necessary or that the new binding-specific prompt has the same calibration. These are arithmetic confirmations on supplied observations, not reruns of the original 30 experiments.

The inverse Choice values also check out: n=2 **0.925**, n=3 **0.900**, n=5 **0.880**, n=12 **0.8625**, n=24 **0.85625**, n=25 **0.856**, n=255 **0.850588…**. Non-blocking: the printed interval `[0.851,0.925]` is rounded, not an exact lower bound; “candidate-count independent” describes the chosen confidence threshold, not identical implied probability thresholds.

`SPEC.md:516–527` gives an adequate conservative outcome policy: setter read-back must equal the argument; toggle/radio value must change; other presses are unconfirmed. **Yes, most ordinary non-toggle button/menu presses can never become `applied` under this v1 policy.** They can still dispatch under approval, then return `unknownOutcome` without retry. That is an honest coverage limitation, not a readiness blocker for the stated scope. The phrase “no reliable predicate exists” should read “v1 defines no generic predicate”: application-specific focus, selection, menu or window transitions may be observable. An unreadable AXValue alone does not prove that no other postcondition can exist.

The late read-only survey (`evidence/ax-effect-predicate.md:5–29`, `evidence/axtoggle.swift`) observes values on several radios and absent menu-button AXValue. It demonstrates neither actual pre/post mutation confirmation nor universal checkbox support nor impossibility for all other roles. This reviewer ran `swift .atc/spec-review-v3/ax-trust.swift`: exit **0**, **AXIsProcessTrusted=false**. No live AX read/setter/press verification is claimed and no permission was changed.

**Other non-blocking precision.** SPEC's title still says v2; §5.5 still says `--approve` mints the token while §6.2 says `decide` writes it; §5.4 has stale “Noul only for applied” and “§5.2 rule 9” references; the low-confidence-none probe note disagrees with the composition's none-first ordering. SECURITY's “delete .env” removes a local copy, not an issued credential's server-side validity. The unchanged model-list wording and prior-art counts are not evidence for this verdict and were not re-audited as product claims. These cleanups should not delay the three substantive contract corrections.

**Evidence locations and verification limits.** Local `.atc/spec-review-v3/` contains `task.md`, preserved SPEC/scanner revisions, `required-check-results.json`, `latest-required-check-results.json`, `arithmetic.json`, `live-request.json`, `live-api.json`, `phase2-literal-api.json`, `checker-adversarial.py/json`, `checker-adversarial-latest.py/json`, `contract-witnesses.py/json`, `ax-trust.swift`, `ax-trust-result.txt`, and canonical documentation snapshots. Synthetic API requests went only to `api.typesafe.ai`; TypeSafe reference material came only from `docs.typesafe.ai`. API credentials were read in-process and not emitted. The Executor's source report is under `/Users/feral/mydev/jevscope/.atc/spec-review-v3/executor-evidence/`; its substantive findings were independently rerun. No production approval service, corpus transformer, metric evaluator or trace writer exists here to test end to end; that is expected at spec stage, not an additional blocker.
