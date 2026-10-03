import AppKit
import AXKit
import Foundation

let version = "jevscope 0.1.0 (spec v6, Codex READY @ 287d22e)"

func arg(_ name: String) -> String? {
    let a = Array(CommandLine.arguments.dropFirst())
    guard let i = a.firstIndex(of: name), i + 1 < a.count else { return nil }
    return a[i + 1]
}

func flag(_ name: String) -> Bool {
    CommandLine.arguments.dropFirst().contains(name)
}

/// Union of all attached displays, as "x,y,WxH" keys for the §7.1 geometric filter.
func screenRects() -> [CGRect] {
    NSScreen.screens.map(\.visibleFrame)
}

func fail(_ message: String, _ code: Int32 = 1) -> Never {
    FileHandle.standardError.write(("jevscope: " + message + "\n").data(using: .utf8)!)
    exit(code)
}

let sub = CommandLine.arguments.dropFirst().first ?? "help"

switch sub {

case "version":
    print(version)

case "doctor":
    // SPEC §12: AX trust + Jev reachability; never echoes the key.
    var ok = true
    let trusted = AXIsProcessTrusted()
    print("ax.trusted            : \(trusted)")
    if !trusted { ok = false }

    guard let key = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"],
          !key.isEmpty else {
        print("jev.key               : MISSING (set TYPESAFE_API_KEY or use .env)")
        fail("no API key", 2)
    }
    print("jev.key               : present (\(key.count) chars, not shown)")

    // Live reachability: models list only. No state, no inference call.
    var req = URLRequest(url: URL(string: "https://api.typesafe.ai/v1/models")!)
    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    let sem = DispatchSemaphore(value: 0)
    var status = "unreachable"
    var models: [String] = []
    URLSession.shared.dataTask(with: req) { data, response, _ in
        if let http = response as? HTTPURLResponse {
            status = "HTTP \(http.statusCode)"
            if http.statusCode == 200, let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = json["models"] as? [[String: Any]] {
                models = list.compactMap { $0["name"] as? String }
            }
        }
        sem.signal()
    }.resume()
    _ = sem.wait(timeout: .now() + 15)
    print("jev.models            : \(status) \(models.joined(separator: ", "))")
    if !status.contains("200") { ok = false }
    print(ok ? "\ndoctor: OK" : "\ndoctor: NOT READY")
    exit(ok ? 0 : 1)

case "tree":
    guard let app = arg("--app") else { fail("tree requires --app <bundleID>") }
    let backend = AXAdapter(appBundleID: app)
    let snap: Snapshot
    do { snap = try backend.snapshot(appBundleID: app, generation: 1) }
    catch { fail("snapshot: \(error)") }
    let goal = arg("--goal") ?? ""
    let rendered = BudgetLadder.render(snapshot: snap, goal: goal,
                                      screens: screenRects()) { kept, opts in
        let payload: [String: Any] = [
            "application": snap.appBundleID,
            "frontWindow": snap.frontWindow ?? "",
            "elements": kept.map {
                Escaping.elementPayload($0, includeValue: opts.includeValue,
                                        includeFrame: opts.includeFrame,
                                        includeActions: opts.includeActions)
            },
        ]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }
    guard let r = rendered else { fail("budgetExhausted") }
    print("// app=\(snap.appBundleID) window=\(snap.frontWindow ?? "-")")
    print("// captured=\(snap.elements.count) completeness=\(snap.completeness.rawValue)"
          + " k=\(r.options.k) stateBytes=\(r.stateBytes)")
    print(r.table)

default:
    print("""
    \(version)

    USAGE
      jevscope doctor                     AX trust + Jev reachability
      jevscope tree --app <bundleID>      snapshot -> element table
      jevscope decide --app … --goal "…"  decision + approval token
      jevscope apply --approve <token>    allowlisted primitive only
      jevscope replay --corpus <dir>      deterministic, offline
      jevscope eval-live --corpus <dir>   measured, pinned

    Subcommand '\(sub)' is not implemented yet.
    """)
}