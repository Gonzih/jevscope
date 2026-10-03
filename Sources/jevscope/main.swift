import AXKit
import Foundation

let version = "jevscope 0.1.0 (spec v6)"

// Subcommands are wired incrementally; `doctor` and `tree` land first.
let args = Array(CommandLine.arguments.dropFirst())
let sub = args.first ?? "help"

switch sub {
case "version":
    print(version)
default:
    print("""
    \(version)

    USAGE
      jevscope doctor                     AX trust + Jev reachability
      jevscope tree --app <bundleID>      snapshot -> element table
      jevscope decide --app … --goal "…"  decision + approval token (no side effects)
      jevscope apply --approve <token>    allowlisted primitive only
      jevscope replay --corpus <dir>      deterministic, offline
      jevscope eval-live --corpus <dir>   measured, pinned

    See SPEC.md for the contract. Subcommand '\(sub)' is not implemented yet.
    """)
}