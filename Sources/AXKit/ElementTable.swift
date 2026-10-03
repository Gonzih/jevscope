import Foundation

// MARK: - Candidate selection
//
// SPEC §7. Hard filter then deterministic ranking, then a budget ladder.

public enum CandidateSelection {
    /// SPEC §7.2 ranking. Fixed coefficients, versioned with the spec.
    public static let enabledWeight = 4.0
    public static let pressWeight = 2.0
    public static let labelWeight = 1.0
    public static let areaWeight = 0.5
    public static let goalTermWeight = 3.0
    public static let minAreaPixels = 800

    /// SPEC §7.2: literal, versioned stopword set. Fixed so ranking is
    /// reproducible across runs and machines.
    public static let stopwords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "if", "then", "this", "that",
        "these", "those", "is", "are", "was", "were", "be", "been", "being",
        "to", "of", "in", "on", "at", "by", "for", "with", "from", "as",
        "it", "its", "my", "your", "our", "their", "me", "you", "we", "they",
        "he", "she", "him", "her", "his", "please", "can", "could", "would",
        "should", "will", "shall", "do", "does", "did", "have", "has", "had",
        "not", "no", "so", "than", "there", "here", "what", "which", "who",
        "whom", "when", "where", "how",
    ]

    public static func goalTerms(_ goal: String) -> Set<String> {
        Set(goal.lowercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
            .filter { $0.count >= 2 && !stopwords.contains($0) })
    }

    /// SPEC §7.1 eligibility. An element with `enabled == .unknown` is
    /// DROPPED, never coerced — failing open would admit controls that may be
    /// disabled; failing closed silently would distort the corpus.
    /// The frame test is an INTERSECTION, not equality: a control may sit
    /// partly offscreen and still be visible. (An exact key lookup rejected
    /// every element in a live TextEdit tree — 470 captured, 0 eligible.)
    public static func isEligible(_ e: CapturedElement, screens: [CGRect]) -> Bool {
        guard let name = e.name, name.count >= 3 else { return false }
        guard !name.hasPrefix("."), !name.hasPrefix("AX") else { return false }
        guard !e.actions.isEmpty else { return false }
        guard e.enabled == .enabled else { return false }
        guard !e.isAppKitSynthetic else { return false }
        if let f = e.frame {
            guard f.width > 0, f.height > 0 else { return false }
            let r = CGRect(x: f.x, y: f.y, width: f.width, height: f.height)
            guard screens.contains(where: { $0.intersects(r) }) else { return false }
        }
        return true
    }

    /// SPEC §7.2 score. Ties break on (name, path) ascending, so ordering is
    /// deterministic and stable across runs and across K sweeps.
    public static func score(_ e: CapturedElement, terms: Set<String>) -> Double {
        var s = 0.0
        if e.enabled == .enabled { s += enabledWeight }
        if e.actions.contains("AXPress") { s += pressWeight }
        if (e.name?.count ?? 0) >= 3 { s += labelWeight }
        if let f = e.frame, f.width * f.height > minAreaPixels { s += areaWeight }
        if let n = e.name?.lowercased(), terms.contains(where: { n.contains($0) }) {
            s += goalTermWeight
        }
        return s
    }

    /// SPEC §7.2: rank, then assign handles from the ranked order.
    public static func rank(_ elements: [CapturedElement], goal: String,
                            screens: [CGRect]) -> [CapturedElement] {
        let terms = goalTerms(goal)
        let eligible = elements.filter { isEligible($0, screens: screens) }
        let scored = eligible.map { ($0, score($0, terms: terms)) }
        let sorted = scored.sorted { a, b in
            if a.1 != b.1 { return a.1 > b.1 }
            let an = a.0.name ?? "", bn = b.0.name ?? ""
            if an != bn { return an < bn }
            return a.0.path < b.0.path
        }
        return sorted.map(\.0)
    }

    /// SPEC §7.2: truncate to K. Handles are assigned AFTER ranking so a
    /// smaller K is a strict prefix — the same element keeps the same handle.
    public static func assignHandles(_ ranked: [CapturedElement], k: Int) -> [CapturedElement] {
        Array(ranked.prefix(k)).enumerated().map { (i, e) in
            var copy = e
            copy.handle = Handle(index: i)
            return copy
        }
    }
}

// MARK: - Escaping (SPEC §7.4)

