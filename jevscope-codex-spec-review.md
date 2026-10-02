# Independent jevscope specification review

**Verdict: NOT_READY at commit `403849ac29bf719385b2086eb507baeade86343d`.** A revision landed during this review and corrected three initial blocking findings. The current fingerprint contract still permits wrong-target actions, and sections 5–11 still require the implementer to invent decision/approval policy, budget handling, and evaluation semantics. There are **seven remaining blocking findings: B3, B5, B6, B7, B8, B9, and B10**.

**Reviewed:** 2026-10-02; `/Users/feral/mydev/jevscope`. Initial review: commit `35018fc2bdc21f1c8863e0209ef04626e1287939`, SPEC.md lines 1–383. Final reviewed revision: `403849ac29bf719385b2086eb507baeade86343d`, SPEC.md lines 1–461. The checkout initially contained six tracked documentation/configuration/license files and no Swift package. Evidence files and then the correcting commit appeared while I was working. I read the final revision and its added probe sources; both versions are preserved in the review evidence directory. I did not edit or commit SPEC.md.

**Lens:** adversarial correctness at the decision-to-act boundary. A refusal must mean no mutation was dispatched; uniqueness must refer to the intended target, not merely whichever object occupies a path. A model probability is evidence for a decision, not proof of authorization or correctness. No autonomous loop, pixels, coordinate clicking, GUI, memory, or background agent is required by this review.

**Evidence location:** `.atc/spec-review/` in `/private/tmp/worktrees/prompt-1790983813565-74484-0`. It contains downloaded canonical documentation, request/response records from synthetic API probes, Swift compiler probes, relevant installed SDK headers, repository metadata, and the preserved late-arriving evidence. No API key was written into these review artifacts. API probes used synthetic states; the saved AX excerpts came from the supplied repository evidence. I did not perform any desktop mutation or grant Accessibility permission.

**Current-revision disposition — read this before the original detailed findings below.**

All unqualified line references in the detailed B1–B10 findings and original ledger refer to the **initial** 35018fc version, preserved as `.atc/spec-review/reviewed-SPEC.md`. The following references and decisions apply to **403849a**, preserved under `.atc/spec-review/revision-403849a/`.

| Finding | Current status | Current evidence and remaining required change |
|---|---|---|
| B1: reversed Noul | **Resolved** | `SPEC.md:253–257` now uses the correct polarity and gives 0.20/0.80 defaults. Question semantics and configuration validation remain part of B5, not a repeated polarity blocker. |
| B2: incorrect Score analysis | **Resolved** | `SPEC.md:229–240` defines the mode correctly and acknowledges the analysis error. Server-confidence gating is a valid choice; it still needs the policy in B5. §3 at lines 43–45 retains the old “docs are wrong” positioning and should be corrected editorially. |
| B3: target continuity/TOCTOU | **Still blocking** | `SPEC.md:314–321` adds role/subrole/identifier/title/description comparison. This detects the Archive-to-Delete label change in the first original example, but not same-label replacement, reused rows, a changed selection under an unchanged toolbar button, or change after the last check. Calling static stability a “sound identity guard” is unsupported. Specify retained snapshot-scoped bindings, operation-context preconditions, invalidation, and the residual-race limit. The new statement that v1 does not mutate real UI (`:320–321`) also contradicts `act` (`:404`); clarify whether it means the probe or the product. Dynamic fake fixtures require no real desktop mutation. |
| B4: action timeout as refusal | **Resolved for performAction** | `SPEC.md:324,340–350` now says at most once, no retry, and `unknownOutcome` distinct from refusal. Carry that state through the diagram/trace and the tests. Setter outcomes still need B6's explicit primitive contract. |
| B5: decision/approval/gates | **Still blocking** | `SPEC.md:249–265` has no Choice/Score threshold values or missing-config policy, exact questions, answer-composition rule, or semantic permission mapping. `:408–410` still has an unnamed execution flag and undefined approval flow. Supply the small versioned decision and authorization contract described in B5. |
| B6: setter versus action | **Still blocking** | `SPEC.md:133–141` still demonstrates value setting, while `:322–324` requires an offered named action. Enumerate primitives and distinguish settable attributes, replacement arguments, and dispatch outcomes. |
| B7: pruning/budget | **Partially addressed, still blocking** | `SPEC.md:361–368` now gives a ranking formula and K=24. Request token accounting, stable IDs, equal-name tie-breaking, exact goal matching, pruned-target handling, and overflow still need specification. The new evidence does not implement the same formula/filter; details below. |
| B8: AX errors/hermetic tests | **Partially addressed, still blocking** | `SPEC.md:306–309` now preserves absent enabled state. `:338` still refuses every non-success read, conflicting with optional missing metadata and `:451`'s skip-element rule. Define phase-specific errors, complete versus partial snapshots, and scripted fake-backend transitions/action counters. |
| B9: evaluation | **Still blocking** | `SPEC.md:414–435` still leaves metrics/oracles unspecified and requires identical live results including latency/date while using a moving model alias. Separate deterministic replay from pinned, measured live evaluation. |
| B10: artifacts | **Still blocking** | `SPEC.md:395,414–421,435,440–442`, SECURITY.md, and CONTRIBUTING.md retain the raw-content secrecy, committed-capture, unsafe secret-check, and storage-location conflicts. Reconcile the publication/export/redaction rules. |

