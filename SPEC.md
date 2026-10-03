# jevscope — SPEC v2

**Status:** draft, second revision. Addresses all seven blockers from the Codex
review of v1 (`jevscope-codex-spec-review.md`, verdict `NOT_READY` at `403849a`).
**Date:** 2026-10-02
**Repo:** `Gonzih/jevscope` (public)

---

## 0. What changed from v1, and why

| # | v1 said | v2 says | Why |
|---|---|---|---|
| B3 | Re-verify by attribute fingerprint, call it a "sound identity guard" | **No generic execution.** `apply` requires an approval token bound to one decision + snapshot generation, and an allowlisted primitive. The residual check-to-use race is disclosed, not papered over. | AX offers no transaction combining snapshot checks with the target app's action. No fingerprint closes it. |
| B4 | `axError` → refusal | Tri-state outcome: `refused` (nothing dispatched), `applied` (dispatched, confirmed), `unknownOutcome` (dispatched, unconfirmed) | `AXUIElementPerformAction` may time out *after* taking effect |
| B5 | "configurable thresholds", no questions, no schema | **§5** is the complete versioned contract: exact questions, operation vocabulary, composition, validation, thresholds, approval | An implementer was being asked to invent safety policy |
| B6 | Value-set and action conflated | **§6** enumerates primitives; `performAction` and `setValue` are separate capabilities | Writable attributes ≠ named actions |
| B7 | 28k token budget, hand-wave ranking | **§7** gives one deterministic ranking, a **byte-based** budget, escaping, stable IDs, pruned-target handling | Tokens were unaccounted; ranking decided the result |
| B8 | Refuse on any non-success read | **§8** phase-specific error table; completeness tracking; fake-backend contract | Contradicted optional-metadata handling |
| B9 | Two live `eval` runs must be identical | **§9** separates deterministic offline replay from pinned live evaluation | Latency, timestamps and `jev-latest` all vary |
| B10 | Committed captures + "secret-free traces" | **§10** separates raw (private) from sanitized (public); redaction rules; non-disclosing secret check | The spec contradicted itself |

---

## 1. Problem

There is no reproducible, openly specified way to answer: **how well does
TypeSafe Jev decide macOS actions from the raw Accessibility tree?** Every
published Jev computer-use project ships an agent and an author-reported number.
None ships a harness a third party can run.

## 2. Prior art — stated plainly

The concept is **not novel**.

