import Foundation

// MARK: - Handles

/// A stable, snapshot-scoped candidate key. SPEC §7.2: assigned AFTER ranking,
/// so pruning never renumbers a handle that was already emitted.
public struct Handle: Hashable, Sendable, Codable, CustomStringConvertible {
    public let raw: String
    public init(raw: String) { self.raw = raw }
    public init(index: Int) { self.raw = String(format: "e%02d", index) }
    public var description: String { raw }
}

// MARK: - Elements

/// `enabled` is tri-state: SPEC §7.2 requires that an absent
/// `kAXEnabledAttribute` is never coerced to `false` (which would silently
/// exclude valid elements) nor to `true` (which would fail open).
public enum Enabled: String, Sendable, Codable {
    case enabled
    case disabled
    case unknown          // attribute absent — NOT applicable, never "disabled"
}

public struct Frame: Sendable, Codable, Equatable {
    public var x: Int, y: Int, width: Int, height: Int
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// One captured element. Pure value type: no `AXUIElement` ever escapes the
/// adapter (SPEC §8.1).
public struct CapturedElement: Sendable, Codable {
    public var handle: Handle
    /// Index path from the app root, e.g. "/3/1/0". SPEC §6.2: the ADDRESS used
    /// to re-acquire the element in a separate `apply` process.
    public var path: String
    public var role: String
    public var subrole: String?
    public var identifier: String?
    public var title: String?
    public var elementDescription: String?
    public var value: String?
    public var enabled: Enabled
    public var focused: Bool?
    public var frame: Frame?
    public var actions: [String]

    public init(
        handle: Handle, path: String, role: String, subrole: String? = nil,
        identifier: String? = nil, title: String? = nil, elementDescription: String? = nil,
        value: String? = nil, enabled: Enabled = .unknown, focused: Bool? = nil,
        frame: Frame? = nil, actions: [String] = []
    ) {
        self.handle = handle
        self.path = path
        self.role = role
        self.subrole = subrole
        self.identifier = identifier
        self.title = title
        self.elementDescription = elementDescription
        self.value = value
        self.enabled = enabled
        self.focused = focused
        self.frame = frame
        self.actions = actions
    }

    /// SPEC §6.2 / §7.1: name resolution is Description -> Title -> Help ->
    /// Identifier. Identifier is LAST because on Apple apps it is frequently an
    /// internal placeholder (`_NS:61`) that is useless to a text-only model.
    public var name: String? {
        if let e = elementDescription, !e.isEmpty { return e }
        if let t = title, !t.isEmpty { return t }
        if let i = identifier, !i.isEmpty { return i }
        return nil
    }

    /// SPEC §6.2 fingerprint tuple: role, subrole, identifier, title, description.
    /// Focus is deliberately absent — it is mutable and re-checked live at apply.
    public var fingerprint: Fingerprint {
        Fingerprint(role: role, subrole: subrole, identifier: identifier,
                    title: title, elementDescription: elementDescription)
    }

    public var isAppKitSynthetic: Bool {
        guard let id = identifier, id.hasPrefix("_NS:") else { return false }
        return (elementDescription?.isEmpty ?? true) && (title?.isEmpty ?? true)
    }
}

public struct Fingerprint: Sendable, Codable, Equatable {
    public var role: String
    public var subrole: String?
    public var identifier: String?
    public var title: String?
    public var elementDescription: String?

    public init(role: String, subrole: String?, identifier: String?,
                title: String?, elementDescription: String?) {
        self.role = role
        self.subrole = subrole
        self.identifier = identifier
        self.title = title
        self.elementDescription = elementDescription
    }
}

// MARK: - Snapshot

public enum SnapshotCompleteness: String, Sendable, Codable {
    case complete
    case partial
}

public struct SnapshotDiagnostics: Sendable, Codable {
    public var droppedUnknownEnabled = 0
    public var malformed = 0
    public var truncated = 0
    public var cycleGuard = 0
    public var limit = 0
    public init() {}
}

public struct Snapshot: Sendable, Codable {
    public var generation: Int
    public var appBundleID: String
    public var appLaunchID: String
    public var frontWindow: String?
    /// All captured elements, in ranking order after §7.2.
    public var elements: [CapturedElement]
    public var completeness: SnapshotCompleteness
    public var diagnostics: SnapshotDiagnostics

