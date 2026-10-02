# Security

## Two separate authorities, not one

These are distinct and must not be conflated:

1. **The TypeSafe API key** (`TYPESAFE_API_KEY` in `.env`) — a remote API
   credential. It lets you spend money and read back what was sent to
   `api.typesafe.ai`. Holding it grants **no** local privilege.
2. **macOS Accessibility (TCC) permission** — grants this binary the ability to
   read and control your UI. Possessing the API key does **not** grant it, and
   revoking it does not revoke the key.

They must be revoked independently: delete `.env` for one, remove the app under
System Settings → Privacy & Security → Accessibility for the other.

## What is sent off this machine

Everything jevscope sends to TypeSafe is **screen content from the
Accessibility tree**: window titles, control labels, and text-field values. Text
you can see in a window is sent to a third-party API. Do not use jevscope
against windows holding credentials, private messages, or regulated data unless
you accept that transfer.

There is no pixel path. Jev accepts text only, so screenshots never leave the
machine and jevscope never takes them.

## Artifacts

| Class | Where | Committed? |
|---|---|---|
| Raw capture | `~/.local/share/jevscope/` | **never** |
| Sanitized corpus | `corpus/v1/*.json` | yes — names/values replaced by `<LABEL_07>` placeholders |
| Traces | `~/.local/share/jevscope/traces/` | **never** |

Traces record timestamps, resolved model version, question version, thresholds,
the decision, the refusal code, the action log, usage counts, and a SHA256 of
the request body — **not** the body. Headers and the API key are never written.

`CONTRIBUTING.md` and `SPEC.md` agree on this; do not reintroduce a rule that
forbids committing the sanitized corpus while also requiring it to be committed.

## Fail-closed by design

jevscope refuses rather than guesses. It will not:

- act on a Choice/Score answer below threshold
- dispatch when the operation or target is `none`
- act on an `irreversible` risk score, or a `hard to reverse` one below its
  own confidence threshold
- dispatch a primitive outside the allowlist (`press`, `setValue`)
- act on an incomplete snapshot, or one with fewer than 3 eligible candidates
- resolve a handle that is not in this snapshot's generation
- **ever** retry a dispatched mutation

### The race we cannot close

Between the last precondition check and the target application processing the
request, the UI can change. The Accessibility API offers no transaction that
combines snapshot verification with the action, so **same-role substitution,
virtualized row reuse, and selection changes under an unchanged control are not
detectable.** v1 mitigates with a narrow allowlist, single-use approval tokens,
no submit/delete primitives, and mandatory operator approval — it does not
claim to eliminate the race.

## Verifying no secret leaked

```bash
python3 scripts/check-secrets.py
```

It compares SHA256 digests and prints only file paths and a count. It never
prints a secret and never places one in a command-line argument. Do not
substitute `git grep "$(cat .env)"` — that expands the secret into `argv` and
prints matches.

## Reporting

Open a GitHub issue describing the problem, without including secrets or
private screen content.