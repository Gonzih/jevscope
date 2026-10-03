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

print("Does a real secure field expose kAXSecureTextFieldSubrole?")
print("app\trole\tsubrole\ttitle")
var found = 0
for bundle in ["com.apple.Safari", "com.apple.finder", "com.apple.TextEdit", "com.apple.Notes",
               "com.apple.systempreferences", "com.apple.mail"] {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { continue }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    var n = 0
    func walk(_ e: AXUIElement) {
        guard n < 4000, found < 12 else { return }
        let role = str(e, kAXRoleAttribute) ?? ""
        let sub = str(e, kAXSubroleAttribute)
        if role == kAXTextFieldRole as String || role == kAXTextAreaRole as String {
            if sub != nil || found < 6 {
                n += 1
                if sub != nil { found += 1 }
                let t = str(e, kAXTitleAttribute) ?? "-"
                if found <= 12 { print("\(bundle)\t\(role)\t\(sub ?? "-")\t\(t)") }
            }
        }
        for c in children(e) { walk(c) }
    }
    walk(root)
}
print("\nfields with a non-nil subrole found: \(found)")
