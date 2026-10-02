// Can a re-read attribute fingerprint detect that an AXUIElementRef now refers
// to a different control? Read-only: presses nothing, mutates nothing.
import AppKit
import ApplicationServices
import Foundation

struct Fingerprint {
    var role: String?, subrole: String?, identifier: String?, title: String?
    var description: String?, value: String?, frame: String?, enabled: Bool?
}

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
    guard let p = attr(e, kAXPositionAttribute as String),
          CFGetTypeID(p) == AXValueGetTypeID() else { return nil }
    guard let s = attr(e, kAXSizeAttribute as String),
          CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
    var pt = CGPoint.zero, sz = CGSize.zero
    let okP = withUnsafeMutableBytes(of: &pt) { AXValueGetValue(p as! AXValue, .cgPoint, $0.baseAddress!) }
    let okS = withUnsafeMutableBytes(of: &sz) { AXValueGetValue(s as! AXValue, .cgSize, $0.baseAddress!) }
    guard okP, okS else { return nil }
    return String(format: "%.0f,%.0f,%.0fx%.0f", pt.x, pt.y, sz.width, sz.height)
}

func fingerprint(_ e: AXUIElement) -> Fingerprint {
    Fingerprint(
        role: str(e, kAXRoleAttribute), subrole: str(e, kAXSubroleAttribute),
        identifier: str(e, kAXIdentifierAttribute), title: str(e, kAXTitleAttribute),
        description: str(e, kAXDescriptionAttribute), value: str(e, kAXValueAttribute),
        frame: rect(e), enabled: flag(e, kAXEnabledAttribute))
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

func walk(_ e: AXUIElement, depth: Int, limit: Int, _ body: (AXUIElement, Fingerprint) -> Bool) -> Bool {
    guard depth < 30 else { return true }
    guard body(e, fingerprint(e)) else { return false }
    var n = 0
    for c in children(e) where n < limit {
        n += 1
        if !walk(c, depth: depth + 1, limit: limit, body) { return false }
    }
    return true
}

let bundle = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "com.apple.finder"
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else {
    print("app \(bundle) not running"); exit(0)
}
let root = AXUIElementCreateApplication(app.processIdentifier)

// Collect pressable elements.
var targets: [(AXUIElement, Fingerprint)] = []
_ = walk(root, depth: 0, limit: 4000) { e, _ in
    if targets.count < 40, str(e, kAXRoleAttribute) == kAXButtonRole {
        targets.append((e, fingerprint(e)))
    }
    return true
}
print("collected \(targets.count) AXButton elements from \(bundle)")

// Re-read after a delay and diff. Also compare the whole element set to detect
// wholesale tree churn.
func row(_ f: Fingerprint) -> [String] {
    [f.role ?? "-", f.subrole ?? "-", f.identifier ?? "-", f.title ?? "-",
     f.description ?? "-", f.value ?? "-", f.frame ?? "-", String(f.enabled.map(String.init) ?? "-")]
}
let headers = ["role", "subrole", "identifier", "title", "description", "value", "frame", "enabled"]
print("elements: " + headers.joined(separator: "\t"))

var fieldDrift = [Int](repeating: 0, count: headers.count)
let samples = 5
for _ in 0..<samples {
    for (e, orig) in targets {
        let now = row(fingerprint(e)), was = row(orig)
        for i in 0..<headers.count where now[i] != was[i] { fieldDrift[i] += 1 }
    }
    usleep(400_000)
}
let n = max(1, samples * targets.count)
print("\n# drift over \(samples) re-reads of \(targets.count) elements (\(samples * targets.count) comparisons)")
for (i, h) in headers.enumerated() {
    let pct = 100 * fieldDrift[i] / n
    print("#   \(h.padding(toLength: 12, withPad: " ", startingAt: 0)) drifted \(pct)%")
}

// Which subset is stable enough to be a TOCTOU guard?
let stableIdx = [0, 1, 2, 3, 4].filter { fieldDrift[$0] == 0 }
print("\nSTABLE fields (0% drift): \(stableIdx.map { headers[$0] }.joined(separator: ", "))")
print("VOLATILE fields: \(fieldDrift.enumerated().filter { $0.element > 0 }.map { "\($0.element)=\(headers[$0.element])" }.joined(separator: ", "))")