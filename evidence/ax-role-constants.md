# Standard AX role and subrole vocabulary — counted from the SDK 2026-10-02

SPEC §10.1 passes a `role` through a replay-fixture transformation only if it is
a standard role string. That check needs an exact, verified list.

## Counts (macOS 27 SDK, `AXRoleConstants.h`)

| symbol class | count |
|---|---|
| `kAX*Role` constants | **58** |
| distinct `CFSTR` values they resolve to | **58** |
| `kAX*Subrole` constants | **37** |

All 58 role values begin with `AX` and are uppercase — verified by filtering out
anything that does not match `^AX[A-Z]`, which returned nothing. That prefix is
therefore a cheap secondary guard, but the authoritative test is membership of
the declared set, because AX explicitly permits **custom** role strings and those
are exactly the ones that may embed private content.

Roles and subroles are **separate namespaces**. `kAXSecureTextFieldSubrole` is a
subrole, not a role; conflating them is what produced v4's incorrect "AX cannot
identify a password field" conclusion.

## Correction

SPEC §10.1 previously said "57 standard `kAX*Role` strings". That number was
inherited from an earlier probe report and was **off by one**. It is 58. Caught
while re-verifying an inherited claim rather than trusting it.
