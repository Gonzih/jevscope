# Secure text fields: the subrole exists — corrected 2026-10-02

SPEC §6.1b concerns identifying a password field so `setValue` does not write
into one. **This file previously concluded that AX cannot do it. That was wrong.**

## Correction

The correct API is a **subrole**, not a role.

| symbol | location | result |
|---|---|---|
| `kAXSecureTextFieldSubrole` | `AXRoleConstants.h:408` — `CFSTR("AXSecureTextField")` | **exists** |
| `kAXSubroleAttribute` | `AXAttributeConstants.h:46` | **exists** |
| `kAXSecureTextFieldRole` | — | does not exist (correct in both revisions) |
| `NSAccessibilityIsSecureTextFieldAttribute` | — | does not exist (correct in both revisions) |
| `NSAccessibilitySecureTextFieldSubrole` | `NSAccessibilityConstants.h:573` | **exists** |

The earlier revision searched only `AXAttributeConstants.h`, missed
`AXRoleConstants.h`, and concluded from the absence of a *role* constant that AX
had no secure-field classification. Codex caught it. The absence of
`kAXSecureTextFieldRole` is true and was never the relevant question.

`NSSecureTextField` does report the ordinary `AXTextField` role — so the
discriminator is carried one level down, in the subrole.

## The mechanism is verified live

Subroles are readable on real elements:

| app | role | subrole |
|---|---|---|
| TextEdit | `AXTextField` | **`AXSearchField`** |
| Safari | `AXTextField` / `AXTextArea` | none |
| Finder | `AXTextField` | none |
| Notes | `AXTextField` | none |

TextEdit populating `AXSearchField` confirms `kAXSubroleAttribute` works on
real elements; `AXSearchField` is the exact analogue of what
`AXSecureTextField` would be for a password field.

## What is still UNVERIFIED

No password field was on screen during testing, so **whether any specific app
actually populates `kAXSecureTextFieldSubrole` is unverified.** Population is
app-dependent: it is an app's or framework's choice, and a custom control may
publish no subrole at all.

Therefore, in SPEC §6.1b:

- the subrole check is **necessary but not sufficient**;
- it is paired with a focused-element refusal (`kAXFocusedAttribute == true`),
  since password prompts take focus;
- neither claim is that secure fields are reliably detectable.

Reproduce the mechanism probe with `evidence/axsubrole.swift`.