# AX walk latency — measured 2026-10-02, macOS 27.0.1
# Bounds `decide` latency and the 120s approval window (SPEC 6.2).
# 5 runs each, full recursive walk, messaging timeout 2.0s.

app                      runs  median_ms  max_ms  nodes
com.apple.finder           5         28     128    511
com.apple.Safari           5         30     240    785
com.apple.TextEdit         5         18     102    470
com.apple.Notes            5       3521    4248   1811

## Findings
1. Walk cost is NOT uniform. Notes is ~2.3x the nodes of Finder but
   ~117x the time: 3.5s vs 28ms median. Per-node IPC cost differs by
   roughly two orders of magnitude between apps (~0.055 ms/node Finder,
   ~1.94 ms/node Notes).

2. This makes SPEC 8.2's node-cap and depth guards load-bearing rather
   than decorative. Without a cap, a slow tree dominates decide latency.

3. Even the worst case is acceptable against the 120s approval expiry:
   ~4.2s walk + ~0.4s Jev round trip leaves >115s of margin. The expiry is
   not threatened by walk latency.

4. UNVERIFIED: whether Notes slowness is transient (app state) or stable.
   Only 5 samples per app, no warm/cold discipline.
