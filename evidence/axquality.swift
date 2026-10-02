// Measures how usable a real macOS AX tree is for a text-only decision model.
// Read-only: never presses, types, or mutates anything.
import AppKit
import ApplicationServices
import Foundation

struct Stat {
    var total = 0, named = 0, actionable = 0, interactive = 0
    var withDescription = 0, withIdentifier = 0, withValue = 0, enabled = 0
}

func stringAttr(_ e: AXUIElement, _ name: String) -> String? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success,
          let s = v as? String, !s.isEmpty
    else { return nil }
    return s
}

func boolAttr(_ e: AXUIElement, _ name: String) -> Bool? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success else { return nil }
    guard let b = v else { return false }            // present-but-null == false
    if CFGetTypeID(b) == CFBooleanGetTypeID() { return CFBooleanGetValue(b as! CFBoolean) }
    return nil
}

func children(_ e: AXUIElement) -> [AXUIElement] {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(e, kAXChildrenAttribute as CFString, &v) == .success,
          let arr = v as? NSArray
    else { return [] }
    let want = AXUIElementGetTypeID()
    var out: [AXUIElement] = []
    for case let obj as CFTypeRef in arr where CFGetTypeID(obj) == want {
        out.append(unsafeDowncast(obj, to: AXUIElement.self))
    }
    return out
}

func actionNames(_ e: AXUIElement) -> [String] {
    var v: CFArray?
    guard AXUIElementCopyActionNames(e, &v) == .success, let a = v as? [String] else { return [] }
    return a
}

func walk(_ e: AXUIElement, depth: Int, limit: Int, s: inout Stat) {
    guard s.total < limit, depth < 40 else { return }
    s.total += 1
    // The spec's §7.1 name resolution order, measured.
    let id = stringAttr(e, kAXIdentifierAttribute)
    let desc = stringAttr(e, kAXDescriptionAttribute)
    let title = stringAttr(e, kAXTitleAttribute)
    let help = stringAttr(e, kAXHelpAttribute)
    let name = id ?? desc ?? title ?? help
    if id != nil { s.withIdentifier += 1 }
    if desc != nil { s.withDescription += 1 }
    if title != nil { s.withValue += 1 }
    if name != nil { s.named += 1 }
    if boolAttr(e, kAXEnabledAttribute) == true { s.enabled += 1 }
    let acts = actionNames(e)
    if !acts.isEmpty { s.actionable += 1 }
    if acts.contains(kAXPressAction as String) { s.interactive += 1 }
    for c in children(e) { walk(c, depth: depth + 1, limit: limit, s: &s) }
}


print("app\tbundleID\tpid\tnodes\tnamed%\tident%\tdesc%\ttitle%\tenabled%\tactionable%\tpress%")
print("# name resolution order: AXIdentifier -> AXDescription -> AXTitle -> AXHelp")

let targets: [(String, String)] = [
    ("Finder", "com.apple.finder"),
    ("System Settings", "com.apple.systempreferences"),
    ("Safari", "com.apple.Safari"),
    ("Terminal", "com.apple.Terminal"),
    ("Notes", "com.apple.Notes"),
    ("Mail", "com.apple.mail"),
    ("Calendar", "com.apple.iCal"),
    ("TextEdit", "com.apple.TextEdit"),
    ("Preview", "com.apple.Preview"),
    ("Music", "com.apple.Music"),
]

var rows: [(String, Int, Int, Int, Int, Int, Int)] = []
for (label, bundle) in targets {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else {
        print("\(label)\t\(bundle)\t-\tNOT RUNNING")
        continue
    }
    let appEl = AXUIElementCreateApplication(app.processIdentifier)
    var s = Stat()
    walk(appEl, depth: 0, limit: 6000, s: &s)
    guard s.total > 0 else {
        print("\(label)\t\(bundle)\t\(app.processIdentifier)\t0\tEMPTY TREE")
        continue
    }
    func pct(_ n: Int) -> Int { 100 * n / s.total }
    print("\(label)\t\(bundle)\t\(app.processIdentifier)\t\(s.total)\t\(pct(s.named))\t\(pct(s.withIdentifier))\t\(pct(s.withDescription))\t\(pct(s.withValue))\t\(pct(s.enabled))\t\(pct(s.actionable))\t\(pct(s.interactive))")
    rows.append((label, s.total, pct(s.named), pct(s.withIdentifier), pct(s.withDescription), pct(s.withValue), pct(s.interactive)))
}

if !rows.isEmpty {
    let n = rows.count
    print("\n# MEAN across \(n) running apps:")
    print("# nodes=\(rows.reduce(0){$0+$1.1}/n)  named%=\(rows.reduce(0){$0+$1.2}/n)  identifier%=\(rows.reduce(0){$0+$1.3}/n)  description%=\(rows.reduce(0){$0+$1.4}/n)  title%=\(rows.reduce(0){$0+$1.5}/n)  pressable%=\(rows.reduce(0){$0+$1.6}/n)")
}