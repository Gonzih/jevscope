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
    var status = "unreachable"
    var models: [String] = []
    do {
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse {
            status = "HTTP \(http.statusCode)"
            if http.statusCode == 200,
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = json["models"] as? [[String: Any]] {
                models = list.compactMap { $0["name"] as? String }
            }
        }
    } catch { status = "error" }
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

case "decide":
    guard let app = arg("--app") else { fail("decide requires --app <bundleID>") }
    guard let goal = arg("--goal") else { fail("decide requires --goal") }
    guard let key = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"],
          !key.isEmpty else { fail("TYPESAFE_API_KEY not set", 2) }

    let backend = AXAdapter(appBundleID: app)
    let snap: Snapshot
    do { snap = try backend.snapshot(appBundleID: app, generation: 1) }
    catch { fail("snapshot: \(error)") }

    let ranked = CandidateSelection.rank(snap.elements, goal: goal, screens: screenRects())
    guard !ranked.isEmpty else { fail("no eligible candidates") }
    let kRequested = Int(arg("--k") ?? "24") ?? 24
    let kept = CandidateSelection.assignHandles(ranked, k: max(3, min(254, kRequested)))
    let handles = kept.map(\.handle)

    let client = JevClient(apiKey: key)
    let pre = JevClient.untrustedPreamble
    var opCrit: [String: Any] = [:]
    for o in Operation.allCases {
        opCrit[o.rawValue] = o == .none ? "No listed element advances the goal"
            : (o == .press ? "Press this element to advance the goal"
                           : "Replace this element's text value")
    }
    var tgtCrit: [String: Any] = ["none": "No listed element advances the goal"]
    for e in kept {
        tgtCrit[e.handle.raw] = "\(e.role) \"\(e.name ?? "")\" [\(e.actions.joined(separator: ","))]"
    }
    let state: [String: Any] = [
        "goal": goal, "application": snap.appBundleID,
        "frontWindow": snap.frontWindow ?? "",
        "elements": kept.map {
            Escaping.elementPayload($0, includeValue: true, includeFrame: true,
                                    includeActions: true)
        },
    ]
    let req = JevRequest(model: "jev-latest", state: AnyCodable(state), questions: [
        "operation": AnyCodable(["type": "choice",
            "instructions": "\(pre) Which single operation advances the goal?",
            "criteria": AnyCodable(opCrit)]),
        "target": AnyCodable(["type": "choice",
            "instructions": "\(pre) Which element should the operation target?",
            "criteria": AnyCodable(tgtCrit)]),
        "risk": AnyCodable(["type": "score",
            "instructions": "\(pre) How risky is performing this action?",
            "criteria": AnyCodable(["reversible", "hard to reverse", "irreversible"])]),
        "applied": AnyCodable(["type": "noul",
            "instructions": "\(pre) Does the screen already satisfy the goal?",
            "criteria": AnyCodable(["true": "The goal already appears satisfied",
                                    "false": "The goal is not yet satisfied"])]),
    ])

    let phase1: JevResponse
    do { phase1 = try await client.call(req) }
    catch { fail("jev phase1: \(error)") }
    print("// phase1 model=\(phase1.model) in=\(phase1.inputTokens) out=\(phase1.outputTokens)")
    print("// candidates=\(handles.count) captured=\(snap.elements.count) goal=\(goal)")

    switch Gate.phase1(phase1, candidateHandles: Set(handles)) {
    case .failure(let code):
        print("refused: \(code.rawValue)")
        if flag("--debug"), let tr = phase1.answers["target"],
           let probs = tr["probabilities"] as? [String: Any] {
            print("// debug target keys  : \(probs.keys.sorted())")
            print("// debug expected     : \((Set(handles.map(\.raw)).union(["none"])).sorted())")
            print("// debug target sum   : \(probs.values.compactMap { ($0 as? NSNumber)?.doubleValue }.reduce(0,+))")
            print("// debug target choice: \(tr["choice"] ?? "?") conf=\(tr["confidence"] ?? "?")")
        }
        if flag("--debug"), let op = phase1.answers["operation"] {
            print("// debug operation    : \(op)")
        }
    case .success(let (op, handle)):
        if op == .none {
            print("decision: no_action")
        } else if let element = kept.first(where: { $0.handle == handle }) {
            let args: String? = (op == .setValue) ? TextArgument.firstQuotedSpan(goal) : nil
            if op == .setValue, args == nil {
                print("refused: unsupportedAction (setValue with no quoted argument)")
            } else {
                let p2: JevRequest = JevRequest(
                    model: "jev-latest",
                    state: AnyCodable(["operation": op.rawValue, "role": element.role,
                                       "name": element.name ?? "",
                                       "arguments": args ?? "<none>", "goal": goal]),
                    questions: [
                        "bindingRisk": AnyCodable(["type": "score",
                            "instructions": "\(pre) How risky is \(op.rawValue) on THIS element with THESE arguments?",
                            "criteria": AnyCodable(["reversible", "hard to reverse", "irreversible"])]),
                        "argSafe": AnyCodable(["type": "noul",
                            "instructions": "\(pre) Is the argument text free of secrets?",
                            "criteria": AnyCodable(["true": "The argument text is free of secrets",
                                                    "false": "The argument text contains a secret"])]),
                    ])
                let r2: JevResponse
                do { r2 = try await client.call(p2) }
                catch { fail("jev phase2: \(error)") }
                switch Gate.phase2(r2) {
                case .failure(let code):
                    print("refused: \(code.rawValue)")
                case .success:
                    let token = Gate.token(generation: snap.generation,
                                           appLaunchID: snap.appLaunchID,
                                           primitive: op == .press ? .press : .setValue,
                                           handle: handle, arguments: args,
                                           questionVersion: "v1")
                    print("decision: act \(op.rawValue) \(handle.raw) \"\(element.name ?? "")\"")
                    print("approval-token: \(token)")
                    print("// NOTE: 'apply' is not implemented; this token cannot be redeemed.")
                }
            }
        }
    }

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