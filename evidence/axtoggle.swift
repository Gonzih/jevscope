import AppKit
import ApplicationServices
import Foundation

func attr(_ e: AXUIElement, _ n: String) -> CFTypeRef? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success else { return nil }
    return v
}
func children(_ e: AXUIElement) -> [AXUIElement] {
    guard let arr = attr(e, kAXChildrenAttribute as String) as? NSArray else { return [] }
    let w = AXUIElementGetTypeID()
    var o: [AXUIElement] = []
    for case let x as CFTypeRef in arr where CFGetTypeID(x) == w { o.append(unsafeDowncast(x, to: AXUIElement.self)) }
    return o
}
func describe(_ e: AXUIElement) -> String {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(e, kAXValueAttribute as CFString, &v) == .success else { return "UNREADABLE" }
    guard let x = v else { return "nil" }
    if let s = x as? String { return "String(\(s))" }
    if CFGetTypeID(x) == CFBooleanGetTypeID() { return "Bool(\(CFBooleanGetValue(x as! CFBoolean)))" }
    if CFGetTypeID(x) == CFNumberGetTypeID() { return "Number(\(x))" }
    return "other(typeID \(CFGetTypeID(x)))"
}

let toggles = Set([kAXRadioButtonRole as String, kAXCheckBoxRole as String,
                   kAXMenuButtonRole as String, kAXPopUpButtonRole as String])
print("Read-only: does a toggle expose a pre/post-dispatch state value?")
print("app\trole\tname\tAXValue now\tAXSelectedValue")
for bundle in ["com.apple.finder", "com.apple.Safari", "com.apple.TextEdit"] {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { continue }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    var n = 0
    func walk(_ e: AXUIElement) {
        guard n < 5 else { return }
        let role = (attr(e, kAXRoleAttribute as String) as? String) ?? ""
        if toggles.contains(role) {
            n += 1
            let name = (attr(e, kAXDescriptionAttribute as String) as? String)
                ?? (attr(e, kAXTitleAttribute as String) as? String) ?? "-"
            let sel = describe2(e, kAXSelectedAttribute as String)
            print("\(bundle)\t\(role)\t\(name)\t\(describe(e))\t\(sel)")
        }
        for c in children(e) { walk(c) }
    }
    walk(root)
}
func describe2(_ e: AXUIElement, _ a: String) -> String {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success else { return "unsupported" }
    if let s = v as? String { return "String(\(s))" }
    if let b = v, CFGetTypeID(b) == CFBooleanGetTypeID() { return "Bool(\(CFBooleanGetValue(b as! CFBoolean)))" }
    if v == nil { return "nil" }
    return "other"
}