Two new details matter for the current B5. First, Choice confidence is an affine normalization of `p_max`, not the same numeric threshold: with three options `p_max=0.8` gives confidence 0.7. `SPEC.md:251`'s equivalence shorthand must not carry old probability thresholds across unchanged. Second, “destructive questions raise hiT to 0.95” does not tighten acceptance of the **no** branch. If the question is “Is this destructive?” and no permits action, the relevant permissive boundary is loT, still 0.20. Define each proposition and its action mapping before describing a threshold as conservative. A server returning confidence also does not remove the need for an application-selected threshold, despite `:255`.

The current B7 evidence has concrete mismatches. `evidence/axrank.swift:60–67` accepts any nonempty name rather than at least three characters, and accepts a missing frame when enabled is true. Its scoring adds a ShowMenu bonus (`:79`) absent from the spec; the unconditional actionable bonus (`:74`) is ranking-neutral but also omitted. It uses substring-any matching (`:77`), which the spec's `goalTermMatch` does not define. Equal names remain tied (`:120–123`); the output actually contains multiple Delete buttons. `:127–128` estimates tokens from name length, role length, and a constant, divided by 3.5; it does not tokenize the final table or request. Thus the 163–485 “tokens” are estimates for a different approximation, and do not prove the budget can never bind (`SPEC.md:379–380`). A single unbounded label or goal is a counterexample. Align the probe and written filter, specify a final tie key and exact match rule, and enforce the full request budget. Use one defined coordinate system and display set for the geometry filter; AX positions are points, so the spec's `px²` unit also needs correction.

Name resolution and tri-state enabled rendering were corrected in 403849a; the corresponding original non-blocking recommendations below are closed. The 16-versus-17 AXError count, immutable-bytes instruction, and other unchanged observations remain. The original claims ledger records what was confirmed/refuted during review; it must not be read as claiming the corrected revision still has reversed Noul or a broken Score formula.

**Original detailed findings and reproducible evidence (35018fc baseline).**

**B1 — Blocking: Noul branches are backwards.**

