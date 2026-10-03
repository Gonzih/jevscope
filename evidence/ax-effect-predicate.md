# Effect predicate feasibility — read-only, 2026-10-02, macOS 27.0.1
# SPEC 6.4 confirms a dispatch only by observing a specified state change.
# This checks whether that state is actually readable, before pressing anything.

app          role           name                                     AXValue          AXSelected
Finder       AXRadioButton  icon view                               Number(1)        unsupported
Finder       AXRadioButton  list view                               Number(0)        unsupported
Finder       AXRadioButton  column view                             Number(0)        unsupported
Finder       AXRadioButton  gallery view                            Number(0)        unsupported
Finder       AXMenuButton   Group                                   UNREADABLE       unsupported
Safari       AXPopUpButton  Apps menu                               String()         Bool(false)
Safari       AXRadioButton  (unnamed)                               Bool(true)       Bool(true)
Safari       AXRadioButton  (unnamed)                               Bool(false)      Bool(false)
Safari       AXMenuButton   Tab Group picker                        UNREADABLE       unsupported
TextEdit     AXMenuButton   column view                             UNREADABLE       unsupported
TextEdit     AXPopUpButton   Where:                                 String(...)       unsupported

## Findings
1. Toggles DO expose a comparable state value: Finder radios as CFNumber
   0/1, Safari radios as CFBoolean. So 'AXValue changed from the
   pre-dispatch value' is a real, workable confirmation for press on
   AXRadioButton and AXCheckBox.
2. AXMenuButton AXValue was UNREADABLE in this sample. That does **not** prove
   that no confirmation predicate exists for it: AXPopUpButton in the same run
   exposed a readable String value, so apps vary in what they publish. The
   honest statement is that a *generic* AXValue predicate is unavailable for
   that role, which is why SPEC 6.4 permits a per-target, operator-registered
   predicate and falls back to unknownOutcome when none applies.
   (An earlier revision of this file inferred "NO reliable predicate exists"
   from the unreadable value. That inference was wrong; Codex caught it.)
3. CORRECTION: kAXSelectedValueAttribute does NOT exist in the macOS 27
   SDK (compiler: cannot find in scope). kAXSelectedAttribute does, but is
   itself unsupported on most elements. Any implementation attempting this
   must not assume either constant is present.
