import Foundation
import CryptoKit

// MARK: - Operation vocabulary (SPEC §5.1)
//
// Closed set. No free text from the model.

public enum Operation: String, CaseIterable, Sendable {
    case press
    case setValue
    case none
}

public enum GateError: Error, Sendable {
    case refused(RefusalCode)
}

/// SPEC §5.1: the text argument comes from the FIRST double-quoted span of the
/// goal, verbatim. With no span, `setValue` is refused rather than guessed.
public enum TextArgument {
    public static func firstQuotedSpan(_ goal: String) -> String? {
        let chars = Array(goal)
        var i = 0
        while i < chars.count {
            if chars[i] == "\"" || chars[i] == "\u{201C}" {
                let open = chars[i]
                let close: Character = (open == "\"") ? "\"" : "\u{201D}"
                var j = i + 1
                var buf = ""
                var closed = false
                while j < chars.count {
                    if chars[j] == close { closed = true; break }
                    buf.append(chars[j]); j += 1
                }
                // An UNTERMINATED quote is not an argument: writing a partial
                // span into a field would be guessing (Codex B7).
                return closed ? buf : nil
            }
            i += 1
        }
        return nil
    }
}

/// SPEC §6.2: canonical, unambiguous encoding for the approval token.
/// Length-prefixed and sorted, so no concatenation is ambiguous.
public enum CanonicalEncoding {
    public static func digest(fields: [(String, String)]) -> String {
        var parts: [String] = []
        for (k, v) in fields.sorted(by: { $0.0 < $1.0 }) {
            let bytes = Array(v.utf8)
            parts.append("\(k)\u{1F}\(bytes.count)\u{1F}\(v)")
        }
        let joined = parts.joined()
        return SHA256.hash(data: Data(joined.utf8))
            .map { hex1($0) }.joined()
    }
}

/// Swift 6's `String(format:)` now collides with the variadic overload, so
/// these two tiny formatters replace it.
func hex1(_ b: UInt8) -> String {
    let s = String(b, radix: 16)
    return b < 16 ? "0" + s : s
}

func hex(_ digest: some Sequence<UInt8>) -> String {
    digest.map { b in
        let s = String(b, radix: 16)
        return b < 16 ? "0" + s : s
    }.joined()
}

func fixed4(_ d: Double) -> String {
    let scaled = Int((d * 10000).rounded())
    let sign = scaled < 0 ? "-" : ""
    let a = abs(scaled)
    let whole = a / 10000
    var frac = String(a % 10000)
    while frac.count < 4 { frac = "0" + frac }
    return "\(sign)\(whole).\(frac)"
}

// MARK: - §6.1b semantic exclusions
//
// Applied to the TARGET's label, never the operation string: excluding the
// operation "send" does not stop a press on a button labelled Send, which
// passes the AXPress capability check (Codex B7 earlier / SPEC 6.1b).
public enum SemanticExclusions {
    public static let pattern =
        #"\b(delete|erase|destroy|remove|empty|trash|wipe|format|reinstall|uninstall|send|publish|share|purchase|buy|checkout|pay|transfer|revoke|reset|force quit|terminate|shutdown|sign out)\b"#

    public static func match(_ e: CapturedElement) -> String? {
        let haystack = [e.name, e.elementDescription]
            .compactMap { $0 }
            .joined(separator: " ")
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                   options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
        guard let m = regex.firstMatch(in: haystack, range: range),
              let r = Range(m.range, in: haystack) else { return nil }
        return String(haystack[r])
    }
}

// MARK: - Gate

/// SPEC §5.3. Composition is deterministic; errors never default to zero, the
/// first option, a guessed handle, or success.
public enum Gate {

    public struct Phase1 {
        public let operation: ChoiceAnswer
        public let target: ChoiceAnswer
        public let risk: ScoreAnswer
        public let applied: NoulAnswer
    }

