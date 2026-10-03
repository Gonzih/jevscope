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
func children(_ e: AXUIElement) -> [AXUIElement] {
    guard let arr = attr(e, kAXChildrenAttribute as String) as? NSArray else { return [] }
    let w = AXUIElementGetTypeID()
    var o: [AXUIElement] = []
    for case let x as CFTypeRef in arr where CFGetTypeID(x) == w { o.append(unsafeDowncast(x, to: AXUIElement.self)) }
    return o
}
func actions(_ e: AXUIElement) -> [String] {
    var v: CFArray?
    guard AXUIElementCopyActionNames(e, &v) == .success, let a = v as? [String] else { return [] }
    return a
}
func isSettable(_ e: AXUIElement, _ attr: String) -> String {
    var b = DarwinBoolean(false)
    let err = AXUIElementIsAttributeSettable(e, attr as CFString, &b)
    if err != .success { return "err(\(err))" }
    return b.boolValue ? "YES" : "no"
}

print("Read-only capability survey. Nothing is written.\n")
print("app\trole\tactions\tAXValueSettable\tAXSelectedTextSettable\tname")
for bundle in ["com.apple.finder", "com.apple.Safari", "com.apple.TextEdit"] {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { continue }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    var found = 0
    func walk(_ e: AXUIElement) {
        guard found < 6 else { return }
        let role = str(e, kAXRoleAttribute) ?? ""
        let acts = actions(e)
        if role == kAXTextFieldRole as String || role == kAXTextAreaRole as String {
            found += 1
            print("\(bundle)\t\(role)\t\(acts.joined(separator: ","))\t\(isSettable(e, kAXValueAttribute as String))\t\(isSettable(e, kAXSelectedTextAttribute as String))\t\(str(e, kAXTitleAttribute) ?? "-")")
        }
        for c in children(e) { walk(c) }
    }
    walk(root)
}
