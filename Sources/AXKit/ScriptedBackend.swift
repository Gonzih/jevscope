import Foundation

// MARK: - Scripted backend (SPEC §8.4)
//
// The seam that makes the dangerous paths testable without a desktop: same-role
// replacement, row reuse, selection change under an unchanged control, app
// restart, out-of-order response, low confidence, cannotComplete after a
// recorded mutation, a target that becomes focused between decide and apply,
// and a required preflight read that fails.
//
// Every refusal test asserts the action log is EMPTY. Every unknown-outcome
// test asserts EXACTLY ONE dispatch. That is the whole point: the count, not
// the message, is what proves no mutation slipped through.

public enum ScriptedEvent: Sendable, Equatable {
    /// Element at `path` now presents a different fingerprint (same role).
    case replaceSameRole(path: String)
    /// A virtualized row reuses a control for a different document.
    case reuseRow(path: String)
    /// Selection changes under an UNCHANGED control.
    case changeSelection
    /// The app restarts, so appLaunchID moves.
    case appRestart
    /// A required preflight attribute read returns a non-success AXError.
    case preflightReadFails(attribute: String)
    /// The target becomes focused between decide and apply (B12).
    case targetBecomesFocused
    /// The subrole read FAILS (returns an error) rather than returning absent.
    case subroleReadFails
    /// Press dispatched, but AX answers cannotComplete.
    case dispatchCannotComplete
}

public struct ActionLogEntry: Sendable, Equatable {
    public let primitive: String
    public let path: String
    public let arguments: String?
}

public final class ScriptedBackend: AXBackend, @unchecked Sendable {

    public private(set) var elements: [String: CapturedElement]
    public private(set) var launch: String
    private var events: [ScriptedEvent]
    private var index = 0

    /// The action log. Its COUNT is the assertion that matters.
    public private(set) var actionLog: [ActionLogEntry] = []
    private let lock = NSLock()

    public init(elements: [CapturedElement], launch: String = "1:0",
                events: [ScriptedEvent] = []) {
        self.elements = Dictionary(uniqueKeysWithValues:
            elements.map { ($0.path, $0) })
        self.launch = launch
        self.events = events
    }

    /// Consume the next scripted event, if any. Mutating is invalid on a class
    /// instance method, so the index is advanced explicitly.
    private func nextEvent() -> ScriptedEvent? {
        guard index < events.count else { return nil }
        let e = events[index]
        index += 1
        return e
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        index = 0
        actionLog.removeAll()
    }

    public func applyNow(_ event: ScriptedEvent) {
        lock.lock(); defer { lock.unlock() }
        apply(event)
    }

    private func apply(_ event: ScriptedEvent) {
        switch event {
        case .replaceSameRole(let path), .reuseRow(let path):
            guard var e = elements[path] else { return }
            // Same ROLE, different identity: exactly what a fingerprint must catch.
            if case .reuseRow = event {
                e.value = "a different document"
            } else {
                e.title = (e.title == "Archive") ? "Delete" : "Archive"
            }
            elements[path] = e
        case .changeSelection:
            for (k, var e) in elements where e.enabled == .enabled {
                e.focused = !(e.focused ?? false)
                elements[k] = e
            }
        case .appRestart:
            launch = "999:restarted"
        case .preflightReadFails, .targetBecomesFocused, .dispatchCannotComplete,
             .subroleReadFails:
            break   // consumed by the corresponding operation
        }
    }

    // MARK: AXBackend

    public func launchID(appBundleID: String) throws -> String { launch }

    public func snapshot(appBundleID: String, generation: Int) throws -> Snapshot {
        Snapshot(generation: generation, appBundleID: appBundleID, appLaunchID: launch,
                 frontWindow: "Fixture",
                 elements: elements.values.sorted { $0.path < $1.path },
                 completeness: .complete, diagnostics: SnapshotDiagnostics())
    }

    /// Re-acquires WITHOUT consuming an event. Events belong to the operation
    /// that scripts them; consuming them here meant revalidatePredicate and
    /// dispatch never saw their own injected failure.
    public func reAcquire(path: String) throws -> CapturedElement {
        guard let e = elements[path] else { throw AXBackendError.notFound(path) }
        return e
    }

    public func supports(_ primitive: Primitive, on element: CapturedElement) throws -> Bool {
        let live = try reAcquire(path: element.path)
        if let ev = nextEvent() { apply(ev) }
        switch primitive {
        case .press:  return live.actions.contains("AXPress")
        case .setValue: return live.enabled == .enabled
        }
    }

    public func revalidatePredicate(for element: CapturedElement,
                                    primitive: Primitive) throws {
        let live = try reAcquire(path: element.path)
        // Consume one event here and act on what it was.
        guard let ev = nextEvent() else { return }
        apply(ev)
        switch ev {
        case .preflightReadFails:
            throw AXBackendError.readFailed("injected preflight read failure")
        case .subroleReadFails:
            // A FAILED read must throw. Using `try?` here once turned this into
            // nil, and nil != "AXSecureTextField" passed the check.
            throw AXBackendError.readFailed("AXSubrole: cannotComplete")
        case .targetBecomesFocused:
            throw AXBackendError.readFailed("target is focused")
        default:
            if live.focused == true {
                throw AXBackendError.readFailed("target is focused")
            }
        }
    }

    public func dispatch(_ primitive: Primitive, on element: CapturedElement,
                         arguments: String?) throws -> Outcome {
        lock.lock()
        actionLog.append(ActionLogEntry(primitive: primitive.rawValue,
                                        path: element.path, arguments: arguments))
        lock.unlock()
        if nextEvent() == .dispatchCannotComplete {
            throw AXBackendError.dispatchedUnknownOutcome("injected cannotComplete")
        }
        return .applied
    }
}