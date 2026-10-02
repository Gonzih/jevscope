# `AXUIElementPerformAction` timeout semantics — header-verified

Source: macOS 27 SDK,
`System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/Headers/AXUIElement.h`
lines 315-331, quoted verbatim:

> It is possible to receive the `kAXErrorCannotComplete` error code from this
> function because accessible applications often need to perform some sort of
> modal processing inside their action callbacks and they may not return within
> the timeout value set by the accessibility API. **This does not necessarily
> mean that the function has failed**, however. If appropriate, your assistive
> application can try to call this function again. Also, you may be able to
> increase the timeout value (see `AXUIElementSetMessagingTimeout`).

## Consequence for jevscope

1. `kAXErrorCannotComplete` from `AXUIElementPerformAction` is **not** a proven
   failure and **not** a proven success. It is an **unknown execution outcome**.
   SPEC.md §7.3 previously mapped any `axError` to "refuse", which is wrong: it
   conflates "we chose not to act" with "we acted and cannot tell".
2. **Never auto-retry a perform.** Apple's suggested retry is safe only for
   idempotent reads. Retrying a press on a destructive control can execute it
   twice. jevscope retries at most *reads*; performs are attempted once.
3. An unknown outcome is reported as its own terminal state, `unknownOutcome`,
   requiring human adjudication — not folded into the refusal taxonomy.
4. `AXUIElementSetMessagingTimeout` semantics (lines 386-402): a positive value
   on the **system-wide** element sets the global timeout for the process; `0`
   on system-wide *resets to the default*, and `0` on any other element makes it
   inherit the current global value. Use a positive value on system-wide.
