// Renders SPEC.md §7.2's element-table line format from a REAL AX tree, to check
// the format is actually producible and token-affordable. Read-only.
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
    guard let v = attr(e, n) else { return false }
    if CFGetTypeID(v) == CFBooleanGetTypeID() { return CFBooleanGetValue(v as! CFBoolean) }
    return nil
}
func rect(_ e: AXUIElement) -> String? {
    guard let p = attr(e, kAXPositionAttribute as String), CFGetTypeID(p) == AXValueGetTypeID(),
          let s = attr(e, kAXSizeAttribute as String), CFGetTypeID(s) == AXValueGetTypeID()
    else { return nil }
    var pt = CGPoint.zero, sz = CGSize.zero
    let okP = withUnsafeMutableBytes(of: &pt) { AXValueGetValue(p as! AXValue, .cgPoint, $0.baseAddress!) }
    let okS = withUnsafeMutableBytes(of: &sz) { AXValueGetValue(s as! AXValue, .cgSize, $0.baseAddress!) }
    guard okP, okS else { return nil }
    return "\(Int(pt.x)),\(Int(pt.y)),\(Int(sz.width))x\(Int(sz.height))"
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
/// SPEC §7.1: AXIdentifier -> AXDescription -> AXTitle -> AXHelp
func name(_ e: AXUIElement) -> String? {
    str(e, kAXIdentifierAttribute) ?? str(e, kAXDescriptionAttribute)
        ?? str(e, kAXTitleAttribute) ?? str(e, kAXHelpAttribute)
}

struct Row { var line: String; var named: Bool; var actionable: Bool }

func walk(_ e: AXUIElement, path: [Int], into out: inout [Row], limit: Int) {
    guard out.count < limit else { return }
    let p = "/" + path.map(String.init).joined(separator: "/")
    let role = str(e, kAXRoleAttribute) ?? "?"
    let n = name(e)
    let acts = actions(e)
    let value = str(e, kAXValueAttribute).map { v -> String in
        let t = v.count > 24 ? String(v.prefix(24)) + "…" : v
        return "\"\(t.replacingOccurrences(of: "\n", with: " "))\""
    } ?? ""
    let tag = n.map { "\"\($0.replacingOccurrences(of: "\"", with: "'"))\"" } ?? "-"
    // SPEC §7.2 format
    let line = "[\(String(format: "%02d", out.count))] \(role) \(tag) | \(flag(e, kAXEnabledAttribute) == true ? "enabled" : "disabled") | \(rect(e) ?? "-") | actions: \(acts.joined(separator: ",")) | \(p)"
    out.append(Row(line: line, named: n != nil, actionable: !acts.isEmpty))
    for (i, c) in children(e).enumerated() { walk(c, path: path + [i], into: &out, limit: limit) }
}

let bundle = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "com.apple.finder"
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else {
    print("not running"); exit(0)
}
let root = AXUIElementCreateApplication(app.processIdentifier)
var rows: [Row] = []
walk(root, path: [], into: &rows, limit: 4000)

let namedOnly = rows.filter { $0.named && $0.actionable }
let header = "// SPEC.md §7.2 element table — real \(bundle) tree, \(rows.count) nodes"
print(header)
for r in namedOnly.prefix(24) { print(r.line) }

let body = namedOnly.prefix(24).map(\.line).joined(separator: "\n")
let approxTokens = Double(body.count) / 3.5
print("")
let totalChars = rows.reduce(into: 0) { acc, r in acc += r.line.count }
print("// full \(rows.count)-node table ≈ \(Int(Double(totalChars) / 3.5)) tokens")
print("// candidate rows available: \(namedOnly.count) of \(rows.count) nodes (\(100 * namedOnly.count / rows.count)% actionable+named)")