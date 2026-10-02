// Tests a concrete candidate-ranking function against real AX trees.
// Read-only: presses nothing, mutates nothing.
import AppKit
import ApplicationServices
import Foundation

func attr(_ e: AXUIElement, _ n: String) -> CFTypeRef? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success else { return nil }
    return v
}
func str(_ e: AXUIElement, _ n: String) -> String? {
    guard let v = attr(e, n) as? String, !v.isEmpty else { return nil }
    return v
}
func flag(_ e: AXUIElement, _ n: String) -> Bool? {
    guard let v = attr(e, n) else { return nil }
    if CFGetTypeID(v) == CFBooleanGetTypeID() { return CFBooleanGetValue(v as! CFBoolean) }
    return nil
}
func rect(_ e: AXUIElement) -> CGRect? {
    guard let p = attr(e, kAXPositionAttribute as String), CFGetTypeID(p) == AXValueGetTypeID(),
          let s = attr(e, kAXSizeAttribute as String), CFGetTypeID(s) == AXValueGetTypeID()
    else { return nil }
    var pt = CGPoint.zero, sz = CGSize.zero
    let a = withUnsafeMutableBytes(of: &pt) { AXValueGetValue(p as! AXValue, .cgPoint, $0.baseAddress!) }
    let b = withUnsafeMutableBytes(of: &sz) { AXValueGetValue(s as! AXValue, .cgSize, $0.baseAddress!) }
    guard a, b else { return nil }
    return CGRect(origin: pt, size: sz)
}
func children(_ e: AXUIElement) -> [AXUIElement] {
    guard let arr = attr(e, kAXChildrenAttribute as String) as? NSArray else { return [] }
    let want = AXUIElementGetTypeID()
    var out: [AXUIElement] = []
    for case let o as CFTypeRef in arr where CFGetTypeID(o) == want {
        out.append(unsafeDowncast(o, to: AXUIElement.self))
    }
    return out
}
func actions(_ e: AXUIElement) -> [String] {
    var v: CFArray?
    guard AXUIElementCopyActionNames(e, &v) == .success, let a = v as? [String] else { return [] }
    return a
}

struct Cand {
    var path: [Int]
    var role: String
    var name: String
    var acts: [String]
    var enabled: Bool?
    var rect: CGRect?
    var synthetic: Bool   // AXIdentifier looks like AppKit's private _NS:<n>
}

let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

// Hard filter: an element is a CANDIDATE only if it is named, actionable,
// not an AppKit-internal placeholder, and geometrically on screen.
func isCandidate(_ c: Cand) -> Bool {
    guard !c.name.isEmpty, !c.acts.isEmpty else { return false }
    guard !c.synthetic else { return false }
    if let r = c.rect, let e = c.enabled {
        if e, r.width > 0, r.height > 0, screen.intersects(r) { return true }
        return false
    }
    return c.enabled == true
}

// Ranking: deterministic, explainable. Higher is better.
func score(_ c: Cand, goalTerms: Set<String>) -> Double {
    var s = 0.0
    s += c.enabled == true ? 4.0 : 0.0
    s += 1.0                                   // actionable (guaranteed by filter)
    if c.name.count >= 3 { s += 1.0 }          // real label, not a stub
    let lower = c.name.lowercased()
    if goalTerms.contains(where: { lower.contains($0) }) { s += 3.0 }
    if c.acts.contains(kAXPressAction as String) { s += 2.0 }
    if c.acts.contains(kAXShowMenuAction as String) { s += 0.5 }
    if let r = c.rect, r.width * r.height > 40 * 20 { s += 0.5 }   // not a hairline
    return s
}

func walk(_ e: AXUIElement, path: [Int], into out: inout [Cand], limit: Int) {
    guard out.count < limit else { return }
    let role = str(e, kAXRoleAttribute) ?? "?"
    // SPEC §7.1 name order — identifier LAST (it is often _NS:<n>)
    let desc = str(e, kAXDescriptionAttribute)
    let title = str(e, kAXTitleAttribute)
    let help = str(e, kAXHelpAttribute)
    let ident = str(e, kAXIdentifierAttribute)
    let name = desc ?? title ?? help ?? ident ?? ""
    let synth = (ident.map { $0.hasPrefix("_NS:") } ?? false) && desc == nil && title == nil
    out.append(Cand(path: path, role: role, name: name, acts: actions(e),
                    enabled: flag(e, kAXEnabledAttribute), rect: rect(e), synthetic: synth))
    for (i, c) in children(e).enumerated() { walk(c, path: path + [i], into: &out, limit: limit) }
}

for bundle in ["com.apple.finder", "com.apple.Safari", "com.apple.TextEdit"] {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { continue }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    var all: [Cand] = []
    walk(root, path: [], into: &all, limit: 4000)

    let actionable = all.filter { !$0.acts.isEmpty }.count
    let named = all.filter { $0.name.count >= 3 }.count
    let synthCount = all.filter(\.synthetic).count
    let cands = all.filter(isCandidate)

    print("=== \(bundle) — \(all.count) nodes")
    print("  actionable            \(actionable)")
    print("  named (>=3 chars)     \(named)")
    print("  AppKit-internal only  \(synthCount)")
    print("  CANDIDATES after hard filter  \(cands.count)")

    for goal in ["archive", "delete", "search"] {
        let terms: Set<String> = [goal]
        var scored: [(Cand, Double)] = []
        for c in cands { scored.append((c, score(c, goalTerms: terms))) }
        scored.sort { a, b in
            if a.1 == b.1 { return a.0.name < b.0.name }
            return a.1 > b.1
        }
        let ranked = scored
        let top = ranked.prefix(5).map { "\($0.0.name.isEmpty ? "<unnamed>" : $0.0.name)[\($0.0.role)]" }
        print("  goal '\(goal)': top5 = \(top.joined(separator: ", "))")
        let chars = ranked.prefix(24).reduce(into: 0) { acc, c in acc += c.0.name.count + c.0.role.count + 40 }
        print("     top-24 token cost ≈ \(Int(Double(chars) / 3.5)) tokens")
    }
    print("")
}