Evidence: `SPEC.md:247` sends low `noul` to the yes branch and high `noul` to the no branch. TypeSafe defines the value as the probability of yes: low means no, high means yes. The two-sided refusal idea is sound; its polarity here is not. [Canonical Noul contract](https://docs.typesafe.ai/primitives/noul).

Independent live check: with state `The color is red.`, the API returned `0.98` for “Is the color red?” and `0.01` for “Is the color blue?”, with no confidence field. Both responses would be routed backwards by §6.3. Evidence: `.atc/spec-review/noul-choice.json`, HTTP 200, resolved model `jev-1.13.0`.

Required change: use `p <= loT => no`, `p >= hiT => yes`, otherwise refuse. Define the exact proposition each Noul evaluates and map that Boolean to the action policy explicitly; “yes to a danger question” must not become permission. Require finite configuration with `0 <= loT < 0.5 < hiT <= 1`, define boundary inclusivity, and supply defaults or refuse operation until thresholds are explicitly configured. Add fixtures at 0, 1, both boundaries, and inside the band.

**B2 — Blocking: the central Score-confidence discrepancy is a calculation error in the supplied evidence.**

Evidence: `SPEC.md:43–45`, `SPEC.md:226–248`, and `evidence/score-confidence-findings.md:14–20` claim that the documented formula fails by approximately 0.29. In the canonical formula, `m` is the **most likely level**, not the returned `score`, which is a probability-weighted mean. [Confidence formula](https://docs.typesafe.ai/confidence), [Score semantics](https://docs.typesafe.ai/primitives/score).

I recalculated all 24 samples in the newly supplied `evidence/score-confidence-samples.json`. Every stored `doc_formula` value exactly matches substituting the returned mean score for `m`. Using the actual modal level reduces the maximum discrepancy from **0.2867 to 0.0200**, and the mean discrepancy to **0.00833**. The residual is compatible with the two-decimal precision of the published probabilities and confidence; it does not establish a different server formula. This is an arithmetic check of the supplied data, independent of trusting the author's interpretation.

Concrete counterexample: `evidence/score-confidence-samples.json:68–78` has probabilities `[0.15, 0.12, 0.73]`, returned score `1.57`, and server confidence `0.36`. The mode is 2. The documented calculation is `max(0, 1 - (0.15*2 + 0.12*1)/(2/3)) = 0.37`. The recorded `0.0733` instead uses distances from `1.57`. Evidence: `.atc/spec-review/score-evidence-recalculation.json` records every recomputed row and the aggregate errors.

Independent live evidence also fits this correction: the canonical bug-report example returned probabilities `[0, 0.54, 0.46]` and confidence `0.31`, exactly the documented result. Eight additional synthetic requests produced maximum Score discrepancy 0.020 and Choice discrepancy 0.010 using the returned rounded values. Records: `score-doc-example.json` and `score-eight-samples.json` in the review evidence directory. I did not retrieve the original eight requests cited by the spec; these are separate measurements.

Computing a local statistic is legitimate, especially for a versioned reproducible gate. Rejecting the server statistic as empirically disproven is not supported by this evidence. Neither statistic guarantees that the chosen action is correct. A peaked distribution over the wrong alternatives can still be confidently wrong.

Required change: correct the empirical claim and the evidence calculation; define `m = argmax_i p_i`, including a tie rule and the ordered level mapping. Specify the actual Score threshold and how the scored quantity affects action eligibility. Remove or clarify “expected-value distance” at `SPEC.md:248`, which currently invites the same mean-versus-mode error. Add the concrete example above as a regression fixture. Keeping a local MAD calculation is an acceptable deliberate policy, without claiming to have corrected a broken server formula.

**B3 — Blocking: Invariant A permits substitution of the wrong target; revalidation does not close TOCTOU.**

Evidence: `SPEC.md:263–267` makes the index path the machine key. `SPEC.md:282–300` requires only snapshot-map membership, same app/launch, unchanged role, enabled state, and supported action. Invariant A at `SPEC.md:302–303` establishes a cardinality property, not continuity of identity or correctness of the selected object.

Counterexample that passes every stated check:

1. The snapshot maps handle 07 to `/3/1/0`, an enabled Archive button offering press.
2. During the API request, the app replaces or reorders that subtree. `/3/1/0` now names an enabled Delete button offering press, in the same app launch.
3. Resolution finds one handle and one element. Role is still `AXButton`; enabled and offered action pass. No specified refusal applies. Delete is pressed.

If the implementation retains the original `AXUIElement` instead of re-traversing the index path, that removes this particular substitution but not all stale-context cases. A virtualized row can reuse a control object for another document; an unchanged toolbar Delete button can act on a newly selected item. Role, label, identifier, and even object identity can all remain unchanged while the operation's subject changes. Rechecking those fields immediately before act still leaves a race before the target application processes the request. AX does not provide a transaction combining the proposed snapshot checks with the target app's action.

The new `evidence/ax-fingerprint-stability.txt` does not establish mutation detection: it explicitly measures static UI. `evidence/axfingerprint.swift:94–99` rereads retained elements without inducing replacement or selection changes. Zero drift under no change is useful noise evidence, not proof that a fingerprint detects identity loss.

There is also no atomic capture operation in the proposed walk. A pure value snapshot is frozen after construction, but sequential AX reads can combine attributes or children observed before and after a UI change. Define capture invalidation and completeness instead of treating the word “snapshot” as proof of a coherent point in time. Finally, `ambiguousName` implies an unspecified fallback even though step 1 declares the exact snapshot map authoritative; a unique name match is not permission to substitute a different target.

Required change: bind each decision to a unique snapshot generation, application launch identity, window/context, immutable candidate map, and retained backend target reference. Never rebind an expired handle by ordinal, path, or unique name. Specify what contextual preconditions make each supported action meaningful, how they are revalidated, when the binding expires, and which refusal represents their loss. Test same-role replacement, row reuse, selection change, app restart, out-of-order responses, and stale approval.

The guarantee must also be honest about the residual check-to-use race. If “no path to a wrong action” is an unconditional requirement, generic live `act` is not justified by these checks: keep that command non-executing in v1 unless an action-specific mechanism can enforce the necessary preconditions. Do not present another fingerprint or a short TTL as an atomicity guarantee.

**B4 — Blocking: an AX action error is not necessarily a no-action refusal.**

Evidence: `SPEC.md:211` has only `.act()` or `.refuse(reason)`. `SPEC.md:300` turns every AX failure, including `cannotComplete`, into refusal; `SPEC.md:355` associates refusal with no AX action. The installed Apple SDK's `AXUIElement.h:315–328` explicitly explains that `AXUIElementPerformAction` may time out while the target is doing modal processing and that this does not necessarily mean the action failed. The header is copied into the review evidence directory.

Example: a press starts a modal operation, then returns `cannotComplete`. Reporting that as “refused, no action” is false. Retrying can perform an operation twice. The risk table's “skip-element” instruction at `SPEC.md:373` is especially inappropriate after a mutation has been sent.

Required change: separate pre-dispatch refusal, dispatched operation with reported success, and execution outcome unknown. Record whether dispatch occurred. Specify no automatic retry of a dispatched mutation on timeout or uncertain transport failure; a repeated command must not silently reuse the old approval. Keep Jev HTTP retries separate from actuator retries. Add a fake-backend case that records a mutation and then returns `cannotComplete`; it must never produce a no-action refusal or a second dispatch.

**B5 — Blocking: the decision, gate, and approval contracts are missing.**

Evidence: §3 promises a versioned Jev question contract (`SPEC.md:38–39`), but §§5–11 contain no concrete request, question text, operation vocabulary, decision schema, or rule composing Choice/Noul/Score answers. `SPEC.md:246–250` names configurable thresholds without values or required-configuration behavior. `SPEC.md:331–332` introduces a default dry run, an unnamed execution flag, and `approval_required`, which is absent from §7.3's public refusal taxonomy.

An implementer must currently decide whether operation and target are independent questions, whether every used answer must pass its gate, what “no applicable action” means, how text arguments originate, and what authorizes a side effect. Independent operation and target answers can describe an invalid pair; API schema validation alone does not establish their semantic compatibility. For Choice, gating on the maximum probability but executing a different `choice` would also be unsafe unless their consistency is checked.

The return type being Codable is insufficient validation. The spec needs behavior for missing/wrong-type answers, missing/extra probability keys, non-finite or out-of-range numbers, bad sums within a stated rounding tolerance, absent candidates, and ties. Errors must not default to zero, a first option, a guessed handle, or success. A single remaining candidate needs a genuine no-action alternative, not automatic certainty from a forced choice.

Desktop text is untrusted decision input. A page label or document can contain instructions to select another legitimate action; exact handle resolution does not stop that. TypeSafe itself documents susceptibility to adversarial state. This is relevant to the claimed fail-closed contract, not a request to build a new security subsystem. [Canonical model limitations](https://docs.typesafe.ai/model-jaggedness/jev-1.13).

Required change: add one complete, versioned request/response-to-decision contract, bounded operation/argument schema, explicit no-action choice, and deterministic composition/validation rules. Specify thresholds or refuse absent configuration; define all inclusivity and tie behavior. Choose exactly how `act` opts into execution and how approval binds to the precise operation, target, arguments, and snapshot. State which operations v1 permits and how authorization is established independently of untrusted screen text. These can be small tables and examples; no agent loop is necessary.

**B6 — Blocking: the actuator's action-name check cannot implement the proposed text entry.**

Evidence: `SPEC.md:133–141` correctly demonstrates text replacement via `AXUIElementSetAttributeValue`. But `SPEC.md:285–286` requires every action to appear in `AXUIElementCopyActionNames`, and `SPEC.md:316` describes only role/action checking and performing. Writable attributes and named AX actions are different capabilities. `AXUIElement.h:283–286` documents the latter; attribute setters have their own API and capability checks.

The spec also does not distinguish replacing a field's entire value from insertion, appending, or submitting. Safari address-bar set/read/restore, even if verified, establishes neither arbitrary text-control support nor a safe submit operation. A single action command must not accidentally become replace-plus-submit because the implementer inferred “typing.”

Required change: enumerate v1 primitives. Separate `performAction` from `setValue` if both are supported, with an exact action-name mapping, `AXUIElementIsAttributeSettable` for setters, target type/value checks, and explicit argument origin and replacement semantics. Otherwise restrict v1 to a specified subset and explicitly exclude text entry. Do not infer setters from the action-name list or add a CGEvent fallback.

**B7 — Blocking: the budget is a number without a budgeting or selection algorithm.**

Evidence: `SPEC.md:107–108` says 28,000 input tokens and rank-and-prune; `SPEC.md:339–340` sweeps approximately 4/12/24 candidates. No ranking function, tokenizer/upper bound, stable ordering, tie-breaker, context retention, or interaction between the two limits is specified. The missing ranking function directly determines whether the intended target reaches the model and changes the evaluation being claimed.

Canonical limits are two-dimensional: 32k for state plus the longest question, and 64k for state plus all questions. A conservative 28k limit on the entire accounted request is reasonable; a 28k table alone is not a defined request budget. Goal, instructions, criteria, duplicated candidate descriptions, encoding, and model framing must be accounted for. Choice also has a maximum of 255 options. [Model limits](https://docs.typesafe.ai/models), [Choice contract](https://docs.typesafe.ai/primitives/choice).

My synthetic probe accepted a response-reported 28,309 input tokens and rejected the larger request with HTTP 400 `max_tokens_exceeded`. That confirms the error shape and a broadly compatible ceiling, not the exact original 799/800 boundary. Evidence: `.atc/spec-review/token-probes.json`. The new table evidence's approximate token counts are explicitly `String.count / 3.5` estimates (`evidence/axtable.swift:83–87`), not a verified tokenizer or a conservative bound, particularly for arbitrary Unicode labels.

Pruning also interacts with identity. If ordinals are regenerated after pruning or between the 4/12/24 sweeps, the corpus's expected target handle can silently change meaning. If the correct target is pruned away, selecting a unique remaining element is still a wrong action. The table grammar currently does not define escaping of labels containing quotes, newlines, pipes, or fake numbered rows; these can corrupt the model-facing representation without affecting the underlying map.

Required change: specify one deterministic candidate eligibility/ranking rule, stable tie-breaker, exact candidate caps, and preservation of snapshot-scoped IDs. Define the token counter or conservative bound, every included request component, fixed-overhead overflow behavior, and final serialized-budget check. Define escaping and retained parent/window context. Record excluded candidates and pruning reasons; provide a no-target/no-action route and score target-pruned cases explicitly. Fail closed on unresolved budget exhaustion. No learned ranking system is required.

**B8 — Blocking: AX error policy contradicts itself, and the fixtures do not yet specify the dangerous paths.**

Evidence: `SPEC.md:260–262` expects missing optional identifiers. `SPEC.md:300` refuses on any non-success AX call. `SPEC.md:373` instead skips elements on `cannotComplete`; `SECURITY.md:40` forbids acting on an empty or truncated tree. These are incompatible without a phase-specific distinction between normal absent metadata and incomplete perception. Successful API status with an unexpected Core Foundation type is another missing case.

If an optional identifier returns `noValue`, must the entire run refuse? If a child enumeration fails, may the remaining partial tree still produce an action? If an enabled attribute is absent, is that false, unknown, or not applicable? A fail-open coercion of unknown to true is dangerous; an unconditional false can silently exclude valid operations and distort the corpus. The late probe demonstrates why this matters: `evidence/axtable.swift:16–19` collapses attribute-read failure to false, and `:65` prints it as disabled. That probe should not become the production semantics.

`AXBackend` plus a stub client can make the core hermetic; nothing in §4.8 makes that architecture impossible. However, a frozen snapshot alone cannot exercise the live rereads, capability changes, wrong CF types, or action-that-timed-out-after-dispatch in B3/B4. `SPEC.md:217–218` overstates what follows merely from declaring a protocol. §10 names the necessary stub client, but neither the backend contract nor the fixture behavior is given. Raw `AXUIElement` ownership, Swift 6 isolation, and error conversion must stay inside the production adapter so fixture tests need no real AX calls.

Required change: define a small normalized backend contract and phase/error table: optional absence, malformed data, essential read failure, incomplete enumeration, preflight failure, and post-dispatch failure. Track snapshot completeness and traversal limits/cycles. Define scripted fake-backend transitions and an action log/counter, along with injected client responses. All refusal tests must assert zero dispatched mutations; unknown-outcome tests must assert exactly one. Keep compiler/AX adapter smoke tests separate from offline tests. This is a contract clarification, not a demand that the unfinished project already contain code.

**B9 — Blocking: the reproducible evaluation acceptance criterion is internally inconsistent.**

Evidence: `SPEC.md:336–343` promises a versioned corpus, candidate-count sweeps, accuracy, refusal precision, false-act rate, p50/p95 latency, date, model version, and corpus hash. `SPEC.md:356` then requires two live `eval` runs to produce identical results. Real latency varies; timestamps vary; `jev-latest` can change. Logging a resolved model version diagnoses change but does not pin it. Even one pinned model is not a promise of identical live responses. [Model versioning](https://docs.typesafe.ai/models).

The fixed app-capture script, snapshot/case schema, corpus coverage, question version, and metric denominators are not specified. “False-act rate” could mean wrong actions divided by all cases or wrong actions divided by acted cases, with materially different values. Refusal precision needs positive/refusal labels and a defined zero-denominator result. Accuracy must say whether operation, target, and arguments must all match; candidate pruning needs separate treatment. Multiple valid targets and expected refusals also need an explicit oracle policy. A refusal-only system must not appear to win by hiding coverage.

The live low-confidence test at `SPEC.md:355` is nondeterministic and does not establish no action without an observable action counter. The public error taxonomy also needs precedence when multiple conditions hold, or an expected single refusal code cannot be reproduced across implementations.

Required change: distinguish deterministic offline replay from live model evaluation. Require identical normalized decisions/refusals in replay; report and compare measured latency separately. Pin the live model ID, question/serialization/ranking versions, thresholds, corpus hash, candidate ordering, and repetition policy. Supply a case schema, capture procedure/app versions, metric equations and denominators, and a small enumerated acceptance matrix including the counterexamples in this review. Replace the stochastic refusal smoke with a injected low-confidence fixture. Define refusal precedence or assert an explicitly allowed set.

**B10 — Blocking for publishing the harness: artifact and secrecy rules conflict.**

Evidence:

- `SPEC.md:336–343` requires committed real AX snapshots and `results/results.json`; `CONTRIBUTING.md:22–23` says never commit captured trees.
- `SPEC.md:363–364` excludes writing outside Application Support, while the corpus/results paths are repository-relative unless an exception is specified.
- `SPEC.md:213,317` promises secret-free traces; `SECURITY.md:24–32` says traces contain request/response bodies and that request bodies contain window titles, labels, and text-field values. Keeping headers out protects the transport key, not secrets present in UI content or goals.
- `SPEC.md:357` proposes a shell-expanded `git grep` of `.env` values. It is not a safe or complete leakage test: multiple values become arguments or paths, regex metacharacters change matching, a match prints the secret, the key can enter the process argument list, and UI secrets have no such inventory.

Required change: distinguish raw captures/traces from reviewed, sanitized public corpus fixtures; explicitly authorize only the latter for version control. State where runtime files live and how a deliberate results/corpus export works. Define trace fields and redaction/omission behavior, or narrow the secret-free claim to what is actually guaranteed while keeping sensitive raw artifacts private. Replace the displayed grep command with a check that neither prints secrets nor expands them into command-line arguments. This asks the spec to reconcile its own promises, not to add pixel processing or a new product feature.

**Non-blocking corrections and precision improvements.**

- `SPEC.md:129` names the wrong Swift helper. `AXValueGetValue` writes through a mutable pointer. `withUnsafeBytes(of:)` fails to typecheck because it supplies an immutable pointer; `withUnsafeMutableBytes(of: &value)` works, as does passing `&value` directly for the duration of the call. Both working forms were executed successfully on a local synthetic CGPoint. The late repo probes already use the mutable form. Evidence: `compiler-probes.json`, `ax-probe.swift`, `ax-probe-result.json`; installed `AXValue.h:119`.
- `SPEC.md:126` says 17 AXError cases; the installed `AXError.h:32–79` contains 16 named cases. The important claims that `AXError` is not Swift `Error`, that `kAXErrorSuccess` is not a Swift global, and that a static CFString triggers Swift 6 concurrency checking were confirmed by compiler diagnostics. Correct the count without making tests depend on it.
- `SPEC.md:258–271` conflates identity and display naming. Identifier-first display defeats the stated tie-breaker-only intent; the supplied table shows `_NS:61` in place of a human label. Preserve identifiers separately from display names. The new four-app data reports identifiers on 59–74% of nodes, contradicting “near-zero recall” as a description of those measurements, though it does not prove useful uniqueness or stability. I could inspect the probe mechanism but could not independently rerun its successful live reads under this process's denied AX permission.
- `SPEC.md:263–267` treats readable handles as a model requirement. With a closed Choice, an opaque stable option key plus a descriptive value is viable; free-form path hallucination is not inevitable. This is not a demand to change the chosen handle style. It is a reason to remove the unsupported “only vocabulary” claim and precisely define ordinal scope, formatting, escaping, and collision handling. [Canonical Choice request contract](https://docs.typesafe.ai/primitives/choice).
- `SPEC.md:107` leaves 4,850 tokens below 32,850: 14.76% of that ceiling, or 17.32% of the 28,000 budget. “More than 15% headroom” needs its denominator specified. The number 28,000 is not itself a blocker; the missing accounting and pruning rules are.
- `SPEC.md:323,353` declares `--app <bundleID>` but tests `--app Finder`; CONTRIBUTING similarly uses Safari. Use `com.apple.finder`/`com.apple.Safari`, or define name lookup and ambiguous-name behavior. Use a runnable binary path or document installation. A pipe to `head` is inspection, not proof of complete capture.
- `SPEC.md:112–114` has useful latency observations, not a latency bound or throughput study. Missing sample count, warm/cold conditions, request body, concurrency and percentile definition limit the conclusion. Treat them as observations; do not use them as the stale-snapshot timeout policy.
- The `JevCore` name at `SPEC.md:217` and the AXKit sample manifest at `:169–179` do not match the module list at `:309–318`. Choose the production target layout when clarifying the test seam; a historical proof-of-concept manifest is fine if labeled as such.
- `SECURITY.md:12–14` conflates the TypeSafe key with local Accessibility control. Possession of the remote API credential does not itself grant macOS TCC permission. Separate those two authorities.

**Claim verification ledger.**

| Claim | Disposition and evidence |
|---|---|
| Jev accepts text, not image/audio/video inputs | Confirmed in canonical [System One docs](https://docs.typesafe.ai/concepts/system-one). No pixels is a coherent v1 constraint; AX-only is this project's chosen text source. |
| Official SDKs are Python and JS/TS | Confirmed current documented list at [SDKs](https://docs.typesafe.ai/sdk); no Swift SDK is listed. This is not proof that no unofficial SDK exists. |
| One documented current model; request-based domain adaptation | Confirmed at [Models](https://docs.typesafe.ai/models); no per-account fine-tuning is offered there. |
| `/v1/models` lists latest/preview aliases and calls resolve to `jev-1.13.0` | Independently confirmed live, HTTP 200. `models.json`, `noul-choice.json`, and Score probe records. Release dates match to the displayed second. |
| HTTP 400 `max_tokens_exceeded` exists and is omitted from the main API error table | Independently confirmed live; canonical [API reference](https://docs.typesafe.ai/api) lists 401/422/429/529. `token-probes.json`, cached `api.md`. |
| Original 799/800-element, 32,850/32,891-token boundary | Not independently reproduced: original request generator and those responses are absent from the inspected evidence. My 28,309-token request succeeded and larger synthetic request failed. Do not mislabel that as the same bisection. |
| Choice confidence follows the documented normalization | Broadly confirmed on live probes, within 0.010 using rounded returned probabilities. The original eight-sample maximum of 0.005 is not independently verified or refuted by a different sample. |
| Noul has no separate confidence field | Independently confirmed live and in canonical docs. |
| Low Noul is yes, high Noul is no | Refuted by both canonical docs and live truth/falsehood probes. B1. |
| Supplied Score samples show a ~0.29 failure of the documented formula | Refuted as an analysis of the supplied 24 rows: every stored formula uses the mean, not the mode. Correct recalculation has max error 0.020. Original eight-sample inputs remain unavailable. B2. |
| macOS 27.0.1, arm64, Swift 6.4 | Confirmed by `sw_vers` and `swift --version`. |
| AXError does not conform to Error; static CFString fails strict concurrency; no Swift kAXErrorSuccess or kAXFrameAttribute | Confirmed by `swiftc -swift-version 6 -typecheck` probes, each with the expected diagnostic. |
| AXError has 17 cases | Refuted by installed header: 16 named cases. |
| AXValueGetValue needs withUnsafeBytes | Refuted: immutable bytes fail compilation, mutable bytes and direct inout succeed. |
| AX coordinates use top-left origin | Confirmed by installed `AXAttributeConstants.h:609–616`; units are points. No coordinate clicking was tested or requested. |
| Successful live AX reads off the main thread | Not independently confirmed. Probe compiled and ran off-main, but `AXIsProcessTrusted()` was false and the read returned -25211 (`apiDisabled`). This does not disprove success under the author's separately trusted process. |
| Accessibility permission is already granted “here” | Not true for this reviewer process. TCC context matters; original process's permission cannot be inferred. No permission was requested or changed. |
| Safari set/read/restore; selected-text writability; observer PID behavior; array-cast crash; AppKit label mapping; role/notification counts | Not independently runtime-verified. SDK shape/probe source supports parts of the implementation approach, but the original successful/crashing runs are not available as reproducible evidence here. I did not alter Safari to recreate them. |
| Sample Package.swift builds with six passing tests | Unverifiable as a full package: no manifest or test sources are present. `swift test` in the requested repo exits 1: “Could not find Package.swift”. Missing implementation is expected at spec stage and is not itself a blocker. |
| Identifier “near-zero recall” | In conflict with supplied newer four-app observations (59–74% identifier presence). Those observations do not establish stable identity; independent AX replication was unavailable. |
| Static fingerprints prove safe target continuity | Not established. The supplied probe measures repeated unchanged UI, not replacement, reuse, or context changes. |
| Six prior-art projects, star counts, universal claims about their gating, and cited research percentages | Not audited in this review; these are not used to justify the readiness verdict. “Every existing project” is unsupported by the evidence inspected. |

**Verification performed and limits.**

`git status --short`, `git log -5 --oneline`, `git diff`, and `git ls-files` established the reviewed baseline and the later untracked evidence. The spec itself was not edited. `swift test` exited 1 because no package exists. Compiler probes exited 1 for the intentionally invalid examples; the corrected standalone AX/CGPoint probe compiled and ran with exit 0. Its local AXValue tests passed; its live AX read was denied, not successful.

I made only synthetic, bounded requests to `https://api.typesafe.ai`, reading the configured key without printing it. Model listing and small decision requests returned HTTP 200; the oversized request returned HTTP 400 with the expected error. All TypeSafe assertions in this review use `docs.typesafe.ai` or `api.typesafe.ai`; no lookalike domains were used.

For the final reviewed 403849a revision, B1/B2 and the performAction part of B4 are corrected. The remaining work is the seven active contracts identified in the current-revision table. A pure decision harness cannot establish the safety of the exposed live `act` command.
