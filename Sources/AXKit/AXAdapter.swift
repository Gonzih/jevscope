import AppKit
import ApplicationServices
import Foundation

// MARK: - AXAdapter
//
// The ONLY code that touches AXUIElement (SPEC §8.1). Swift 6 + macOS 27
// notes, all verified by compilation or a live read (SPEC §4.8):
//   * every `kAX*` constant is a Swift `String`; call sites need `as CFString`
//   * `AXError` is an enum and does NOT conform to Error, so `Result<_, AXError>`
//     will not compile -- it is matched explicitly below
//   * `AXValueGetValue` writes through a MUTABLE pointer: withUnsafeMutableBytes
//   * `CFBoolean` cannot be constructed; use kCFBooleanTrue / kCFBooleanFalse
//   * `CFArrayGetValueAtIndex` + `load(as:)` SEGFAULTS; bridge via NSArray and
//     check CFGetTypeID == AXUIElementGetTypeID() before unsafeDowncast
//   * `kAXFrameAttribute` does not exist; use kAXPosition + kAXSize
//   * AX calls work off the main thread

public final class AXAdapter: AXBackend, @unchecked Sendable {

    /// Bound every AX call so a wedged app cannot hang the walk (SPEC §8.2).
    public static let messagingTimeoutSeconds: Float = 2.0
    public static let maxDepth = 40
    public static let maxNodes = 6000

    private let bundleID: String

