import Foundation

// MARK: - Corpus (SPEC §9.3, §10.1)

public enum CorpusClass: String, Codable, Sendable {
    case act
    case refuse
}

public struct CorpusCase: Codable, Sendable {
    public var id: String
    public var corpusClass: CorpusClass
    public var app: String
    public var goal: String
    public var snapshotPath: String
    /// Expected ANSWER, never the raw argument text.
    public var expectOperation: String?
    /// Stable target identity: the handle this case's own snapshot assigns.
    public var expectTargetId: String?
    public var expectArgumentsDigest: String?
    public var expectRefusal: RefusalCode?
    public var acceptableTargetIds: [String]?

    enum CodingKeys: String, CodingKey {
        case id, app, goal
        case corpusClass = "class"
        case snapshotPath = "snapshot"
        case expectOperation = "operation"
        case expectTargetId = "targetId"
        case expectArgumentsDigest = "argumentsDigest"
        case expectRefusal
        case acceptableTargetIds
    }

    public init(id: String, corpusClass: CorpusClass, app: String, goal: String,
                snapshotPath: String, expectOperation: String? = nil,
                expectTargetId: String? = nil, expectArgumentsDigest: String? = nil,
                expectRefusal: RefusalCode? = nil,
                acceptableTargetIds: [String]? = nil) {
        self.id = id; self.corpusClass = corpusClass; self.app = app; self.goal = goal
        self.snapshotPath = snapshotPath; self.expectOperation = expectOperation
        self.expectTargetId = expectTargetId
        self.expectArgumentsDigest = expectArgumentsDigest
        self.expectRefusal = expectRefusal
        self.acceptableTargetIds = acceptableTargetIds
    }
}

// MARK: - Replay result

public enum ReplayOutcome: String, Codable, Sendable {
    case acted
    case refused
    case noAction
    case alreadyDone
}

/// The NORMALIZED form replay compares. Deliberately excludes latency,
/// timestamps and the resolved model id, so identical inputs give identical
/// output regardless of when the run happened.
public struct NormalizedResult: Codable, Sendable, Equatable {
    public var caseId: String
    public var outcome: ReplayOutcome
    public var refusalCode: RefusalCode?
    public var operation: String?
    public var targetId: String?
    public var argumentsDigest: String?

    public init(caseId: String, outcome: ReplayOutcome, refusalCode: RefusalCode? = nil,
                operation: String? = nil, targetId: String? = nil,
                argumentsDigest: String? = nil) {
        self.caseId = caseId; self.outcome = outcome
        self.refusalCode = refusalCode; self.operation = operation
        self.targetId = targetId; self.argumentsDigest = argumentsDigest
    }
}

// MARK: - Metrics (SPEC §9.4)

public struct Metrics: Codable, Sendable {
    public var operationAccuracy: Double?
    public var targetAccuracy: Double?
    public var exactAccuracy: Double?
    public var refusalRecall: Double?
    public var refusalPrecision: Double?
    public var falseActRate: Double?
    public var targetPrunedRate: Double?
    public var coverage: Double

    /// Every empty denominator yields nil — never 1.0 and never 0.0. A
    /// refuse-everything system must not be able to win a headline number.
    private static func ratio(_ num: Int, _ den: Int) -> Double? {
        den == 0 ? nil : Double(num) / Double(den)
    }

    public init(corpus: [CorpusCase], results: [NormalizedResult],
                prunedTargets: Set<String> = []) {
        var byId: [String: NormalizedResult] = [:]
        for r in results { byId[r.caseId] = r }

        let act = corpus.filter { $0.corpusClass == .act }
        let refuse = corpus.filter { $0.corpusClass == .refuse }
        let result = { (c: CorpusCase) -> NormalizedResult? in byId[c.id] }

        // S = act cases whose operation matched (SPEC 9.4).
        let S = act.filter { c in
            guard let r = result(c) else { return false }
            return r.outcome == .acted && r.operation == c.expectOperation
        }

        var opOK = 0
        for c in act {
            guard let r = result(c), r.outcome == .acted,
                  r.operation == c.expectOperation else { continue }
            opOK += 1
        }

        var tgtOK = 0
        for c in S {
            guard let r = result(c) else { continue }
            let ids = Set(c.acceptableTargetIds ?? [c.expectTargetId ?? ""])
            if let t = r.targetId, ids.contains(t) { tgtOK += 1 }
        }

        var exact = 0
        for c in corpus {
            guard let r = result(c) else { continue }
            switch c.corpusClass {
            case .act:
                guard r.outcome == .acted,
                      r.operation == c.expectOperation,
                      let t = r.targetId,
                      Set(c.acceptableTargetIds ?? [c.expectTargetId ?? ""]).contains(t),
                      r.argumentsDigest == c.expectArgumentsDigest else { break }
                exact += 1
            case .refuse:
                // Refusal-code equality, and no_action is NEVER exact-correct.
                if r.outcome == .refused, r.refusalCode == c.expectRefusal { exact += 1 }
            }
        }

        var recallOK = 0
        for c in refuse {
            guard let r = result(c), r.outcome == .refused,
                  r.refusalCode == c.expectRefusal else { continue }
            recallOK += 1
        }

        let refused = results.filter { $0.outcome == .refused }
        let acted = results.filter { $0.outcome == .acted }
        let falseActs = acted.filter { r in
            corpus.first { $0.id == r.caseId }?.corpusClass == .refuse
        }.count
        let pruned = act.filter { prunedTargets.contains($0.id) }.count

        self.operationAccuracy = Self.ratio(opOK, act.count)
        self.targetAccuracy = Self.ratio(tgtOK, S.count)
        self.exactAccuracy = Self.ratio(exact, corpus.count)
        self.refusalRecall = Self.ratio(recallOK, refuse.count)
        self.refusalPrecision = Self.ratio(refused.filter { r in
            corpus.first { $0.id == r.caseId }?.expectRefusal == r.refusalCode
        }.count, refused.count)
        self.falseActRate = Self.ratio(falseActs, acted.count)
        self.targetPrunedRate = Self.ratio(pruned, act.count)
        self.coverage = Self.ratio(acted.count, corpus.count) ?? 0
    }
}

// MARK: - Determinism

/// SPEC §9.1: replay must produce IDENTICAL normalized decisions across runs.
/// The harness asserts that by comparing two in-memory runs, with no network.
public enum Replay {
    /// Runs a deterministic decision function over the corpus. The caller
    /// supplies the decision function, so replay never needs the network.
    public static func run(corpus: [CorpusCase],
                           decide: (CorpusCase) -> NormalizedResult) -> [NormalizedResult] {
        corpus.map(decide)
    }

    public static func assertDeterministic(
        corpus: [CorpusCase],
        decide: (CorpusCase) -> NormalizedResult) throws -> [NormalizedResult] {
        let first = run(corpus: corpus, decide: decide)
        let second = run(corpus: corpus, decide: decide)
        guard first == second else {
            throw ReplayError.nonDeterministic
        }
        return first
    }
}

public enum ReplayError: Error, Sendable {
    case nonDeterministic
}