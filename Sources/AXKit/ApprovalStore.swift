import Foundation

// MARK: - Approval record (SPEC §6.2)
//
// A record on disk, not a bare digest. v2 asserted a token was "single-use"
// without any state able to enforce it; a hash consumes nothing.

public struct ApprovalRecord: Codable, Sendable, Equatable {
    public enum State: String, Codable, Sendable {
        case issued
        case consumed
    }
    public var token: String
    public var state: State
    public var generation: Int
    public var appBundleID: String
    public var appLaunchID: String
    /// ADDRESS of the element, not a live reference: an AXUIElement cannot
    /// survive the process that created it, so `apply` re-acquires by path and
    /// requires an exact fingerprint match.
    public var elementPath: String
    public var elementFingerprint: Fingerprint
    public var primitive: String
    /// Literal argument TEXT, not just its digest: setValue needs the value.
    public var arguments: String?
    public var argumentsDigest: String
    public var thresholdsDigest: String
    public var questionVersion: String
    public var issuedAt: Date

    public init(token: String, generation: Int, appBundleID: String, appLaunchID: String,
                elementPath: String, elementFingerprint: Fingerprint, primitive: Primitive,
                arguments: String?, thresholdsDigest: String, questionVersion: String,
                issuedAt: Date = Date()) {
        self.token = token
        self.state = .issued
        self.generation = generation
        self.appBundleID = appBundleID
        self.appLaunchID = appLaunchID
        self.elementPath = elementPath
        self.elementFingerprint = elementFingerprint
        self.primitive = primitive.rawValue
        self.arguments = arguments
        self.argumentsDigest = Gate.sha256Hex(arguments ?? "")
        self.thresholdsDigest = thresholdsDigest
        self.questionVersion = questionVersion
        self.issuedAt = issuedAt
    }
}

public enum ApprovalError: Error, Sendable {
    case notFound(String)
    case alreadyConsumed(String)
    case expired(String)
    case bindingMismatch(String)
}

/// SPEC §6.2: consumption is atomic and happens BEFORE dispatch, so a crash
/// mid-dispatch cannot leave a replayable token. Expiry is a REPLAY bound, not
/// an atomicity claim — see §6.5.
public final class ApprovalStore: @unchecked Sendable {

    public static let validitySeconds: TimeInterval = 120

    private let root: URL
    private let lock = NSLock()

    public init(root: URL? = nil) {
        if let root {
            self.root = root
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.root = home
                .appendingPathComponent(".local/share/jevscope/approvals", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.root,
                                                 withIntermediateDirectories: true)
    }

    private func url(_ token: String) -> URL {
        // Token is hex from SHA256, but never trust an unvalidated name on disk.
        root.appendingPathComponent(token + ".json")
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @discardableResult
    public func issue(_ record: ApprovalRecord) throws -> ApprovalRecord {
        lock.lock(); defer { lock.unlock() }
        try Self.encoder.encode(record).write(to: url(record.token), options: .atomic)
        return record
    }

    public func load(_ token: String) throws -> ApprovalRecord {
        guard Self.isValidToken(token) else { throw ApprovalError.notFound("malformed token") }
        guard let data = try? Data(contentsOf: url(token)) else {
            throw ApprovalError.notFound(token)
        }
        return try Self.decoder.decode(ApprovalRecord.self, from: data)
    }

    /// Consume atomically. Returns the record as it was when still `issued`;
    /// throws if it was already consumed or has expired. Never consumes twice.
    @discardableResult
    public func consume(_ token: String, now: Date = Date()) throws -> ApprovalRecord {
        lock.lock(); defer { lock.unlock() }
        let rec = try load(token)
        guard rec.state == .issued else { throw ApprovalError.alreadyConsumed(token) }
        guard now.timeIntervalSince(rec.issuedAt) <= Self.validitySeconds else {
            throw ApprovalError.expired(token)
        }
        var consumed = rec
        consumed.state = .consumed
        try Self.encoder.encode(consumed).write(to: url(token), options: .atomic)
        return rec
    }

    /// SPEC §6.2: a record is bound to every component, so a policy change or a
    /// different snapshot invalidates it.
    public func verify(_ record: ApprovalRecord, against current: ApprovalRecord) throws {
        guard record.token == current.token,
              record.generation == current.generation,
              record.appLaunchID == current.appLaunchID,
              record.elementPath == current.elementPath,
              record.elementFingerprint == current.elementFingerprint,
              record.primitive == current.primitive,
              record.argumentsDigest == current.argumentsDigest,
              record.thresholdsDigest == current.thresholdsDigest,
              record.questionVersion == current.questionVersion else {
            throw ApprovalError.bindingMismatch(record.token)
        }
    }

    public func purge(olderThan seconds: TimeInterval = 3600, now: Date = Date()) {
        lock.lock(); defer { lock.unlock() }
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: root.path) else { return }
        for name in names where name.hasSuffix(".json") {
            let path = root.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: path),
                  let rec = try? Self.decoder.decode(ApprovalRecord.self, from: data) else {
                continue                       // unreadable: leave it, do not guess
            }
            // Age by the RECORD's issue time. File mtime is wrong here: a
            // freshly written file holding a stale record would never purge.
            if now.timeIntervalSince(rec.issuedAt) > seconds {
                try? FileManager.default.removeItem(at: path)
            }
        }
    }

    static func isValidToken(_ t: String) -> Bool {
        t.count == 64 && t.allSatisfy { $0.isHexDigit && ($0.isNumber || $0.isLowercase) }
    }
}

// MARK: - Trace (SPEC §10.3)
//
// Records the DECISION and the ACTION LOG, never the request or response body
// and never the raw argument text — only its digest — so a credential passed
// as goal text cannot reach a trace through that path.

public struct TraceEntry: Codable, Sendable {
    public var at: Date
    public var phase: String
    public var model: String?
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var decision: String?
    public var refusalCode: String?
    public var outcome: String?
    public var token: String?
    public var generation: Int?
    public var snapshotComplete: Bool?
    public var candidateCount: Int?
    public var stateBytes: Int?
    public var requestDigest: String?
    public var goalDigest: String?
    public var goalLength: Int?
    public var argumentsDigest: String?
    public var thresholdsDigest: String?

    public init(at: Date = Date(), phase: String) {
        self.at = at; self.phase = phase
    }
}

public final class TraceWriter: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()

    /// - Parameter directory: a DIRECTORY. The JSONL file name is generated.
    ///   (Passing a file path here silently wrote inside a directory named
    ///   after it, which cost a debugging cycle.)
    public init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/jevscope/traces", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        url = dir.appendingPathComponent("trace-\(stamp).jsonl")
    }

    public var path: String { url.path }

    public func write(_ entry: TraceEntry) {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Self.encoder.encode(entry) else { return }
        var line = data
        line.append(0x0A)
        // Ensure the file exists first; FileHandle(forWritingTo:) throws on a
        // missing file, and the fallback silently lost the first entry.
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let fh = try? FileHandle(forWritingTo: url) else {
            try? line.write(to: url, options: .atomic)
            return
        }
        defer { try? fh.close() }
        _ = try? fh.seekToEnd()
        _ = try? fh.write(contentsOf: line)
    }
}