    public init(appBundleID: String) {
        self.bundleID = appBundleID
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(),
                                       Self.messagingTimeoutSeconds)
    }

    // MARK: raw reads

    /// AXError does NOT conform to Swift's Error protocol, so `Result<T, AXError>`
    /// cannot be formed (SPEC §4.8). Attribute reads return an explicit pair.
    private func copyAttribute(_ e: AXUIElement, _ name: String)
        -> (value: CFTypeRef?, error: AXError?) {
        var v: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(e, name as CFString, &v)
        return (err == .success ? v : nil, err == .success ? nil : err)
    }

    private func stringAttr(_ e: AXUIElement, _ name: String) -> String? {
        let r = copyAttribute(e, name)
        guard r.error == nil, let s = r.value as? String, !s.isEmpty else { return nil }
        return s
    }

    /// Returns nil when the attribute is ABSENT (`.noValue`) — distinct from
    /// a read that errored, which is a hard failure.
    private func boolAttr(_ e: AXUIElement, _ name: String) throws -> Bool? {
        let r = copyAttribute(e, name)
        if let err = r.error {
            if err == .noValue { return nil }
            throw AXBackendError.readFailed("\(name): \(err)")
        }
        guard let v = r.value else { return nil }
        if CFGetTypeID(v) == CFBooleanGetTypeID() {
            return CFBooleanGetValue(unsafeBitCast(v, to: CFBoolean.self))
        }
        // A non-boolean where a boolean is required is MALFORMED, never
        // silently false -- SPEC 8.2.
        throw AXBackendError.readFailed("\(name): unexpected type")
    }

    private func frame(_ e: AXUIElement) -> Frame? {
        func point(_ n: String) -> CGPoint? {
            let r = copyAttribute(e, n)
            guard r.error == nil, let v = r.value, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
            var p = CGPoint.zero
            let ok = withUnsafeMutableBytes(of: &p) {
                AXValueGetValue(unsafeBitCast(v, to: AXValue.self), .cgPoint, $0.baseAddress!)
            }
            return ok ? p : nil
        }
        func size(_ n: String) -> CGSize? {
            let r = copyAttribute(e, n)
            guard r.error == nil, let v = r.value, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
            var s = CGSize.zero
            let ok = withUnsafeMutableBytes(of: &s) {
                AXValueGetValue(unsafeBitCast(v, to: AXValue.self), .cgSize, $0.baseAddress!)
            }
            return ok ? s : nil
        }
        guard let p = point(kAXPositionAttribute as String),
              let s = size(kAXSizeAttribute as String) else { return nil }
        return Frame(x: Int(p.x), y: Int(p.y), width: Int(s.width), height: Int(s.height))
    }

    private func actionNames(_ e: AXUIElement) -> [String] {
        var v: CFArray?
        guard AXUIElementCopyActionNames(e, &v) == .success, let a = v as? [String] else { return [] }
        return a
    }

    /// Safe child enumeration. The CFArrayGetValueAtIndex + load(as:) route
    /// segfaults; this bridges to NSArray and type-checks first.
    ///
    /// Returns nil when the READ FAILED, which is deliberately distinct from
    /// an empty array. Callers must treat nil as "enumeration lost" and mark
    /// the snapshot partial -- returning [] for both would silently swallow a
    /// dropped subtree and report a complete tree (re-validation).
    /// Count of child-array members that were not AXUIElement. Surfaced in the
    /// snapshot diagnostics; a non-zero count makes the snapshot partial.
    private var malformedChildren = 0

    private func childrenChecked(_ e: AXUIElement) -> [AXUIElement]? {
        let r = copyAttribute(e, kAXChildrenAttribute as String)
        if let err = r.error {
            return (err == .noValue) ? [] : nil      // no children vs unreadable
        }
        guard let arr = r.value as? NSArray else { return nil }
        let want = AXUIElementGetTypeID()
        var out: [AXUIElement] = []
        for case let obj as CFTypeRef in arr {
            guard CFGetTypeID(obj) == want else {
                // A child that is not an AXUIElement is MALFORMED, not absent.
                // Silently dropping it made a damaged tree look clean.
                malformedChildren += 1
                continue
            }
            out.append(unsafeDowncast(obj, to: AXUIElement.self))
        }
        return out
    }

    private func children(_ e: AXUIElement) -> [AXUIElement] {
        childrenChecked(e) ?? []
    }

    // MARK: AXBackend

    public func launchID(appBundleID: String) throws -> String {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: appBundleID).first else {
            throw AXBackendError.appNotRunning(appBundleID)
        }
        // pid + launch date is stable for the life of the process.
        return "\(app.processIdentifier):\(app.launchDate?.timeIntervalSince1970 ?? 0)"
    }

    public func snapshot(appBundleID: String, generation: Int) throws -> Snapshot {
        guard AXIsProcessTrusted() else {
            throw AXBackendError.axUnavailable("Accessibility permission not granted")
        }
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: appBundleID).first else {
            throw AXBackendError.appNotRunning(appBundleID)
        }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        var collected: [CapturedElement] = []
        var diag = SnapshotDiagnostics()
        var partial = false
        // Cycle guard (SPEC 8.2): the AX tree is not guaranteed acyclic, and a
        // self-referential subtree recursed to the node cap -- 6000 nodes with
        // 27-level duplicate paths instead of the 339 real elements.
        //
        // Cycle guard by EQUALITY, not by hash. A hash table can collide and
        // silently drop a genuinely different element; Codex showed a witness
        // where every unique node was retained yet the snapshot still went
        // partial, because a collision was indistinguishable from a repeat.
        // CFEqual against a short seen-list has no such failure mode, and a
        // real repeat genuinely loses nothing so it must NOT mark partial.
        var seen: [AXUIElement] = []

        func walk(_ e: AXUIElement, path: [Int], depth: Int, ancestors: [String]) {
            guard collected.count < Self.maxNodes else { diag.limit += 1; partial = true; return }
            guard depth <= Self.maxDepth else { diag.cycleGuard += 1; partial = true; return }
            if seen.contains(where: { CFEqual($0, e) }) {
                // The same element reached twice: stopping here loses nothing,
                // so the snapshot stays complete.
                diag.cycleGuard += 1
                return
            }
            seen.append(e)

            let role = stringAttr(e, kAXRoleAttribute as String) ?? "?"
            let subrole = stringAttr(e, kAXSubroleAttribute as String)
            let identifier = stringAttr(e, kAXIdentifierAttribute as String)
            let title = stringAttr(e, kAXTitleAttribute as String)
            let desc = stringAttr(e, kAXDescriptionAttribute as String)
            let help = stringAttr(e, kAXHelpAttribute as String)
            let value = stringAttr(e, kAXValueAttribute as String)
            let enabledRaw = try? boolAttr(e, kAXEnabledAttribute as String)
            let enabled: Enabled = enabledRaw == true ? .enabled
                : (enabledRaw == false ? .disabled : .unknown)
            let focused = (try? boolAttr(e, kAXFocusedAttribute as String)) ?? nil
            let fr = frame(e)
            let acts = actionNames(e)

            collected.append(CapturedElement(
                handle: Handle(index: collected.count),
                path: "/" + path.map(String.init).joined(separator: "/"),
                role: role, subrole: subrole, identifier: identifier, title: title,
                elementDescription: desc, value: value, enabled: enabled,
                focused: focused, frame: fr, actions: acts,
                ancestorLabels: ancestors))

            switch childrenChecked(e) {
            case .some(let kids):
                if kids.isEmpty { /* a genuine leaf, not truncation */ }
                let isContainer = role == kAXMenuRole as String
                    || role == kAXPopUpButtonRole as String
                    || role == kAXMenuBarItemRole as String
                let label = desc ?? title ?? help
                let next = (isContainer && label.map { !$0.isEmpty } == true)
                    ? ancestors + [label!] : ancestors
                for (i, c) in kids.enumerated() {
                    walk(c, path: path + [i], depth: depth + 1, ancestors: next)
                }
            case .none:
                // Enumeration LOST: the subtree below is unknown, so this
                // snapshot is partial rather than falsely complete.
                diag.truncated += 1; partial = true
            default: break
            }
            if malformedChildren > 0 { partial = true }
        }
        walk(root, path: [], depth: 0, ancestors: [])

        return Snapshot(
            generation: generation,
            appBundleID: appBundleID,
            appLaunchID: try launchID(appBundleID: appBundleID),
            frontWindow: stringAttr(root, kAXFocusedWindowAttribute as String),
            elements: collected,
            completeness: partial ? .partial : .complete,
            diagnostics: diag)
    }

    public func reAcquire(path: String) throws -> CapturedElement {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID).first else {
            throw AXBackendError.appNotRunning(bundleID)
        }
        var cur = AXUIElementCreateApplication(app.processIdentifier)
        for comp in path.split(separator: "/") {
            guard let idx = Int(comp) else { throw AXBackendError.notFound("bad path \(path)") }
            let kids = children(cur)
            guard idx >= 0, idx < kids.count else {
                throw AXBackendError.notFound("path \(path) no longer resolves")
            }
            cur = kids[idx]
        }
        // Cache the LIVE reference for this path so `dispatch` can act on it.
        liveLock.lock()
        liveHandles[path] = cur
        liveLock.unlock()
        return describe(cur, path: path)
    }

    private func describe(_ e: AXUIElement, path: String) -> CapturedElement {
        CapturedElement(
            handle: Handle(index: 0), path: path,
            role: stringAttr(e, kAXRoleAttribute as String) ?? "?",
            subrole: stringAttr(e, kAXSubroleAttribute as String),
            identifier: stringAttr(e, kAXIdentifierAttribute as String),
            title: stringAttr(e, kAXTitleAttribute as String),
            elementDescription: stringAttr(e, kAXDescriptionAttribute as String),
            value: stringAttr(e, kAXValueAttribute as String),
            enabled: (try? boolAttr(e, kAXEnabledAttribute as String)).map { $0 ? .enabled : .disabled } ?? .unknown,
            focused: try? boolAttr(e, kAXFocusedAttribute as String),
            frame: frame(e), actions: actionNames(e))
    }

    public func supports(_ primitive: Primitive, on element: CapturedElement) throws -> Bool {
        // Re-acquire first: capability is a property of the LIVE element.
        let live = try reAcquire(path: element.path)
        switch primitive {
        case .press:
            return live.actions.contains(kAXPressAction as String)
        case .setValue:
            guard let liveEl = elementFor(live.path) else {
                throw AXBackendError.readFailed("no live element for \(element.path)")
            }
            var b = DarwinBoolean(false)
            let err = AXUIElementIsAttributeSettable(
                liveEl, kAXValueAttribute as CFString, &b)
            if err != .success { throw AXBackendError.readFailed("settable: \(err)") }
            return b.boolValue
        }
    }

    private var liveHandles: [String: AXUIElement] = [:]
    private var liveLock = NSLock()

    private func elementFor(_ path: String) -> AXUIElement? {
        liveLock.lock(); defer { liveLock.unlock() }
        return liveHandles[path]
    }

    /// String read that DISTINGUISHES three cases, because conflating any two
    /// of them is a fail-open bug:
    ///
    ///   * `.noValue`      -> nil. Genuinely absent, which is allowed.
    ///   * any AXError     -> throw. The read failed; refuse.
    ///   * wrong CF type   -> throw. A number or boolean where a string was
    ///     required is MALFORMED, not "absent". Treating it as absent let a
    ///     subrole read returning NSNumber(777) or a boolean pass the secure-
    ///     field check (re-validation).
    internal func stringAttrRequired(_ e: AXUIElement, _ name: String) throws -> String? {
        let r = copyAttribute(e, name)
        if let err = r.error {
            if err == .noValue { return nil }
            throw AXBackendError.readFailed("\(name): \(err)")
        }
        guard let v = r.value else { return nil }          // absent, allowed
        if CFGetTypeID(v) == CFBooleanGetTypeID() {
            throw AXBackendError.readFailed("\(name): boolean where string required")
        }
        if CFGetTypeID(v) == CFNumberGetTypeID() {
            throw AXBackendError.readFailed("\(name): number where string required")
        }
        guard let s = v as? String else {
            throw AXBackendError.readFailed("\(name): unexpected type")
        }
        return s.isEmpty ? nil : s
    }

    /// SPEC §6.3 precondition 5: re-evaluate the §6.1b predicate LIVE.
    public func revalidatePredicate(for element: CapturedElement,
                                    primitive: Primitive) throws {
        let live = try reAcquire(path: element.path)
        guard primitive == .setValue else { return }
        guard let liveEl = elementFor(live.path) else {
            throw AXBackendError.readFailed("no live element for \(element.path)")
        }
        // A FAILED subrole read is unknown, and unknown refuses.
        //
        // `try?` MUST NOT be used here: it converts the thrown read failure
        // into nil, and `nil != "AXSecureTextField"` passes -- which is exactly
        // how an unreadable target reached a setValue (re-validation).
        let subrole = try stringAttrRequired(liveEl, kAXSubroleAttribute as String)
        if subrole == kAXSecureTextFieldSubrole as String {
            throw AXBackendError.readFailed("target is a secure text field")
        }
        // Read focus from the LIVE element. No system-wide fallback: that would
        // answer for a different element entirely.
        if let f = try boolAttr(liveEl, kAXFocusedAttribute as String), f {
            throw AXBackendError.readFailed("target is focused")
        }
    }

    /// MUTATION IS DISABLED. A public `dispatch` reachable from the library
    /// bypassed approval consumption, the §6.3 preconditions and the §6.4
    /// effect predicate, and returned `.applied` on an unverified AX success.
    /// Codex reproduced a reachable `decision: act` through it.
    ///
    /// It stays `internal` rather than deleted so the actuator can be wired to
    /// the real approval record when `apply` exists. Until then it refuses.
    internal func dispatch(_ primitive: Primitive, on element: CapturedElement,
                           arguments: String?) throws -> Outcome {
        throw AXBackendError.mutationDisabled(
            "apply is not implemented: no approval record, no preflight, no "
            + "effect predicate, so no AX mutation is permitted")
    }

    /// The real implementation, deliberately unreachable while B1 stands.
    private func performUnverified(_ primitive: Primitive, on element: CapturedElement,
                                   arguments: String?) throws -> Outcome {
        guard let live = elementFor(element.path) else {
            throw AXBackendError.readFailed("no live handle for \(element.path)")
        }
        switch primitive {
        case .press:
            let err = AXUIElementPerformAction(live, kAXPressAction as CFString)
            if err == .success { return .applied }
            if err == .cannotComplete {
                // SPEC §6.4: dispatched, outcome UNKNOWN. Never a refusal,
                // never retried -- a retry can execute twice.
                throw AXBackendError.dispatchedUnknownOutcome("press cannotComplete")
            }
            throw AXBackendError.readFailed("press: \(err)")
        case .setValue:
            guard let text = arguments else {
                throw AXBackendError.readFailed("setValue without arguments")
            }
            let err = AXUIElementSetAttributeValue(live, kAXValueAttribute as CFString,
                                                  text as CFString)
            if err == .success { return .applied }
            if err == .cannotComplete {
                throw AXBackendError.dispatchedUnknownOutcome("setValue cannotComplete")
            }
            throw AXBackendError.readFailed("setValue: \(err)")
        }
    }
}