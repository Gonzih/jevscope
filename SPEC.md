# jevscope — SPEC v1

**Status:** draft, awaiting Codex review
**Date:** 2026-10-02
**Repo:** `Gonzih/jevscope` (public)

---

## 1. Problem

There is no reproducible, openly specified way to answer one question: **how
well does TypeSafe Jev actually decide macOS actions from the raw Accessibility
tree?** Every published Jev computer-use project ships a working agent and an
author-reported number. None ships a harness a third party can run.

## 2. Prior art — stated plainly, up front

This concept is **not novel**. Six projects already do it. This is the single
most important thing a reader should learn from this repository.

| Project | Lang / license | Perception | Jev role |
|---|---|---|---|
| [savka777/jev-use](https://github.com/savka777/jev-use) | Swift, MIT, 114★ | macOS AX tree only | operation + numbered target |
| [awlevin/typesafe-computer-use](https://github.com/awlevin/typesafe-computer-use) | Python, MIT, 1144★ | Vision OCR ⊕ AX tree | 3 Choices/step |
| [jcpsimmons/jev-macos-loop](https://github.com/jcpsimmons/jev-macos-loop) | JS+Swift, AGPL-3.0 | ScreenCaptureKit + OmniParser + Vision OCR ⊕ AX | finite choice over element IDs |
| [paulsmith/computer-use-jev](https://github.com/paulsmith/computer-use-jev) | Go + Swift worker, MIT | AX tree only | action / target / done / needs-text |
| [Eronmmer/jev-cua](https://github.com/Eronmmer/jev-cua) | TypeScript, AGPL | AX first, approved screenshot fallback | workflow router only |
| [trycua/cua `jev-use` recipe](https://github.com/trycua/cua/tree/main/libs/cua-driver/examples/jev-use) | Python + TS | macOS AX / Windows UIA / Linux AT-SPI | capped candidate choice |

`savka777/jev-use` is a Swift macOS app whose README describes the naive
version of this project almost clause-for-clause.

**We do not claim to be first.** The differentiator, and the only one we can
actually defend, is §3.

## 3. What we claim to build

1. **An open spec** — the Jev question contract, the element-table format, the
   confidence semantics, and every refusal rule written down and versioned.
2. **A reproducible eval harness** — a versioned corpus of real macOS
   Accessibility snapshots, a runner that reports decision accuracy, refusal
   rate, and latency, and a committed results file. A third party can re-run it.
3. **Correct confidence semantics** — see §6. Every existing project gates on a
   field whose meaning is not what the docs claim. We measure this (§6.3) and
   implement the corrected version.
4. **A fail-closed action layer** — the handle-resolution rules in §7, with the
   refusal taxonomy as part of the public API.

We deliberately do **not** ship an autonomous agent loop in v1. The eval harness
is the deliverable; the loop is downstream of it.

## 4. Verified constraints

Everything in this section was measured on this machine against the live API on
2026-10-02, or read from canonical TypeSafe docs. Marked facts are reproducible.

### 4.1 Jev is text-only
> "Jev currently accepts text input only. It evaluates strings, JSON objects,
> and arrays of text. Images, audio, and video are not supported (yet)."
> — [docs.typesafe.ai/concepts/system-one](https://docs.typesafe.ai/concepts/system-one)

**Consequence:** no pixels ever leave the machine. The entire perception layer is
the Accessibility tree. This is a hard architectural constraint, not a choice.

### 4.2 There is no official Swift SDK
Official SDKs are Python `typesafe-sdk` and JS/TS `@typesafe-ai/sdk`. No Swift,
Kotlin, or Java SDK exists. *(`[PARTIAL]` — an unofficial Kotlin Multiplatform
client `itisnomatter/kojev` exists; the complete official list was not
enumerated from `/sdk`.)*

**Consequence:** hand-written `URLSession` client. Correct for a pure-Swift
desktop tool regardless.

### 4.3 There are no Domain-Specific Models
`https://docs.typesafe.ai/models` lists exactly one model, `jev-1.13.0`, with two
aliases. No UI, computer-use, or macOS model exists. "DSM" is not a documented
TypeSafe concept. Jev is shaped to a domain **through the request**, never
through per-account weights.

### 4.4 Model aliases — live `GET /v1/models` (HTTP 200)
```json
{"models":[
  {"name":"jev-latest", "release_date":"2026-09-10T18:38:01Z"},
  {"name":"jev-preview","release_date":"2026-09-10T18:39:06Z"}]}
```
Responses carry a concrete version, e.g. `"model": "jev-1.13.0"`. jevscope
defaults to `jev-latest` and **records the resolved version in every trace**.

### 4.5 Undocumented error: HTTP 400 `max_tokens_exceeded`
The API reference documents 401, 422, 429, 529. It does **not** document 400.
The live API returns it:
```
HTTP 400  {"detail": {"error_type": "max_tokens_exceeded"}}
```
**Consequence:** the client must treat 400 with `error_type ==
"max_tokens_exceeded"` as a first-class, non-retryable, budget error — not a
generic bad request.

### 4.6 Token ceiling ≈ 32.8k input tokens (bisected)
Synthetic element tables, one Choice question, `jev-latest`:

| elements | input tokens | result |
|---|---|---|
| 799 | 32,850 | HTTP 200 |
| 800 | 32,891 | HTTP 400 `max_tokens_exceeded` |

**Consequence:** client-side budget of **28,000 input tokens**, leaving >15%
headroom. Over budget ⇒ rank-and-prune, never silently truncate.



### 4.7 Latency (live, 1–2 word states, 10–400 elements)
189 ms @ 10 elements · 325 ms @ 50 · 270 ms @ 100 · 407 ms @ 200 · 397 ms @ 400.
**Consequence:** a synchronous per-step loop is viable. No batching tricks needed.

### 4.8 The macOS AX contract — compile- and runtime-verified on this machine

Accessibility permission is **already granted here**, so the findings below are
runtime-verified, not just compiled. Swift 6.4, macOS 27.0.1, arm64.

**API shape that works:**
- `AXUIElementCreateApplication(pid_t) -> AXUIElement`;
  `NSWorkspace.shared.frontmostApplication` (`.activeApplication` is deprecated).
- All `kAX*` constants are Swift **`String`** in Swift 6 — every call site needs
  `as CFString`. 57 roles and 34 notification constants verified.
- `AXError` is a **Swift enum, 17 cases**. There are **no `kAXError*` globals**,
  and `AXError` does **not** conform to `Error` — so `Result<_, AXError>` does
  not compile. Map it explicitly.
- `AXValueGetValue` needs `withUnsafeBytes(of:)`; `UnsafeRawPointer(&var)` warns.
  AX coordinates are top-left-origin screen space, **not** flipped Quartz.
- AX calls work **off the main thread**.

**Text entry — verified working.** Setting a value on a text field is:
```swift
AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, text as CFString)
```
Verified end-to-end on Safari's address bar
(`WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD`): set → `kAXErrorSuccess`, read-back
matched, restore → `kAXErrorSuccess`. **No CGEvent synthesis is needed.** Note
`kAXSelectedText` is *not* settable (`isSettable == false`), and `CFBoolean(v)`
does not compile — use `kCFBooleanTrue` / `kCFBooleanFalse`.

**Gotchas that will bite, all confirmed by compiler diagnostics:**
- `String` does **not** bridge to a `CFString` parameter.
- A `static let` holding a `CFString` is a Swift 6 concurrency error
  (`CFString` is non-`Sendable`, `#MutableGlobalVariable`).
- `kAXTrustedCheckOptionPrompt` is a **global `var`** → also non-`Sendable`.
- `kAXFrameAttribute` **does not exist in the SDK** (apps advertise `"AXFrame"`
  but return `kAXErrorAttributeUnsupported`). Use `kAXPositionAttribute` +
  `kAXSizeAttribute`.
- `AXMakeProcessTrusted` is unavailable in Swift.
- Do **not** use `CFArrayGetValueAtIndex` + `load(as:)` — it compiles with a
  type error and **segfaults** (exit 139). Safe path: bridge `CFArray` → `NSArray`,
  check `CFGetTypeID(obj) == AXUIElementGetTypeID()` (live value 77), then
  `unsafeDowncast`.
- `AXObserverCreate` must receive the **target app's pid** — not your own, and
  not `0`/`-1`, which return `AXError.illegalArgument` (-25201). Confirmed
  runtime: own pid → `AddNotification` fails -25201; target pid → succeeds.

**Verified `Package.swift`** (builds clean, 6 tests pass, dumps a live iTerm2
AX tree off the main thread):
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
                linkerSettings: [.linkedFramework("ApplicationServices"), .linkedFramework("AppKit")]),
        .executableTarget(name: "jevscope", dependencies: ["AXKit"],
                swiftSettings: [.swiftLanguageMode(.v6)],
                linkerSettings: [.linkedFramework("ApplicationServices"), .linkedFramework("AppKit")]),
        .testTarget(name: "AXKitTests", dependencies: ["AXKit"],
                swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
```
The library does **not** re-export ApplicationServices; any target naming
`AXUIElement` must import it itself.

---

## 5. Architecture

```
                    ┌──────────────────────────────────────┐
                    │  AXBackend (protocol)                │
                    │  AXUIElementBackend | FixtureBackend  │
                    └───────────────┬──────────────────────┘
                                    │  [Snapshot] (pure value type)
                    ┌───────────────▼──────────────────────┐
                    │  ElementTable                         │
                    │  flat, indexed, budgeted, serialised  │
                    └───────────────┬──────────────────────┘
                                    │  state: JSON string
                    ┌───────────────▼──────────────────────┐
                    │  JevClient (URLSession)              │
                    │  → answers (typed, decoded, checked)  │
                    └───────────────┬──────────────────────┘
                                    │  [Decision]
                    ┌───────────────▼──────────────────────┐
                    │  Gate        — confidence semantics   │
                    │  Resolver    — handle → live element  │
                    │  Actuator    — role∩action check     │
                    └───────────────┬──────────────────────┘
                                    │  .act() | .refuse(reason)
                    ┌───────────────▼──────────────────────┐
                    │  Trace (JSONL, no secrets)           │
                    └──────────────────────────────────────┘
```

`JevCore` is pure: `AXBackend` is a protocol, so the whole decision path is
testable against fixtures with no live API and no Accessibility permission.

---

## 6. Confidence semantics — verified against the live API

This is the technical core of the project.

### 6.1 Documented formulas
From [docs.typesafe.ai/confidence](https://docs.typesafe.ai/confidence):
- Choice: `(p_max − 1/n) / (1 − 1/n)`
- Score: `max(0, 1 − Σ p_i·|i − m| / MAD_unif)`, `MAD_unif = (1/n)Σ|i − (n−1)/2|`,
  where **`m` is the most likely level (`argmax` of the probabilities)** — *not*
  the returned mean `score`
- Noul: `|2p − 1|`, **derived client-side, not returned**

### 6.2 What actually comes back (live, 32 samples)
- **Choice**: formula **confirmed**, max abs error **0.005** (8 samples).
- **Score**: formula **confirmed**, max abs error **0.020**, mean **0.008**
  (24 samples) — consistent with two-decimal rounding. An earlier revision of
  this spec wrongly reported the formula as unreproducible; that was an error in
  the analysis (it fed the returned mean `score` in as `m`). Caught by the Codex
  review, re-verified, and recorded in `evidence/score-confidence-findings.md`.
- **Noul**: carries **no `confidence` field at all** — only `noul`. High `noul`
  means **YES** (0 = no, 1 = yes), verified 6/6 including a negative-polarity
  probe; see `evidence/noul-polarity.md`.

### 6.3 What we implement
Gate on the server's `confidence` for **Choice** and **Score** — both are now
verified reproducible, so there is no reason to reimplement them.

| Answer type | Gate on | Rule |
|---|---|---|
| Choice | server `confidence` (≡ `p_max` form) | act if `confidence ≥ threshold` |
| Score | server `confidence` | act if `confidence ≥ threshold` |
| Noul | the `noul` value, two-sided | `noul ≥ hiT` ⇒ **yes**; `noul ≤ loT` ⇒ **no**; otherwise **refuse** |

Noul is the only primitive needing our own threshold, because the API returns
no confidence for it. Defaults: `loT = 0.20`, `hiT = 0.80`; destructive
questions raise `hiT` to `0.95`, following the canonical worked example.

> **Corrected defect.** An earlier draft read this gate as
> `p ≤ loT ⇒ yes` / `p ≥ hiT ⇒ no`. That is **inverted**: it selected the
> destructive branch exactly when the model was least confident the action was
> destructive, inverting the safety mechanism. Found by the Codex review and
> independently re-verified live.

Every threshold is **configurable and recorded in the trace**. Refusals emit the
full probability distribution, following `paulsmith/computer-use-jev`.

---

## 7. Element identity — the fail-closed contract

### 7.1 Strategy (chosen from three, with reasons)
1. **`AXIdentifier`** — high precision, near-zero recall. Purely opt-in: AppKit's
   Interface Builder Identity inspector exposes only Description and Help, and
   SwiftUI only emits an identifier via `.accessibilityIdentifier`. Probing it
   costs one IPC round-trip per node and usually returns `kAXErrorNoValue`.
   **Opportunistic tie-breaker only. Never the primary key.**
2. **Index path** (`/3/1/0`) — guaranteed present and unambiguous *within one
   frozen snapshot*, but meaningless to a model, which will hallucinate a
   plausible path. **Machine key only.**
3. **Role + ordinal + label** — the only vocabulary a text-only model already
   understands. **Model-facing handle.**

Note from the live SDK: AppKit maps `accessibilityLabel` → **`AXDescription`**
(not `AXTitle`).

**Corrected name-resolution order:**
**`AXDescription` → `AXTitle` → `AXHelp` → `AXIdentifier`** — identifier **last**.
An earlier draft put `AXIdentifier` first. Measured against real trees, that
yields AppKit's private placeholders (`_NS:61`, `_NS:8`, `_NS:23`) as the
displayed name, which is useless to a text-only model and contradicts §7.1's own
"tie-breaker only" intent. See `evidence/ax-element-table-format.txt`.
Measured coverage on this machine (4 running apps, 3,574 nodes): **identifier
66%, description 7%, title 46%, named-by-any-order 74%**
(`evidence/ax-quality-macos27.txt`). Those are Apple apps; third-party coverage
is **UNVERIFIED** and the eval harness exists to measure it.

### 7.2 Serialised element line
Flat, numbered, one element per line — a numbered list beats a nested tree for
a text-only model and keeps the handle adjacent to the human name.

```
[07] AXButton "Archive" | enabled | 512,180,72x24 | press | /3/1/0
```

`enabled` is **tri-state**: `enabled`, `disabled`, or `-` when the attribute is
absent. An earlier draft rendered absent as `disabled`, which mislabelled every
`AXWindow` (they do not report `kAXEnabledAttribute`) as disabled. `nil` means
not applicable, never disabled.

### 7.3 Resolution, re-verification, refusal
1. Jev returns a handle. Look it up in **this snapshot's** map — the only
   authoritative path.
2. **Re-verify by full fingerprint**, not just role+enabled. An index path can
   silently point at a *different same-role control* after the UI changes, so
   role alone is insufficient. Compare `role`, `subrole`, `identifier`, `title`
   and `description` against the snapshot. Measured drift across 190 re-read
   comparisons on static Finder/Safari trees: **0% on all fields**
   (`evidence/ax-fingerprint-stability.txt`), so this is a sound identity guard.
   *UNVERIFIED:* that it actually fires when a control is genuinely swapped —
   that test requires mutating a real UI, which v1 does not do.
3. Check the action is actually offered, via `AXUIElementCopyActionNames` — not
   a hardcoded role table.
4. Perform **at most once**. Never retry a perform.

**Refuse, deterministically, when any of these hold:**

| Code | Condition |
|---|---|
| `unknownHandle` | handle not in this snapshot's map |
| `staleSnapshot` | snapshot bound to a different app/launch instance |
| `disabled` | element reports `enabled == false` |
| `fingerprintChanged` | any identity field differs from the snapshot |
| `ambiguousName` | name fallback matched 0 or >1 elements |
| `unsupportedAction` | role does not offer the requested action |
| `lowConfidence` | Choice/Score confidence below threshold |
| `ambiguousNoul` | noul value inside the refusal band |
| `readError` | an AX **read** returned non-success ⇒ no action taken |

**`unknownOutcome` — a distinct terminal state, not a refusal.**
Apple's own header (`AXUIElement.h:317-320`) states that
`AXUIElementPerformAction` may return `kAXErrorCannotComplete` and that
*"This does not necessarily mean that the function has failed."* Apple even
suggests retrying — which on a destructive control means **double execution**.
So an action timeout is neither a proven success nor a proven failure:

- performs are attempted **once**, never retried;
- `kAXErrorCannotComplete` on a perform ⇒ `unknownOutcome`;
- `unknownOutcome` requires human adjudication and is reported distinctly, so
  it is never conflated with "we chose not to act".

See `evidence/ax-perform-timeout-semantics.md`.

**Invariant A:** exactly one handle resolves to at most one element, or the run
refuses. There is no "best-guess" path.

### 7.4 Candidate ranking (measured, not aspirational)
Raw trees are far too large to act on: **510–784 nodes**, of which 346–519 are
named *and* actionable. Two stages, both measured:

**Hard filter — keep only:** named (≥3 chars) · has ≥1 action · `enabled == true`
· frame non-empty and intersecting the screen · **not** an AppKit-internal
placeholder (identifier matching `_NS:<n>` *and* no description/title).

**Score, then keep top K** (default **K = 24**, configurable):
`4·enabled + 2·offersPress + 1·name≥3chars + 0.5·area>800px² + 3·goalTermMatch`,
ties broken by name for determinism. `goalTerms` = lowercased goal tokens,
split on non-alphanumerics.

Measured (`evidence/ax-candidate-ranking.txt`):

| app | nodes | after hard filter | top-24 tokens |
|---|---|---|---|
| Finder | 510 | **39** | 485 |
| Safari | 784 | **59** | 421 |
| TextEdit | 470 | **9** | 163 |

The filter removes ~92%, and goal-term matching puts the right control first
(`search` → `Search[AXButton]`; `delete` → `Delete[AXButton]`). **A top-24 table
costs 163–485 tokens — the 28k budget in §4.6 is never the binding constraint.**
Ranking governs *accuracy*, not tokens.

---

## 8. Module surface

| Module | Responsibility | Depends on |
|---|---|---|
| `AXTypes` | `Snapshot`, `Element`, `RefusalCode`, `AXBackend` protocol | Foundation |
| `ElementTable` | walk → index → budget → serialise | AXTypes |
| `JevClient` | request/response codable types, retry, budget guard | Foundation |
| `Gate` | confidence semantics (§6.3) | — |
| `Resolver` | handle → live element, refusal taxonomy | AXTypes |
| `Actuator` | role∩action check, perform | AXTypes |
| `Trace` | JSONL writer, secret-free | Foundation |
| `jevscope` (exe) | CLI | all |

## 9. CLI

```
jevscope doctor                      # AX trust + Jev reachability, no key echoed
jevscope tree [--app <bundleID>]     # snapshot → element table → stdout
jevscope decide --goal "<text>"      # snapshot + goal → decision or refusal (no action)
jevscope act --goal "<text>"        # decide, then act, fail-closed
jevscope eval [--corpus <dir>]       # run the harness, write results.json
```

`decide` and `act` are separate so the eval harness can measure decisions
without touching the desktop. **`--dry-run` is the default; acting requires an
explicit flag or a resolved `approval_required` refusal.**

## 10. Eval harness (the differentiator)

- **Corpus:** versioned real AX snapshots (JSON), captured from a fixed script
  of apps, committed under `corpus/v1/`. Each case: goal, expected operation,
  expected target handle, expected refusal code where applicable.
- **Runner:** sweeps candidate counts (≈4 / 12 / 24, following the Cua recipe's
  measured operating point) and reports decision accuracy, refusal precision,
  false-act rate, and p50/p95 latency.
- **Output:** `results/results.json` — committed, with the resolved model
  version, date, and corpus hash. A regression is a diff a third party can read.
- **Fixtures never hit the network.** `FixtureBackend` + a stub client make
  `swift test` hermetic and offline.

## 11. Verification plan

| # | Gate | Command |
|---|---|---|
| 1 | Builds clean | `swift build` |
| 2 | Unit tests pass, hermetic | `swift test` |
| 3 | Real AX tree, real app | `jevscope tree --app Finder \| head -40` |
| 4 | Live Jev round-trip | `jevscope doctor` |
| 5 | Refusal provably fires | act on a low-confidence goal; expect a `Refusal`, no AX action |
| 6 | Corpus reproducible | `jevscope eval` twice → identical results |
| 7 | No secret leakage | `git grep -I $(cut -d= -f2 .env)` → empty |
| 8 | Codex validation | independent review dispatch |

## 12. Non-goals for v1

Autonomous multi-step loops · screenshots / OCR / any pixel path · clicking by
screen coordinates · agent memory · a GUI · background agents · writing files
outside `Application Support`.

## 13. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Concept not novel | **High** | §2/§3 positioning; own the harness, not the idea |
| Raw AX tree is poor input — only ~33% of macOS apps offer full a11y support, and name/description/value are frequently missing ([Screen2AX, arXiv:2507.16704](https://arxiv.org/abs/2507.16704)) | **High** | measure it in the harness; that measurement *is* the deliverable |
| Vision-first camp claims to beat the text baseline on grounding ([OmniParser, arXiv:2408.00203](https://arxiv.org/abs/2408.00203)) | Medium | publish the numbers either way; add a local-vision arm in v2 if text loses |
| AX calls hang (`kAXErrorCannotComplete`) | Medium | `AXUIElementSetMessagingTimeout` at startup; treat as skip-element |
| Elements change between snapshot and act | Medium | §7.3 re-verification; the refusal taxonomy |
| Token ceiling | Low | §4.6 budget + rank-and-prune |
| AGPL contamination from prior art | Low | clean-room; MIT only; no code copied |

## 14. Licence and provenance

MIT. **No code copied from any prior project** — the Jev request shape was
ported from the operator's own private `paper-traiding-mk4-executor`
(Python), and the Swift client is written from the canonical TypeSafe HTTP
contract. Prior-art projects are cited, not vendored.
