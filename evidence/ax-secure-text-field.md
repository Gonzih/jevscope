# Secure text fields are not distinguishable through AX — verified 2026-10-02

SPEC §6.1b excluded "`AXSecureTextField` always". That role **does not exist**.

## Probes

| symbol | result |
|---|---|
| `kAXSecureTextFieldRole` | **absent** — no such constant in `AXAttributeConstants.h` (macOS 27 SDK); the only "secure" hit is prose in a doc comment |
| `kAXSecureFieldRole` | absent |
| `NSAccessibilityIsSecureTextFieldAttribute` | **absent** — compiler: "cannot find in scope"; not declared in the AppKit headers |
| `NSSecureTextField.accessibilityRole()` | reports the same `AXTextField` role as `NSTextField` |

## Consequence

macOS exposes **no role and no standard attribute** that distinguishes a secure
text field from an ordinary one. An `AXUIElement` for a password field is
indistinguishable from one for a search box.

This matters because `setValue` writes operator-supplied text into a field. If
the target is a password field, jevscope cannot tell, and §5.4's `argSafe` gate
judges the *argument text*, not the *destination*.

## Spec response

1. The nonexistent `AXSecureTextField` role is removed from §6.1b.
2. The limitation is stated rather than papered over: AX cannot identify a
   secure field, so this is a **disclosed residual risk**, not a closed one.
3. `setValue` additionally requires that the target is **not** the currently
   focused UI element (`kAXFocusedAttribute == true`), because password prompts
   take focus. This is a mitigation, not a guarantee: a pre-focused password
   field can still be written to.

## UNVERIFIED

Whether any app sets a distinguishing `kAXSubroleAttribute` on a secure field was
not tested; no such convention is documented in the SDK. No claim is made either
way, and v1 does not rely on one.
