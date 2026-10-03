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
func count(_ e: AXUIElement) -> Int {
    var n = 1
    for c in children(e) { n += count(c) }
    return n
}

print("Full-tree walk latency (this bounds decide, and the 120s approval window)")
print("app\truns\tmedian_ms\tmax_ms\tnodes")
for bundle in ["com.apple.finder", "com.apple.Safari", "com.apple.TextEdit", "com.apple.Notes"] {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { continue }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    _ = AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 2.0)
    var times: [Double] = []
    var nodes = 0
    for _ in 0..<5 {
        let t0 = DispatchTime.now().uptimeNanoseconds
        nodes = count(root)
        let dt = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
        times.append(dt)
    }
    let s = times.sorted()
    print("\(bundle)\t5\t\(String(format: "%.0f", s[2]))\t\(String(format: "%.0f", s[4]))\t\(nodes)")
}
