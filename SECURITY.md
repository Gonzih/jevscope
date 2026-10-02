# Security

## jevscope drives your real desktop

This tool reads the macOS Accessibility tree of your frontmost application and
performs real actions on it — pressing buttons, typing text, opening menus.
It is not a sandbox and not a simulator. A bug or a wrong decision reaches your
actual running applications.

## Treat the Accessibility permission as root

Granting Accessibility to jevscope lets it read and control every application
you can use. Anyone holding this binary on your machine, and any process that
can read this repository's `.env`, inherits that reach.

- Run it on a machine where you are willing to grant that scope.
- Do not run it against a machine holding credentials you care about while
  exploring.
- Remove the grant in System Settings → Privacy & Security → Accessibility to
revoke it. That is the only reliable kill switch.

## Secrets

The only secret is `TYPESAFE_API_KEY` in `.env`, which is git-ignored. The key
is read from the environment, is sent only to `https://api.typesafe.ai`, and
is never logged, printed, or written to a trace file. A recorded trace stores
the request *body* and the response *body* — never headers.

Everything jevscope sends to TypeSafe is screen content from the Accessibility
tree: window titles, control labels, and text field values. **Text you can see
in a window is sent off this machine to a third-party API.** Do not use it
against windows holding credentials, private messages, or regulated data
unless you accept that transfer.

## Fail-closed by design

jevscope refuses to act rather than guessing. It will not:

- act on a Jev answer below the configured confidence threshold
- act when the accessibility tree is empty, truncated, or ambiguous
- resolve a model-cited element handle to more than one element
- perform an action on an element whose role does not support that action

## Reporting

Open a GitHub issue describing the problem without including secrets or
private screen content.
