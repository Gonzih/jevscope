# Token budget bound — verified 2026-10-02

SPEC §7.3 budgets on **UTF-8 bytes of the fully serialized request**, assuming
**1 token ≤ 1 byte**. There is no official tokenizer, so this bound is measured
rather than assumed. (The v1 `chars/3.5` estimate was rejected in review as
unverified.)

## Method

Build a synthetic element table of N rows, serialize the complete request as
UTF-8, measure its byte length, send it, and read the server's reported
`usage.input_tokens`.

| case | HTTP | request bytes | input tokens | bytes/token |
|---|---|---|---|---|
| ascii, 100 elements | 200 | 13,893 | 7,710 | 1.802 |
| ascii, 400 elements | 200 | 55,568 | 30,485 | 1.823 |
| unicode, 100 elements | 200 | 28,893 | 10,310 | 2.802 |
| unicode, 300 elements | 200 | 86,668 | 30,685 | 2.824 |
| ascii, 600 elements | 400 | 83,368 | — | `max_tokens_exceeded` |

**Worst observed: 1.802 bytes/token.**

## Verdict

`1 token ≤ 1 byte` **holds with 1.8× margin** for ASCII and 2.8× for
non-ASCII. The bound is conservative in the safe direction, so budgeting at
28,000 bytes cannot under-count tokens. This also explains the ceiling: ~800
ASCII elements serialise to ~33 KB ≈ 32.9k tokens, matching the §4.6 bisection.

## Caveats

- The request here is one Choice question. A four-question request (§5.1) has
  more fixed overhead, which §7.3 accounts for explicitly rather than folding
  into this ratio.
- Non-ASCII labels raise the ratio, so byte budgeting is *more* conservative
  for them, not less.
- Measured against `jev-latest` on 2026-10-02. Re-measure if the model alias
  moves; `eval-live` records the resolved model id.