    /// Phase 1 result: a concrete binding, or a refusal.
    public static func phase1(_ r: JevResponse, candidateHandles: Set<Handle>)
        -> Result<(operation: Operation, handle: Handle), RefusalCode> {
        guard let oRaw = r.answers["operation"],
              let tRaw = r.answers["target"],
              let aRaw = r.answers["applied"] else {
            return .failure(.invalidAnswer)
        }
        let operationKeys = Set(Operation.allCases.map(\.rawValue))
        let operation = try? ChoiceAnswer(question: "operation", json: oRaw)
        let target = try? ChoiceAnswer(question: "target", json: tRaw)
        let applied = try? NoulAnswer(question: "applied", json: aRaw)
        guard let operation, let target, let applied else { return .failure(.invalidAnswer) }
        // Phase 1 carries a risk answer too. It must be VALID even though it
        // never authorises anything -- a malformed one is invalidAnswer, not a
        // silently ignored extra (Codex B4).
        if let riskRaw = r.answers["risk"] {
            guard let risk = try? ScoreAnswer(question: "risk", json: riskRaw, levelCount: 3),
                  (try? risk.validateTie()) != nil else { return .failure(.invalidAnswer) }
        }
        guard (try? operation.validate(expectedKeys: operationKeys)) != nil,
              (try? target.validate(expectedKeys:
                  Set(candidateHandles.map(\.raw)).union(["none"]))) != nil
        else { return .failure(.invalidAnswer) }

        // §5.3: `none` in either head is a no-action decision, not a refusal.
        if operation.choice == Operation.none.rawValue { return .success((.none, Handle(raw: "none"))) }
        if target.choice == "none" { return .success((.none, Handle(raw: "none"))) }

        // Two-sided Choice gate (SPEC §5.4): confidence AND p_max floor.
        if operation.confidence < Thresholds.operationConfidence
            || operation.pMax < Thresholds.pMaxFloor {
            return .failure(.lowConfidence)
        }
        if target.confidence < Thresholds.targetConfidence
            || target.pMax < Thresholds.pMaxFloor {
            return .failure(.lowConfidence)
        }
        let handle = Handle(raw: target.choice)
        guard candidateHandles.contains(handle) else {
            return .failure(.unknownHandle)
        }
        guard let op = Operation(rawValue: operation.choice) else {
            return .failure(.unsupportedAction)
        }
        return .success((op, handle))
    }

    /// Phase 2 (SPEC §5.1): binding confirmation. Risk is gated ONLY here,
    /// because Phase 1 could not have known the binding.
    public static func phase2(_ r: JevResponse) -> Result<Void, RefusalCode> {
        guard let riskRaw = r.answers["bindingRisk"],
              let argRaw = r.answers["argSafe"] else {
            return .failure(.invalidAnswer)
        }
        guard let risk = try? ScoreAnswer(question: "bindingRisk", json: riskRaw, levelCount: 3),
              let arg = try? NoulAnswer(question: "argSafe", json: argRaw) else {
            return .failure(.invalidAnswer)
        }
        guard (try? risk.validateTie()) != nil else { return .failure(.invalidAnswer) }

        // Permissive-only risk gate: BOTH conditions required.
        guard risk.score <= Thresholds.riskScoreMax,
              risk.confidence >= Thresholds.riskConfidenceMin else {
            return .failure(.approvalRequired)
        }
        // argSafe asks whether the text is free of secrets: HIGH noul is SAFE.
        guard arg.isConfidentlySafe else { return .failure(.approvalRequired) }
        return .success(())
    }

    /// §5.3: the `applied` completion question. Three outcomes, not two:
    /// confident DONE, confident PROCEED, and the ambiguous middle band which
    /// REFUSES rather than proceeding (Codex B4 -- an `applied` of 0.5 or 0.9
    /// must never be read as "carry on").
    public enum Completion {
        case proceed
        case alreadyDone
        case ambiguous
    }

    public static func completion(_ a: NoulAnswer) -> Completion {
        if a.noul >= Thresholds.appliedHi { return .alreadyDone }
        if a.noul <= Thresholds.appliedLo { return .proceed }
        return .ambiguous
    }

    /// SPEC §6.2 approval token.
    public static func token(generation: Int, appLaunchID: String, primitive: Primitive,
                             handle: Handle, arguments: String?,
                             questionVersion: String) -> String {
        CanonicalEncoding.digest(fields: [
            ("appLaunchID", appLaunchID),
            ("argumentsDigest", sha256Hex(arguments ?? "")),
            ("generation", String(generation)),
            ("handle", handle.raw),
            ("primitive", primitive.rawValue),
            ("questionVersion", questionVersion),
            ("thresholds", Thresholds.digest),
        ])
    }

    public static func sha256Hex(_ s: String) -> String {
hex(SHA256.hash(data: Data(s.utf8)))
    }
}