| Project | Lang / license | Perception | Jev role |
|---|---|---|---|
| [savka777/jev-use](https://github.com/savka777/jev-use) | Swift, MIT | macOS AX tree only | operation + target |
| [awlevin/typesafe-computer-use](https://github.com/awlevin/typesafe-computer-use) | Python, MIT, 1144★ | Vision OCR ⊕ AX | 3 Choices/step |
| [jcpsimmons/jev-macos-loop](https://github.com/jcpsimmons/jev-macos-loop) | JS+Swift, AGPL-3.0 | ScreenCaptureKit + OmniParser ⊕ AX | finite choice |
| [paulsmith/computer-use-jev](https://github.com/paulsmith/computer-use-jev) | Go + Swift worker, MIT | AX tree only | action/target/done/needs-text |
| [Eronmmer/jev-cua](https://github.com/Eronmmer/jev-cua) | TypeScript, AGPL | AX first, approved fallback | workflow router |
| [trycua/cua `jev-use`](https://github.com/trycua/cua/tree/main/libs/cua-driver/examples/jev-use) | Python + TS | macOS AX / Win UIA / Linux AT-SPI | capped candidate choice |

`savka777/jev-use` is a Swift macOS app whose README describes the naive version
of this project almost clause-for-clause. **We do not claim to be first.**

Our differentiator: an open spec, a reproducible harness, verified confidence
semantics, and an honest account of what the AX API cannot guarantee.

## 3. Scope of v1

**In:** observe the AX tree; rank candidates; ask Jev typed questions; gate the
answer; emit a decision; execute a **narrow allowlist** of primitives under an
explicit approval token; evaluate against a committed corpus.

**Out:** autonomous multi-step loops; screenshots/OCR/pixels; coordinate
clicking; CGEvent synthesis; submit/send/delete/purchase; a GUI.

## 4. Verified constraints

Measured on this machine, 2026-10-02. Evidence under `evidence/`.

### 4.1 Jev is text-only
> "Jev currently accepts text input only… Images, audio, and video are not
> supported (yet)." — [docs.typesafe.ai/concepts/system-one](https://docs.typesafe.ai/concepts/system-one)

Pixels never leave the machine. The AX tree is the entire perception layer.

### 4.2 No official Swift SDK
Official SDKs are Python `typesafe-sdk` and `@typesafe-ai/sdk`. **UNVERIFIED:**
the complete official list — `/sdk` was not enumerated directly. A hand-written
`URLSession` client is required and is the right call anyway.

### 4.3 No Domain-Specific Models
`/models` lists one model, `jev-1.13.0`, with aliases `jev-latest` and
`jev-preview`. No UI/computer-use model exists.

### 4.4 Confidence — verified live
| Primitive | Formula | Status |
|---|---|---|
| Choice | `(p_max − 1/n)/(1 − 1/n)` | confirmed, max err **0.005** (8 samples) |
| Score | `max(0, 1 − Σ p_i·\|i − argmax(p)\| / MAD_unif)` | confirmed, max err **0.020** (24 samples) |
| Noul | **no field returned**; `noul` is P(yes) | verified 6/6, incl. negative polarity |

> **Correction.** v1 claimed the Score formula did not reproduce. That was an
> **error in the analysis** — `m` is the *modal* level, not the returned mean
> `score`. Codex found it; recalculated max error is 0.020.
> See `evidence/score-confidence-findings.md`.

> **Threshold trap.** Choice confidence is an **affine normalization** of
> `p_max`, not `p_max`. With 3 options, `p_max = 0.8` → confidence **0.7**.
> A threshold is not interchangeable between the two. jevscope gates on
> `confidence` and never substitutes a probability threshold for it.

### 4.5 Undocumented error: HTTP 400 `max_tokens_exceeded`
Docs list 401/422/429/529. The live API also returns
`{"detail":{"error_type":"max_tokens_exceeded"}}`. Treated as a first-class,
non-retryable budget error.

### 4.6 Input ceiling ≈ 32.8k tokens
799 synthetic elements → 32,850 tokens (HTTP 200); 800 → 32,891 (HTTP 400).
**UNVERIFIED as an exact boundary** — codex independently confirmed the error
shape and a broadly compatible ceiling, not this exact edge.

### 4.7 Latency — observations, not bounds
189 ms @ 10 elements · 325 ms @ 50 · 270 ms @ 100 · 407 ms @ 200 · 397 ms @ 400.
Single samples, no percentile discipline, no concurrency study. **These are not
a timeout policy** and are not used as one.

### 4.8 macOS AX contract — compile- and runtime-verified
Accessibility permission is granted on this machine, so these are
runtime-verified. Swift 6.4, macOS 27.0.1, arm64.

**Working API shape**
- `AXUIElementCreateApplication(pid_t)`, `NSWorkspace.shared.frontmostApplication`
  (`.activeApplication` deprecated).
- All `kAX*` constants are **`String`** in Swift 6 — every call site needs
  `as CFString`.
- `AXError` is a Swift enum with **16** named cases (`AXError.h:32–79`). There
  are **no `kAXError*` globals**, and `AXError` does **not** conform to `Error`,
  so `Result<_, AXError>` does not compile.
- `AXValueGetValue` writes through a **mutable** pointer: use
  `withUnsafeMutableBytes(of: &value)` or pass `&value` directly.
  `withUnsafeBytes(of:)` does **not** typecheck.
- AX coordinates are top-left-origin screen space, not flipped Quartz.
- AX calls work off the main thread.
- `AXUIElementSetMessagingTimeout`: a **positive** value on the **system-wide**
  element sets the process-wide timeout; `0` on system-wide *resets to default*.
- `AXObserverCreate` requires the **target app's pid** — not your own, not
  `0`/`-1` (those return `.illegalArgument`, −25201).

**Gotchas confirmed by compiler diagnostics**
- `String` does **not** bridge to a `CFString` parameter.
- A `static let` holding a `CFString` is a Swift 6 concurrency error.
- `kAXTrustedCheckOptionPrompt` is a non-`Sendable` global `var`.
- `kAXFrameAttribute` does **not** exist; use `kAXPosition` + `kAXSize`.
- `AXMakeProcessTrusted` is unavailable in Swift.
- `CFArrayGetValueAtIndex` + `load(as:)` **segfaults** (exit 139). Safe path:
  bridge `CFArray` → `NSArray`, check `CFGetTypeID(obj) == AXUIElementGetTypeID()`
  (live value 77), then `unsafeDowncast`.
- ApplicationServices is **not** re-exported; every target naming `AXUIElement`
  must import it.

**Verified `Package.swift`** (builds clean, dumps a live AX tree off-main-thread):

```swift
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "jevscope",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AXKit", targets: ["AXKit"]),
        .executable(name: "jevscope", targets: ["jevscope"]),
    ],
    targets: [
        .target(name: "AXKit", swiftSettings: [.swiftLanguageMode(.v6)],
                linkerSettings: [.linkedFramework("ApplicationServices"),
                                 .linkedFramework("AppKit")]),
        .executableTarget(name: "jevscope", dependencies: ["AXKit"],
                swiftSettings: [.swiftLanguageMode(.v6)],
                linkerSettings: [.linkedFramework("ApplicationServices"),
                                 .linkedFramework("AppKit")]),
        .testTarget(name: "AXKitTests", dependencies: ["AXKit"],
                swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
```

### 4.9 Action timeouts are not failures
> "…they may not return within the timeout value… **This does not necessarily
> mean that the function has failed**, however. If appropriate, your assistive
> application can try to call this function again."
> — `AXUIElement.h:317–320`

Apple's suggested retry is unsafe for mutations: a retried press can execute
twice. See §6.4.

---

## 5. Decision contract — `jevscope decide v1` (versioned, complete)

### 5.1 Request

One `POST /v1/systemone`, `model: "jev-latest"`. Exactly four questions, asked
together:

```json
{
  "model": "jev-latest",
  "state": { "application": "...", "frontWindow": "...", "elements": [...] },
  "questions": {
    "operation": { "type": "choice", "instructions": "...", "criteria": {...} },
    "target":    { "type": "choice", "instructions": "...", "criteria": {...} },
    "risk":      { "type": "score",  "instructions": "...", "criteria": [...] },
    "applied":   { "type": "noul",   "instructions": "...", "criteria": {...} }
  }
}
```

**Operation vocabulary** (`criteria` keys) — a closed set. No free text:
`press` · `setValue` · `none`.

**Target criteria** — one option per candidate handle, value
`"<role> \"<name>\" <actions>"`, plus a mandatory `none` option. Cap **24**
(§7). A `choice` answer whose `probabilities` keys do not exactly equal the
criteria keys is a hard error (§8).

**Questions**
| Key | Type | Asks |
|---|---|---|
| `operation` | choice | which single operation advances the goal, or `none` |
| `target` | choice | which element the operation targets, or `none` |
| `risk` | score | irreversibility of the selected operation, 3 levels `["reversible","hard to reverse","irreversible"]` |
| `applied` | noul | "has the requested outcome already been reached?" |

All four share one `state`; screen text is **data**, and every instruction says
so explicitly.

### 5.2 Answer validation (all must hold, else `invalidAnswer`)
1. Every question key present; every answer's `type` matches its question.
2. `probabilities` keys **exactly** equal the `criteria` keys.
3. Every probability finite and in `[0,1]`; sum within **0.02** of 1.
4. `choice` is a member of `probabilities`.
5. `confidence` finite and in `[0,1]` (Choice, Score only).
6. `noul` finite and in `[0,1]`.
7. Any tie in `probabilities` is a **hard error**, never an arbitrary pick.

Errors **never** default to zero, the first option, a guessed handle, or success.

### 5.3 Composition → Decision

```
no_action   if operation == "none"                    -> Decision(action: .none)
no_action   if target    == "none"                    -> Decision(action: .none)
refused     if operation confidence < 0.85            -> lowConfidence
refused     if target    confidence < 0.85            -> lowConfidence
refused     if target.handle is not a candidate in THIS snapshot
                                                    -> unknownHandle
refused     unless risk.score <= 0.20 AND risk.confidence >= 0.85
                                                    -> approvalRequired
decision    otherwise, bound to (snapshotGeneration, appLaunchID,
             handle, arguments, thresholds)
```

`operation` and `target` are **not** independent: after both gates pass, the
pair is validated against the primitive table in §6.1. An invalid pair is
`unsupportedAction`, never dispatched. When `operation` is `none` the `target`
question is still asked (one round trip) and its answer is ignored.

### 5.4 Thresholds

Finite configuration required, with `0 ≤ loT < 0.5 < hiT ≤ 1`; boundaries are
**inclusive**: `noul ≥ hiT` ⇒ yes, `noul ≤ loT` ⇒ no, otherwise `ambiguousNoul`.
Defaults: `operationConfidence 0.85`, `targetConfidence 0.85`,
`riskScoreMax 0.20`, `riskConfidenceMin 0.85`, `noulLoT 0.20`, `noulHiT 0.80`.

The `applied` Noul gates **completion**, not permission: `applied ≥ 0.80` ⇒
`Decision(action: .alreadyDone)`, `applied ≤ 0.20` ⇒ proceed, else
`ambiguousNoul`. Because raising `hiT` for a dangerous question does not tighten
the permissive *no* branch, the destructive boundary is enforced by the `risk`
**Score**, not by Noul thresholds.

**Measured risk gate (`evidence/risk-gate-calibration.md`).** An earlier draft
gated risk as `score >= 2` or `score == 1 && confidence < 0.90`. That rule has a
hole: a score of **1.23 satisfies neither clause**. Measured on 15 benign and 15
destructive goals, "delete the selected file" scores **1.23** and would have been
dispatched.

The gate is therefore **permissive-only** — dispatch requires *both* conditions:

| | benign max | destructive min | threshold |
|---|---|---|---|
| `risk.score` | **0.08** | **0.23** | `≤ 0.20` to act |
| `risk.confidence` | min **0.89** | max **0.87** | `≥ 0.85` to act |

That admits **15/15 benign** and refuses **15/15 destructive**. Both conditions
are required: score alone would rely on luck about range, and confidence alone
would admit "force quit the app" at 0.66.

**Noul is not used for risk.** Measured, "force quit the app" scores **0.16** on
the risk Noul — *below* the benign "toggle dark mode" at **0.18**. The overlap
is small but sits in the unsafe direction, so a Noul band is not a risk gate.
Noul is used only for the `applied` completion question.

**Honest limits:** n = 15 per class, text-only states, one prompt formulation.
This is a calibrated starting point, not a proven gate. §9 re-measures it on the
corpus; the gate tightens on evidence and is never loosened without new data.

### 5.5 Untrusted screen text
Window titles and labels are attacker-controlled. TypeSafe documents that models
are susceptible to adversarial state
([model-jaggedness](https://docs.typesafe.ai/model-jaggedness/jev-1.13)).
Authorization is therefore **never** derived from screen text: §6.4 approval is
a local token minted from the operator's own `--approve` flag.

---

## 6. Primitives, execution, and outcomes

### 6.1 Primitive table (v1 allowlist)

| Primitive | Mechanism | Precondition | Argument |
|---|---|---|---|
| `press` | `AXUIElementPerformAction(el, kAXPressAction)` | `"AXPress"` ∈ `AXUIElementCopyActionNames(el)` | none |
| `setValue` | `AXUIElementSetAttributeValue(el, kAXValueAttribute, text)` | `AXUIElementIsAttributeSettable(el, kAXValueAttribute)` is true | text from the **goal string**, never from screen content |

Explicitly **not** in v1: `submit`, `send`, `delete`, `press` on any menu item
whose label matches a destructive regex, coordinate clicks, CGEvent synthesis,
and any action inferred from the action-name list.

`setValue` **replaces** the entire field value. It does not append, insert, or
submit. Verified on Safari's address bar (set → success, read-back matched,
restore → success); arbitrary text-control support is otherwise **UNVERIFIED**.

### 6.2 Approval

`jevscope decide` emits a decision containing an **approval token**: a
`SHA256` over `snapshotGeneration ‖ appLaunchID ‖ primitive ‖ handle ‖
arguments ‖ thresholds ‖ questionVersion`. `apply` requires that token via
`--approve <token>` and refuses if any component differs.

A token is **single-use**: applying consumes it. Re-running `decide` after any
mutation mints a different `snapshotGeneration` and therefore a different
token, so a stale approval cannot be silently reused.

### 6.3 Preconditions re-verified at apply time
1. Same app, same launch (`appLaunchID`), non-`nil` retained backend reference.
2. Snapshot generation matches the decision.
3. `AXUIElementCopyActionNames` still contains the required action (or the
   attribute is still settable).
4. Element still reports `enabled != false`.
5. **Same-role substitution is explicitly out of scope of detection** and is
   disclosed (§6.5).

### 6.4 Outcome is tri-state

| Outcome | Meaning | Retry |
|---|---|---|
| `refused(code)` | **Nothing was dispatched** | n/a |
| `applied` | Dispatched and confirmed by a subsequent successful AX read | never |
| `unknownOutcome` | Dispatched; AX returned `.cannotComplete` or the connection failed | **never** — report for human adjudication |

A dispatched mutation is **never** automatically retried. HTTP retries to the
Jev API are a separate concern from actuator retries.

### 6.5 The residual race — disclosed, not solved
There is an unavoidable interval between the last precondition check and the
target app processing the request. AX exposes no transaction that combines
snapshot verification with the action. Same-role label-preserving replacement,
virtualized row reuse, and a selection change under an unchanged toolbar
control are **not detectable** by any AX read available to us.

Consequences: v1 ships a **narrow allowlist**, no submit/delete primitives, a
single-use token bound to exact arguments, and an operator who must supply
`--approve`. This is why v1 does **not** offer a generic unattended `act`.

---

## 7. Candidate selection and budget

### 7.1 Eligibility (hard filter)
Keep an element only if **all** hold:
- name resolves non-empty via **`AXDescription` → `AXTitle` → `AXHelp` →
  `AXIdentifier`** (identifier **last**: it is often AppKit's private `_NS:<n>`,
  which is useless to the model — `evidence/ax-element-table-format.txt`);
- name length ≥ 3 and does not start with `.` or `AX`;
- ≥ 1 named action;
- `enabled == true` (absent is **not** coerced to true — such elements are
  dropped and counted);
- frame is non-empty, non-zero, and intersects the union of `NSScreen.visibleFrame`;
- not AppKit-synthetic (identifier matching `_NS:<n>` **and** no description/title).

### 7.2 Ranking
```
score = 4·enabled + 2·offersPress + 1·(name.count >= 3)
      + 0.5·(frameArea > 800) + 3·(name contains any goal term)
```
`goalTerms` = lowercased goal tokens split on non-alphanumerics, length ≥ 2,
stopwords removed. **Ties break on `(name, path)` ascending** so ordering is
deterministic and stable across runs and across K sweeps.

Keep top **K = 24** (configurable). Handles are `e00…e23`, **assigned after
ranking** and stable for a given snapshot generation — pruning never renumbers a
handle that was already emitted.

Measured (`evidence/ax-candidate-ranking.txt`): Finder 510 → 39 eligible;
Safari 784 → 59; TextEdit 470 → 9.

### 7.3 Budget — bytes, not guessed tokens
There is no official tokenizer. Rather than the v1 `chars/3.5` estimate (which
codex correctly rejected as unverified), jevscope budgets on **UTF-8 bytes of
the fully serialized request**, at **1 token ≤ 1 byte** — conservative, since
measured 800 elements ≈ 32,800 bytes ≈ 32,891 tokens.

Budget: **28,000 bytes**, covering `goal`, all four `instructions`, all `criteria`
(with the full candidate table duplicated into `target`), the element table, and
model framing.

Overflow order, deterministic:
1. drop the `value` field from each element line;
2. drop `frame`;
3. drop `actions` for the lowest-ranked candidates;
4. reduce K by halving (24 → 12 → 6 → 3 → 1);
5. still over ⇒ **fail closed** with `budgetExhausted`. Never silently truncate.

Re-check the final serialized request before sending. On HTTP 400
`max_tokens_exceeded`, retry **once** at K/2, then fail closed.

### 7.4 Escaping and the line grammar
Labels may contain quotes, newlines, pipes, or text resembling a numbered row.
Escape as: `\` → `\\`, `"` → `\"`, newline → `\n`, CR → `\r`, `|` → `\|`.
Any residual control character is replaced with `?`. After escaping, a line
matching `^\[\d{2,}\]` inside a label is prefixed with a space.

---

## 8. Backend contract and error handling

### 8.1 Backend protocol (normalized — no raw `AXUIElement` escapes)
```swift
protocol AXBackend {
    func launchID(app: String) throws -> String
    func snapshot(generation: Int, budget: ByteBudget) throws -> Snapshot
    func supports(_ primitive: Primitive, on handle: Handle) throws -> Bool
    func verify(_ binding: Binding) throws -> VerifyResult
    func dispatch(_ binding: Binding) throws -> DispatchResult
}
```
`AXUIElement` ownership, Swift 6 isolation and `AXError` conversion stay inside
the production adapter. **Fixture tests never touch real AX.**

### 8.2 Phase-specific error table

| Phase | Condition | Result |
|---|---|---|
| attribute | optional attribute absent (`AXIdentifier`, `AXHelp`) | field is `nil`, continue |
| attribute | essential attribute malformed (wrong CF type) | skip element, count `malformed` |
| attribute | `enabled` absent | element is **dropped**, counted `enabledUnknown` — never coerced to true |
| traversal | child enumeration fails for a subtree | mark snapshot **partial**, continue; record `truncated` |
| traversal | depth > 40, node cap, or a repeated element | stop that branch, count `cycleGuard` / `limit` |
| preflight | app not running, AX not trusted, empty root | `refused(.axUnavailable)` |
| preflight | snapshot **partial** *and* fewer than 3 eligible candidates | `refused(.incompleteSnapshot)` |
| dispatch | precondition fails | `refused(.fingerprintChanged)` |
| dispatch | `.cannotComplete` or transport failure | **`unknownOutcome`**, never `refused` |

A snapshot is `complete` or `partial`; the flag is recorded in every trace and
in every corpus case.

### 8.3 Refusal precedence
When several conditions hold, the **first** match in this order is reported:
`budgetExhausted` → `axUnavailable` → `incompleteSnapshot` → `invalidAnswer` →
`lowConfidence` → `unknownHandle` → `unsupportedAction` → `ambiguousNoul` →
`approvalRequired` → `staleApproval` → `fingerprintChanged` → `ambiguousName`.

### 8.4 Fake backend contract
`ScriptedBackend` replays a transition list and records an **action log**.
Required scripted cases: same-role replacement; row reuse; selection change under
an unchanged control; app restart; out-of-order response; low-confidence
fixture; `cannotComplete` after a recorded mutation.

**Every refusal test asserts the action log is empty. Every unknown-outcome test
asserts exactly one recorded dispatch.**

---

## 9. Evaluation

### 9.1 Two separate modes
- **`jevscope replay <corpus>`** — fully offline and **deterministic**: recorded
  Jev responses + a fake backend. Asserts **identical normalized decisions and
  refusal codes** across runs. No network.
- **`jevscope eval-live <corpus>`** — calls the live API. Reports metrics and
  **asserts nothing about run-to-run equality**. Latency and timestamps vary;
  `jev-latest` moves.

### 9.2 Pinned for live runs
`model` id resolved at run start (recorded), question version, serialisation
version, ranking version, thresholds, corpus hash, candidate ordering,
`--repeats` (default 3) with median and min/max reported.

### 9.3 Case schema
```json
{ "id":"finder-list-view",
  "app":"com.apple.finder", "snapshot":"finder-recents-v1.json",
  "goal":"switch to list view",
  "expect": { "operation":"press", "target_name":"list view" },
  "expectRefusal": null,
  "acceptableTargets": [] }
```

### 9.4 Metrics — explicit denominators
| Metric | Definition |
|---|---|
| `operationAccuracy` | correct `operation` ÷ **all cases** |
| `targetAccuracy` | correct target name ÷ cases where `operation` was correct |
| `exactAccuracy` | operation **and** target correct ÷ all cases |
| `refusalPrecision` | correct refusals ÷ cases whose oracle is a refusal |
| `falseActRate` | acted-when-oracle-said-refuse ÷ **cases the system acted on** |
| `targetPrunedRate` | correct target absent from candidates ÷ all cases |
| `coverage` | acted ÷ all cases (so a refusal-only system cannot "win") |

`refusalPrecision` over zero refusals is reported as `null`, never 1.0.
`acceptableTargets` is non-empty ⇒ a match on any listed name counts.
`targetPruned` is scored separately, never as a silent pass.

### 9.5 Acceptance matrix
Replay must reproduce, for every corpus case, the recorded normalized decision
or refusal. All §8.4 scripted cases must pass. Refusal tests assert zero
dispatches; unknown-outcome tests assert exactly one. The stochastic
"low-confidence" smoke test is **replaced** by an injected fixture.

---

## 10. Artifacts, privacy, and secrets

### 10.1 Two classes
| Class | Location | Version control | Contents |
|---|---|---|---|
| **Raw capture** | `~/.local/share/jevscope/` | **never** | full AX tree incl. text-field values |
| **Sanitized corpus** | `corpus/v1/*.json` | **yes** | element tables with names/values replaced by stable placeholders (`<LABEL_07>`), frame jittered, app + goal retained |

Only the sanitized form is published. `CONTRIBUTING.md` is updated to match —
v1 contradicted itself here.

### 10.2 Runtime files
Traces: `~/.local/share/jevscope/traces/`. Results: `results/results.json` in
the repo, written **only** by `eval-live` via an explicit `--write-results`.
v1's "no writes outside Application Support" is scoped to runtime state only.

### 10.3 Trace contents and redaction
Traces record: timestamps, resolved model, question version, thresholds, the
**decision and refusal code**, the action log, usage counts, and a **SHA256 of
the request body** — not the body. The API key is never written. Headers are
never written. Screen text is not written to traces; the sanitized corpus is the
only artifact containing element text, and it is placeholder-substituted.

### 10.4 Non-disclosing secret check
The v1 `git grep "$(cat .env)"` is unsafe — it expands secrets into argv and
prints matches. Replaced by a check that compares **SHA256 digests** and prints
only file paths and a count:
```
python3 scripts/check-secrets.py   # prints "0 files contain the API key"
```
It never prints the secret and never passes it on a command line.

### 10.5 Two authorities, not one
Holding the TypeSafe API key does **not** grant macOS Accessibility permission;
they are separate. `SECURITY.md` is corrected to keep them distinct.

---

## 11. Module surface

Single production library target `AXKit` (matching the verified `Package.swift`),
plus the `jevscope` executable and `AXKitTests`. The v1 `JevCore` name is
dropped — it never existed.

| Module | Responsibility |
|---|---|
| `AXTypes` | `Snapshot`, `Element`, `Handle`, `RefusalCode`, `Outcome`, `AXBackend` |
| `AXAdapter` | the only code touching `AXUIElement`; CF conversion; `AXError` mapping |
| `FixtureBackend` | `ScriptedBackend` + action log |
| `ElementTable` | eligibility, ranking, escaping, budget, serialisation |
| `JevClient` | codable request/response, retries, budget guard, validation |
| `Gate` | §5 composition and thresholds |
| `Resolver` | handle → binding, preconditions, §6.3 |
| `Actuator` | primitive allowlist, dispatch, tri-state outcome |
| `Trace` | JSONL writer, redaction per §10.3 |
| `jevscope` | CLI |

## 12. CLI

```
jevscope doctor                       # AX trust + Jev reachability; never echoes the key
jevscope tree --app com.apple.finder  # snapshot → element table
jevscope decide --app … --goal "…"    # Decision + approval token; no side effects
jevscope apply --approve <token>      # allowlisted primitive only
jevscope replay --corpus corpus/v1    # deterministic, offline
jevscope eval-live --corpus corpus/v1 # measured, pinned
```

`decide` never dispatches. `apply` is the only dispatching command and requires
`--approve`. Bundle identifiers are used throughout; no name lookup, so no
ambiguity.

## 13. Verification plan

| # | Gate | Command |
|---|---|---|
| 1 | Builds clean | `swift build` |
| 2 | Offline tests pass, no network, no AX | `swift test` |
| 3 | Real AX tree from a real app | `.build/debug/jevscope tree --app com.apple.Safari` |
| 4 | Live Jev round-trip | `.build/debug/jevscope doctor` |
| 5 | Refusal provably fires | fixture; assert action log empty |
| 6 | Unknown-outcome provably fires | fixture; assert exactly one dispatch |
| 7 | Replay is deterministic | run twice, diff normalized output |
| 8 | No secret leakage | `python3 scripts/check-secrets.py` |
| 9 | Codex validation | independent review dispatch |

## 14. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Residual TOCTOU race is unclosable | **High** | §6.5 discloses it; narrow allowlist; no unattended act; single-use tokens |
| Concept not novel | **High** | §2; own the harness and the honesty |
| Raw AX tree is poor input — ~33% of macOS apps offer full a11y support, and name/description/value are frequently missing ([Screen2AX, arXiv:2507.16704](https://arxiv.org/abs/2507.16704)) | **High** | measure it in §9; that measurement is the deliverable |
| Vision-first camp claims to beat the text baseline on grounding ([OmniParser, arXiv:2408.00203](https://arxiv.org/abs/2408.00203)) | Medium | publish numbers either way |
| Noul gates refuse benign actions (measured 0.39–0.71 on harmless goals) | Medium | §5.4; risk gated by `Score`, not Noul |
| AX calls hang (`kAXErrorCannotComplete`) | Medium | messaging timeout at startup; §8.2 phase table |
| `jev-latest` moves under `eval-live` | Medium | §9.2 pins and records the resolved id; replay is separate |
| AGPL contamination from prior art | Low | clean-room; MIT only; nothing vendored |

## 15. Licence and provenance

MIT. **No code copied from any prior project.** The Jev request shape derives
from canonical TypeSafe HTTP docs and from the operator's own private
`paper-traiding-mk4-executor` (Python). Prior-art projects are cited, not
vendored. The Swift AX client was written against the live macOS 27 SDK, with
every API confirmed by a successful compile or a runtime read recorded under
`evidence/`.