public enum Escaping {
    /// A label may contain quotes, newlines, pipes, or text resembling a
    /// numbered row — all of which would corrupt the model-facing line.
    public static func label(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s.unicodeScalars {
            switch ch {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "|": out += "\\|"
            default:
                if ch.value < 0x20 || ch.value == 0x7F {
                    out += "?"
                } else {
                    out.unicodeScalars.append(ch)
                }
            }
        }
        // A label that itself looks like a numbered row must not be mistaken
        // for one: prefix a space so `^\[\d{2,}\]` fails to match.
        if out.range(of: "^\\[\\d{2,}\\]", options: .regularExpression) != nil {
            out = " " + out
        }
        return out
    }

    /// SPEC §7.2 serialised line.
    public static func line(_ e: CapturedElement, includeValue: Bool,
                            includeFrame: Bool, includeActions: Bool) -> String {
        let enabled = switch e.enabled {
        case .enabled: "enabled"
        case .disabled: "disabled"
        case .unknown: "-"
        }
        let name = e.name.map { "\"\(label($0))\"" } ?? "-"
        var parts = ["[\(e.handle)] \(e.role) \(name)", enabled]
        if includeFrame, let f = e.frame {
            parts.append("\(f.x),\(f.y),\(f.width)x\(f.height)")
        }
        if includeActions, !e.actions.isEmpty {
            parts.append("actions: " + e.actions.joined(separator: ","))
        }
        if includeValue, let v = e.value, !v.isEmpty {
            let t = v.count > 24 ? String(v.prefix(24)) + "…" : v
            parts.append("value=\"\(label(t))\"")
        }
        parts.append(e.path)
        return parts.joined(separator: " | ")
    }

    /// The `state.elements` payload sent to Jev (SPEC §5.1).
    public static func elementPayload(_ e: CapturedElement, includeValue: Bool,
                                       includeFrame: Bool, includeActions: Bool)
        -> [String: Any] {
        var out: [String: Any] = [
            "handle": e.handle.raw,
            "role": e.role,
            "name": e.name ?? "",
            "enabled": e.enabled.rawValue,
        ]
        if includeFrame, let f = e.frame {
            out["frame"] = "\(f.x),\(f.y),\(f.width)x\(f.height)"
        }
        if includeActions {
            out["actions"] = e.actions
        }
        if includeValue, let v = e.value, !v.isEmpty {
            let t = v.count > 24 ? String(v.prefix(24)) + "…" : v
            out["value"] = t
        }
        return out
    }
}

// MARK: - Budget (SPEC §7.3)

public struct ByteBudget {
    /// Empirical size policy, NOT a proved token bound (SPEC §7.3).
    public static let framingAllowance = 512
    public static let limit = 30_000

    public static func exceeds(_ bytes: Int) -> Bool { bytes + framingAllowance > limit }
}

/// SPEC §7.3 overflow ladder, deterministic and ordered.
public enum BudgetLadder {
    public struct Options {
        public var includeValue = true
        public var includeFrame = true
        public var includeActions = true
        public var k: Int = 24
        public init() {}
    }

    public struct Rendered {
        public var table: String
        public var stateBytes: Int
        public var options: Options
    }

    public static let kFloor = 3      // SPEC §7.3: never below the §8.2 minimum
    public static let kCeiling = 254  // one Choice slot reserved for `none`

    public static func render(snapshot: Snapshot, goal: String,
                              screens: [CGRect],
                              body: ([CapturedElement], Options) -> Data) -> Rendered? {
        var options = Options()
        let ranked = CandidateSelection.rank(snapshot.elements, goal: goal, screens: screens)
        options.k = min(24, max(kFloor, min(kCeiling, ranked.count)))
        for _ in 0..<8 {
            let kept = CandidateSelection.assignHandles(ranked, k: options.k)
            let data = body(kept, options)
            if !ByteBudget.exceeds(data.count) {
                let table = kept.map {
                    Escaping.line($0, includeValue: options.includeValue,
                                  includeFrame: options.includeFrame,
                                  includeActions: options.includeActions)
                }.joined(separator: "\n")
                return Rendered(table: table, stateBytes: data.count, options: options)
            }
            if options.includeValue { options.includeValue = false; continue }
            if options.includeFrame { options.includeFrame = false; continue }
            if options.includeActions { options.includeActions = false; continue }
            if options.k > kFloor { options.k = max(kFloor, options.k / 2); continue }
            return nil   // fail closed with .budgetExhausted
        }
        return nil
    }
}