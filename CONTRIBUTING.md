# Contributing

## Setup

```bash
git clone https://github.com/Gonzih/jevscope
cd jevscope
cp .env.example .env      # then set TYPESAFE_API_KEY
swift build
```

## Ground rules

1. **Fail closed.** Every guard that prevents a wrong action on a real desktop
   is load-bearing. Replacing one with something weaker needs an explanation in
   the PR, not a judgement call.
2. **Do not claim atomicity.** The Accessibility API cannot combine snapshot
   verification with the target's action. SPEC §6.5 documents the residual race.
   A better fingerprint is not a transaction, and a short TTL is not one either.
3. **No unverified claims.** "This works" needs a command and its real output.
   A green build does not prove an AX tree is correct.
4. **`swift test` is offline.** Tests use `ScriptedBackend` and recorded Jev
   responses. They must not reach the network or touch a real AX tree.
   Live checks are separate, explicit commands.

## Artifacts — read this before adding fixtures

- **Never commit** raw captures, traces, or anything containing real screen
   text. They live under `~/.local/share/jevscope/` and are git-ignored.
- **Do commit** the sanitized corpus (`corpus/v1/*.json`), whose names and
  values are placeholder-substituted (`<LABEL_07>`). It is required for
  `replay` to work for anyone else.
- Capture a real tree, then sanitize it. Do not "sanitize" by deleting a line
  here and there — the substitution must be total.

## Before opening a PR

```bash
swift build
swift test
python3 scripts/check-secrets.py
```

Then exercise the real path and paste the output:

```bash
.build/debug/jevscope doctor
.build/debug/jevscope tree --app com.apple.Safari
.build/debug/jevscope replay --corpus corpus/v1
```

Use **bundle identifiers**, not app names — there is no name lookup and so no
ambiguity handling. A pipe to `head` is inspection, not proof of a complete
capture; check the element count the command reports.

## Review gate

Spec changes and validation runs go through an independent Codex review
dispatched via ATC. Expect to be asked for evidence, not assertions. The v1
review found seven real blockers, two of which were defects in claims this
project had already published.