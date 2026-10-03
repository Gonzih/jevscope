# AX capability survey — read-only, 2026-10-02, macOS 27.0.1
# Validates SPEC §6.1 precondition for the setValue primitive.
# Nothing was written to any element.

app         role          actions                        AXValue  AXSelectedText  name
Safari      AXTextArea    AXPress,AXShowMenu,AXScroll..  YES     YES             What to Test
Safari      AXTextField   AXShowMenu,AXConfirm,AXShow..  YES     YES             -
TextEdit    AXTextField   AXShowMenu,AXConfirm           YES     no              -

## Findings
1. AXValue is settable on every text field surveyed -> the setValue
   precondition in SPEC 6.1 (AXUIElementIsAttributeSettable on kAXValue)
   is the correct, sufficient check.

2. CORRECTION: AXSelectedText is settable on BOTH Safari fields but NOT on
   the TextEdit field. An earlier probe reported it as categorically
   'not settable' from a single observation. Settability is per-element and
   must be queried, never assumed - which is exactly why SPEC 6.1 queries it.

3. Safari's AXTextField exposes AXConfirm. That is the submit primitive.
   SPEC 6.1 explicitly excludes submit from v1, so its presence is
   harmless here, but it confirms that an action-name list alone cannot be
   used to infer intent - a field offers Press/Confirm/ShowMenu together.