    public init(generation: Int, appBundleID: String, appLaunchID: String,
                frontWindow: String?, elements: [CapturedElement],
                completeness: SnapshotCompleteness, diagnostics: SnapshotDiagnostics) {
        self.generation = generation
        self.appBundleID = appBundleID
        self.appLaunchID = appLaunchID
        self.frontWindow = frontWindow
        self.elements = elements
        self.completeness = completeness
        self.diagnostics = diagnostics
    }

    public func element(for handle: Handle) -> CapturedElement? {
        elements.first { $0.handle == handle }
    }

    public var handleSet: Set<Handle> { Set(elements.map(\.handle)) }
}

// MARK: - Refusals and outcomes

/// SPEC §8.3 precedence order. The first match in this order is reported.
public enum RefusalCode: String, Sendable, Codable, CaseIterable {
    case budgetExhausted
    case axUnavailable
    case incompleteSnapshot
    case invalidAnswer
    case lowConfidence
    case unknownHandle
    case unsupportedAction
    case ambiguousNoul
    case approvalRequired
    case staleApproval
    case fingerprintChanged
    case enabledUnknown
    case preflightReadFailed
    case ambiguousName

    /// Exact §8.3 ordering. `nil` when the code is not in the taxonomy.
    public static let precedence: [RefusalCode] = [
        .budgetExhausted, .axUnavailable, .incompleteSnapshot, .invalidAnswer,
        .lowConfidence, .unknownHandle, .unsupportedAction, .ambiguousNoul,
        .approvalRequired, .staleApproval, .fingerprintChanged, .enabledUnknown,
        .preflightReadFailed, .ambiguousName,
    ]

    /// SPEC §8.3: when several conditions hold, report the first match here.
    public static func first(_ codes: [RefusalCode]) -> RefusalCode? {
        for candidate in precedence where codes.contains(candidate) { return candidate }
        return nil
    }
}

public enum Primitive: String, Sendable, Codable, CaseIterable {
    case press
    case setValue
}

public enum DecisionKind: Sendable, Codable {
    case act(primitive: Primitive, handle: Handle, arguments: String?)
    case noAction
    case alreadyDone
}

public enum Outcome: Sendable {
    /// Nothing was dispatched.
    case refused(RefusalCode)
    /// Dispatched and the effect predicate was observed.
    case applied
    /// Dispatched; the effect could NOT be confirmed. Never retried.
    case unknownOutcome(reason: String)

    public var isDispatching: Bool {
        switch self {
        case .refused: false
        case .applied, .unknownOutcome: true
        }
    }
}

public struct Decision: Sendable, Codable {
    public var kind: DecisionKind
    public var generation: Int
    public var appLaunchID: String
    /// SHA256 over the canonical encoding in §6.2 — the approval token.
    public var approvalToken: String
    public var argumentDigest: String?

    public init(kind: DecisionKind, generation: Int, appLaunchID: String,
                approvalToken: String, argumentDigest: String?) {
        self.kind = kind
        self.generation = generation
        self.appLaunchID = appLaunchID
        self.approvalToken = approvalToken
        self.argumentDigest = argumentDigest
    }
}

// MARK: - Backend seam

/// SPEC §8.1. Normalised contract: no raw `AXUIElement` escapes, so fixture
/// tests need no real Accessibility permission.
public protocol AXBackend: Sendable {
    func launchID(appBundleID: String) throws -> String
    func snapshot(appBundleID: String, generation: Int) throws -> Snapshot
    /// Re-acquire by ADDRESS (SPEC §6.2): walk `elementPath`, then require an
    /// exact fingerprint match. Never by ordinal or name alone.
    func reAcquire(path: String) throws -> CapturedElement
    /// Live capability probe. SPEC §8.2: a failed or malformed read is an
    /// error, never "assume unchanged".
    func supports(_ primitive: Primitive, on element: CapturedElement) throws -> Bool
    /// SPEC §6.3: live re-check of the §6.1b decision predicate.
    func revalidatePredicate(for element: CapturedElement, primitive: Primitive) throws
    func dispatch(_ primitive: Primitive, on element: CapturedElement,
                  arguments: String?) throws -> Outcome
}

/// Errors the backend may raise; mapped to refusal codes by the caller.
public enum AXBackendError: Error, Sendable {
    case axUnavailable(String)
    case readFailed(String)
    case appNotRunning(String)
    case notFound(String)
    case unsupported(String)
    /// The action was dispatched; the outcome is unknown. NEVER a refusal.
    case dispatchedUnknownOutcome(String)
}