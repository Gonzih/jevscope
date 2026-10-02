# Contributing

## Setup

```bash
git clone https://github.com/Gonzih/jevscope
cd jevscope
cp .env.example .env   # then set TYPESAFE_API_KEY
swift build
```

## Ground rules

1. **Fail closed.** Every guard that prevents a wrong action on a real desktop
   is load-bearing. If you remove one, you must have a replacement that is at
   least as strict, and you must say so in the PR.
2. **No unverified claims.** "This works" needs a command and its real output.
   A green build is not proof that the accessibility tree is correct.
3. **Tests must not touch the live desktop.** Unit tests use fixtures. Anything
   that needs a real Accessibility tree is an explicit, separately invoked
   smoke command, not part of `swift test`.
4. **Never commit `.env`, traces, or captured trees.** `.gitignore` covers
   these; keep it that way.

## Before opening a PR

```bash
swift build
swift test
```

Then exercise the real path and paste the output:

```bash
.build/debug/jevscope tree --app Safari | head -40
.build/debug/jevscope doctor
```

## Review gate

Spec changes and validation runs go through an independent Codex review
dispatched via ATC. Expect to be asked for evidence, not assertions.
