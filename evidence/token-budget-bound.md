# Token budget bound — corrected 2026-10-02

SPEC §7.3 budgets on **UTF-8 bytes of the serialized request plus a fixed
framing allowance**. There is no official tokenizer, so the bound is measured.

## Correction

An earlier revision of this file claimed **`1 token ≤ 1 byte`** on the strength
of worst-case 1.80 bytes/token. **That claim is false.** Codex's live check
found a **139-byte** request reporting **304 input tokens** — more tokens than
bytes. The model counts framing that is not present in the request body.

The original measurements missed this because every sample was large enough to
amortise the constant: the ratio `bytes/tokens` rises with request size, and only
small requests expose the fixed overhead.

## Full measurement set

| case | request bytes | input tokens | bytes/token |
|---|---|---|---|
| minimal, 2 options | **139** | **304** | **0.457** |
| minimal, 3 options | 149 | 316 | 0.472 |
| small state, 2 options | 172 | 309 | 0.557 |
| ascii, 100 elements | 13,893 | 7,710 | 1.802 |
| ascii, 400 elements | 55,568 | 30,485 | 1.823 |
| unicode, 100 elements | 28,893 | 10,310 | 2.802 |
| unicode, 300 elements | 86,668 | 30,685 | 2.824 |

## Candidate bounds

| bound | covers every sample? | worst margin |
|---|---|---|
| `bytes` | **no** | 0.46× |
| `bytes + 300` | yes | 1.42× |
| `bytes + 400` | yes | 1.74× |
| **`bytes + 512`** | **yes** | **1.84×** |

## Adopted

**`requestBytes + 512 ≤ 30,000`.**

- The **512** covers fixed framing that the API counts but the client does not
  send.
- The **1 byte = 1 token** term is conservative for the variable part: the
  worst measured variable ratio was **1.86 bytes/token** (ascii).
- 30,000 leaves margin under the ~32,850-token ceiling in SPEC §4.6.

## Caveats

- Measured against `jev-latest` on 2026-10-02. Framing size is an implementation
  detail that could change with the alias; `eval-live` records the resolved
  model id, and §9 re-measures.
- The 512 allowance is empirical, not contractual. It is validated by the seven
  samples above, spanning the full observed range.
- A request smaller than ~150 bytes would be dominated by framing. jevscope's
  real requests carry a 24-candidate table, so they sit in the large regime
  where the bound has ~1.8× margin.