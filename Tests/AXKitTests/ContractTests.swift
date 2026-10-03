import XCTest

@testable import AXKit

/// Hermetic and offline: no network, no Accessibility, no desktop access.
final class ContractTests: XCTestCase {

    // MARK: helpers

    private func element(_ name: String, role: String = "AXButton",
                         enabled: Enabled = .enabled, actions: [String] = ["AXPress"],
                         frame: Frame? = Frame(x: 100, y: 100, width: 80, height: 30),
                         path: String = "/0/0", subrole: String? = nil,
                         identifier: String? = nil, value: String? = nil,
                         focused: Bool? = nil) -> CapturedElement {
        CapturedElement(handle: Handle(index: 0), path: path, role: role,
                        subrole: subrole, identifier: identifier, title: name,
                        elementDescription: nil, value: value, enabled: enabled,
                        focused: focused, frame: frame, actions: actions)
    }

    private let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]

    // MARK: §7.1 eligibility — fail closed on unknown enabled

    func testUnknownEnabledIsDroppedNotCoerced() {
        XCTAssertFalse(CandidateSelection.isEligible(
            element("Archive", enabled: .unknown), screens: screens))
        XCTAssertTrue(CandidateSelection.isEligible(
            element("Archive", enabled: .enabled), screens: screens))
    }

    func testDisabledIsDropped() {
        XCTAssertFalse(CandidateSelection.isEligible(
            element("Archive", enabled: .disabled), screens: screens))
    }

    func testOffscreenFrameIsDroppedButPartiallyVisibleIsKept() {
        let off = element("Archive", frame: Frame(x: 5000, y: 5000, width: 80, height: 30))
        XCTAssertFalse(CandidateSelection.isEligible(off, screens: screens))
        // Straddling the right edge: still visible, so eligible.
        let straddle = element("Archive", frame: Frame(x: 1400, y: 100, width: 200, height: 30))
        XCTAssertTrue(CandidateSelection.isEligible(straddle, screens: screens))
    }

    func testZeroSizedFrameIsDropped() {
        XCTAssertFalse(CandidateSelection.isEligible(
            element("Archive", frame: Frame(x: 10, y: 10, width: 0, height: 30)),
            screens: screens))
    }

    func testAppKitInternalPlaceholderIsDropped() {
        // identifier "_NS:61" with no description/title is AppKit-internal.
        var e = element("Archive")
        e.identifier = "_NS:61"
        e.title = nil
        e.elementDescription = nil
        XCTAssertTrue(e.isAppKitSynthetic)
        XCTAssertFalse(CandidateSelection.isEligible(e, screens: screens))
    }

    func testUnnamedAndPlaceholderNamedElementsAreDropped() {
        XCTAssertFalse(CandidateSelection.isEligible(element("ab"), screens: screens))
        XCTAssertFalse(CandidateSelection.isEligible(element(".localized"), screens: screens))
        XCTAssertFalse(CandidateSelection.isEligible(element("AXButton"), screens: screens))
        XCTAssertFalse(CandidateSelection.isEligible(element("Archive", actions: []),
                                                     screens: screens))
    }

    // MARK: §7.1 name order — identifier LAST

    func testNamePrefersDescriptionOverIdentifier() {
        var e = element("ignored")
        e.elementDescription = "Archive"
        e.identifier = "_NS:61"
        XCTAssertEqual(e.name, "Archive")
    }

    func testNameFallsBackToIdentifierOnlyAsLastResort() {
        var e = element("unused")
        e.title = nil
        e.elementDescription = nil
        e.identifier = "_NS:61"
        XCTAssertEqual(e.name, "_NS:61")
    }

    // MARK: §7.2 ranking determinism

    func testGoalTermBoostsMatchingCandidate() {
        let terms = CandidateSelection.goalTerms("switch to list view")
        XCTAssertTrue(terms.contains("list"))
        XCTAssertTrue(terms.contains("switch"))    // not a stopword; kept
        let hit = element("list view")
        let miss = element("sidebar toggle", path: "/0/9")
        XCTAssertGreaterThan(CandidateSelection.score(hit, terms: terms),
                             CandidateSelection.score(miss, terms: terms))
    }

    func testRankingIsDeterministicAndTieBreaksOnNameThenPath() {
        let a = element("Alpha", path: "/0/2")
        let b = element("Alpha", path: "/0/1")
        let r1 = CandidateSelection.rank([a, b], goal: "", screens: screens)
        let r2 = CandidateSelection.rank([b, a], goal: "", screens: screens)
        XCTAssertEqual(r1.map(\.path), r2.map(\.path))
        XCTAssertEqual(r1.map(\.path), ["/0/1", "/0/2"])
    }

    func testHandlesAssignedAfterRankingSoSmallerKIsStrictPrefix() {
        let els = (0..<10).map { element("Control \($0)", path: "/0/\($0)") }
        let ranked = CandidateSelection.rank(els, goal: "", screens: screens)
        let k24 = CandidateSelection.assignHandles(ranked, k: 24)
        let k4 = CandidateSelection.assignHandles(ranked, k: 4)
        XCTAssertEqual(k24.count, 10)
        XCTAssertEqual(k4.map(\.handle), Array(k24.prefix(4)).map(\.handle))
    }

    // MARK: §7.4 escaping

    func testEscapingNeutralisesStructuralCharacters() {
        let s = Escaping.label("a\"b|c\\d\ne\rf")
        XCTAssertFalse(s.contains("\n"))
        XCTAssertFalse(s.contains("\r"))
        // `|` becomes `\|`, which still contains a pipe; the escape is the
        // backslash, not the removal of the character.
        XCTAssertTrue(s.contains("\\\""))
        XCTAssertTrue(s.contains("\\|"))
        XCTAssertTrue(s.contains("\\\\"))
    }

    func testEscapingDisarmsFakeNumberedRow() {
        let s = Escaping.label("[07] AXButton \"Delete\"")
        XCTAssertTrue(s.hasPrefix(" "), "a label must not look like a numbered row")
        XCTAssertNil(s.range(of: "^\\[\\d+\\]", options: .regularExpression))
    }

    func testEscapingReplacesControlCharacters() {
        XCTAssertFalse(Escaping.label("a\u{07}b").contains("\u{07}"))
    }

    // MARK: §7.3 budget ladder

    private func snapshot(_ els: [CapturedElement]) -> Snapshot {
        Snapshot(generation: 1, appBundleID: "com.example.x", appLaunchID: "1:0",
                 frontWindow: "w", elements: els, completeness: .complete,
                 diagnostics: SnapshotDiagnostics())
    }

    func testBudgetLadderShrinksUntilItFits() {
        // Labels big enough that the first configuration cannot fit, so the
        // ladder is forced to take at least one step down.
        let els = (0..<40).map {
            element(String(repeating: "Label", count: 900) + "\($0)", path: "/0/\($0)")
        }
        var sizes: [Int] = []
        let out = BudgetLadder.render(snapshot: snapshot(els), goal: "", screens: screens) {
            kept, opts in
            let payload: [String: Any] = ["elements": kept.map {
                Escaping.elementPayload($0, includeValue: opts.includeValue,
                                        includeFrame: opts.includeFrame,
                                        includeActions: opts.includeActions)
            }]
            let d = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
            sizes.append(d.count)
            return d
        }
        XCTAssertNotNil(out, "ladder must find a fitting configuration")
        XCTAssertTrue(sizes.first! > sizes.last!, "payload must actually shrink")
        XCTAssertFalse(ByteBudget.exceeds(out!.stateBytes))
    }

    func testBudgetLadderFailsClosedWhenNothingFits() {
        let els = (0..<3).map { element("Huge \(String(repeating: "X", count: 400))\($0)",
                                          path: "/0/\($0)") }
        let out = BudgetLadder.render(snapshot: snapshot(els), goal: "", screens: screens) { _, _ in
            Data(count: ByteBudget.limit + 1000)   // never fits
        }
        XCTAssertNil(out, "must fail closed, never silently truncate")
    }

    func testBudgetFloorsKAtThree() {
        XCTAssertEqual(BudgetLadder.kFloor, 3)
        XCTAssertEqual(BudgetLadder.kCeiling, 254)   // one Choice slot reserved for `none`
    }

    // MARK: §5.2 validation — never defaults

    private func choiceJSON(choice: String, probs: [String: Double], conf: Double) -> [String: Any] {
        ["type": "choice", "choice": choice, "confidence": conf,
         "probabilities": probs.mapValues { $0 as Any }]
    }

    func testChoiceRequiresExactKeyMatchWithCriteria() {
        let a = try! ChoiceAnswer(question: "t",
                                  json: choiceJSON(choice: "e00", probs: ["e00": 1.0], conf: 1.0))
        XCTAssertThrowsError(try a.validate(expectedKeys: ["e00", "none"]))
        XCTAssertNoThrow(try a.validate(expectedKeys: ["e00"]))
    }

    func testChoiceRejectsChoiceThatIsNotArgmax() {
        let a = try! ChoiceAnswer(question: "t",
                                  json: choiceJSON(choice: "e00",
                                                   probs: ["e00": 0.2, "e01": 0.8], conf: 0.5))
        XCTAssertThrowsError(try a.validate(expectedKeys: ["e00", "e01"])) { error in
            guard case AnswerError.choiceNotArgmax = error else {
                return XCTFail("wrong error: \(error)")
            }
        }
    }

    func testChoiceRejectsTieAtMaximum() {
        let a = try! ChoiceAnswer(question: "t",
                                  json: choiceJSON(choice: "e00",
                                                   probs: ["e00": 0.5, "e01": 0.5], conf: 0.3))
        XCTAssertThrowsError(try a.validate(expectedKeys: ["e00", "e01"])) { error in
            guard case AnswerError.tieAtMaximum = error else {
                return XCTFail("wrong error: \(error)")
            }
        }
    }

    func testChoiceRejectsSumOutOfRange() {
        let a = try! ChoiceAnswer(question: "t",
                                  json: choiceJSON(choice: "e00",
                                                   probs: ["e00": 0.9, "e01": 0.05], conf: 0.5))
        XCTAssertThrowsError(try a.validate(expectedKeys: ["e00", "e01"])) { error in
            guard case AnswerError.sumOutOfRange = error else {
                return XCTFail("wrong error: \(error)")
            }
        }
    }

    func testChoiceRejectsOutOfRangeProbability() {
        let json: [String: Any] = ["type": "choice", "choice": "e00", "confidence": 0.5,
                                   "probabilities": ["e00": 1.4, "e01": -0.4]]
        XCTAssertThrowsError(try ChoiceAnswer(question: "t", json: json))
    }

    // MARK: §5.2 Score — decimal index keys, Noul has no confidence

    func testScoreRequiresDecimalIndexKeysMatchingCriteriaLength() {
        let json: [String: Any] = ["type": "score", "score": 1.0, "confidence": 0.9,
                                   "probabilities": ["0": 0.2, "1": 0.8]]
        // Indices {0,1} exactly match 2 criteria levels.
        let ok = try! ScoreAnswer(question: "r", json: json, levelCount: 2)
        XCTAssertEqual(ok.score, 1.0)
        // Against 3 levels the same distribution is incomplete and must throw
        // rather than being silently accepted.
        XCTAssertThrowsError(try ScoreAnswer(question: "r", json: json, levelCount: 3)) { error in
            guard case AnswerError.keyMismatch = error else {
                return XCTFail("wrong error: \(error)")
            }
        }
    }

    func testScoreRejectsScoreOutsideLevelRange() {
        let json: [String: Any] = ["type": "score", "score": 5.0, "confidence": 0.9,
                                   "probabilities": ["0": 0.2, "1": 0.8]]
        XCTAssertThrowsError(try ScoreAnswer(question: "r", json: json, levelCount: 3))
    }

    func testNoulHasNoConfidenceAndAbsenceIsExpected() {
        let n = try! NoulAnswer(question: "a", json: ["type": "noul", "noul": 0.8])
        XCTAssertEqual(n.noul, 0.8)
        XCTAssertTrue(n.isConfidentlySafe)          // high noul == safe
        let low = try! NoulAnswer(question: "a", json: ["type": "noul", "noul": 0.2])
        XCTAssertFalse(low.isConfidentlySafe)
    }

    func testNoulRejectsOutOfRange() {
        XCTAssertThrowsError(try NoulAnswer(question: "a",
                                            json: ["type": "noul", "noul": 1.4]))
    }

    // MARK: §6.2 canonical token encoding

    func testTokenEncodingIsUnambiguousAcrossFieldBoundaries() {
        // Without length framing, ("ab","c") and ("a","bc") collide.
        let x = CanonicalEncoding.digest(fields: [("a", "bc"), ("b", "c")])
        let y = CanonicalEncoding.digest(fields: [("a", "b"), ("b", "c")])
        XCTAssertNotEqual(x, y)
    }

    func testTokenEncodingIsOrderIndependent() {
        let a = Gate.token(generation: 1, appLaunchID: "L", primitive: .press,
                           handle: Handle(raw: "e00"), arguments: nil, questionVersion: "v1")
        let b = Gate.token(generation: 1, appLaunchID: "L", primitive: .press,
                           handle: Handle(raw: "e00"), arguments: nil, questionVersion: "v1")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 64)     // sha256 hex
    }

    func testTokenChangesWithAnyBoundComponent() {
        let base = Gate.token(generation: 1, appLaunchID: "L", primitive: .press,
                              handle: Handle(raw: "e00"), arguments: nil, questionVersion: "v1")
        XCTAssertNotEqual(base, Gate.token(generation: 2, appLaunchID: "L", primitive: .press,
                                           handle: Handle(raw: "e00"), arguments: nil,
                                           questionVersion: "v1"))
        XCTAssertNotEqual(base, Gate.token(generation: 1, appLaunchID: "OTHER",
                                           primitive: .press, handle: Handle(raw: "e00"),
                                           arguments: nil, questionVersion: "v1"))
        XCTAssertNotEqual(base, Gate.token(generation: 1, appLaunchID: "L",
                                           primitive: .setValue, handle: Handle(raw: "e00"),
                                           arguments: nil, questionVersion: "v1"))
    }

    // MARK: §5.1 text argument rule

    func testTextArgumentTakesFirstQuotedSpanVerbatim() {
        XCTAssertEqual(TextArgument.firstQuotedSpan(#"set field to "cats""#), "cats")
        XCTAssertEqual(TextArgument.firstQuotedSpan(#"a "b" then "c""#), "b")
        XCTAssertNil(TextArgument.firstQuotedSpan("set field to cats"))
    }

    // MARK: §8.3 precedence

    func testRefusalPrecedencePicksTheEarliestCode() {
        XCTAssertEqual(RefusalCode.first([.ambiguousName, .budgetExhausted, .axUnavailable]),
                       .budgetExhausted)
        XCTAssertEqual(RefusalCode.first([.enabledUnknown, .fingerprintChanged]),
                       .fingerprintChanged)
    }

    func testPreflightReadFailedIsInTheTaxonomy() {
        XCTAssertTrue(RefusalCode.allCases.contains(.preflightReadFailed))
        XCTAssertTrue(RefusalCode.precedence.contains(.preflightReadFailed))
    }

    // MARK: fingerprint excludes focus (SPEC §6.2 vs §6.3)

    func testFingerprintIsInvariantToFocus() {
        let a = element("Search", role: "AXTextField")
        let b = element("Search", role: "AXTextField", focused: true)
        XCTAssertEqual(a.fingerprint, b.fingerprint,
                       "focus must not be part of the re-verified fingerprint")
        XCTAssertNotEqual(a.focused, b.focused)
    }

    func testFingerprintIncludesSubrole() {
        let a = element("pw")
        let b = element("pw", subrole: "AXSecureTextField")
        XCTAssertNotEqual(a.fingerprint, b.fingerprint,
                          "a subrole change must invalidate the binding")
    }
}
/// Codex B5: strict numeric handling. A JSON boolean bridges to NSNumber and
/// would otherwise pass a range check as 1.0/0.0.
final class StrictNumberTests: XCTestCase {
    func testBooleanIsRejectedWhereANumberIsRequired() {
        // Swift Bool must never read as 1.0/0.0.
        XCTAssertNil(strictDouble(true))
        XCTAssertNil(strictDouble(false))
        // NSNumber(value: 0) is a CFNumber and is correctly ACCEPTED as 0.0.
        // An earlier revision asserted the opposite, which would have required
        // rejecting legitimate integer probabilities (see StrictNumberJSONTests).
        XCTAssertEqual(strictDouble(NSNumber(value: 0)), 0.0)
        XCTAssertEqual(strictDouble(NSNumber(value: 1.5)), 1.5)
        XCTAssertEqual(strictDouble(NSNumber(value: 3)), 3.0)
        XCTAssertEqual(strictDouble(0.0), 0.0)
        // kCFBooleanTrue/False are CFBoolean and must be rejected.
        XCTAssertNil(strictDouble(kCFBooleanTrue))
        XCTAssertNil(strictDouble(kCFBooleanFalse))
        XCTAssertEqual(strictDouble(1.0), 1.0)
    }

    func testChoiceRejectsBooleanProbability() {
        let json: [String: Any] = ["type": "choice", "choice": "e00", "confidence": 0.9,
                                   "probabilities": ["e00": true, "e01": false]]
        XCTAssertThrowsError(try ChoiceAnswer(question: "t", json: json))
    }

    func testChoiceRejectsOutOfRangeConfidence() {
        for bad in [1.5, -0.1, NSNull()] {
            let json: [String: Any] = ["type": "choice", "choice": "e00",
                                       "confidence": bad,
                                       "probabilities": ["e00": 1.0]]
            XCTAssertThrowsError(try ChoiceAnswer(question: "t", json: json),
                                 "confidence \(bad) must be rejected")
        }
    }

    func testScoreRejectsNonCanonicalIndexKeys() {
        for badKey in ["00", "1.0", "-0", " 1"] {
            let json: [String: Any] = ["type": "score", "score": 0.5, "confidence": 0.9,
                                       "probabilities": [badKey: 0.5, "1": 0.5]]
            XCTAssertThrowsError(try ScoreAnswer(question: "r", json: json, levelCount: 2),
                                 "key '\(badKey)' must be rejected")
        }
    }

    func testUnterminatedQuoteYieldsNoArgument() {
        // B7: an unclosed quote is not an argument; writing it would guess.
        XCTAssertNil(TextArgument.firstQuotedSpan(#"set field to "unterminated"#))
        XCTAssertEqual(TextArgument.firstQuotedSpan(#"set field to "cats""#), "cats")
    }

    func testDestructiveLabelIsExcludedRegardlessOfOperation() {
        var e = CapturedElement(handle: Handle(index: 0), path: "/0", role: "AXButton",
                                subrole: nil, identifier: nil, title: "Delete",
                                elementDescription: nil, value: nil, enabled: .enabled,
                                focused: nil, frame: nil, actions: ["AXPress"])
        XCTAssertNotNil(SemanticExclusions.match(e), "a Delete button is excluded")
        e.title = "Archive"
        XCTAssertNil(SemanticExclusions.match(e), "a benign label is not")
    }

    func testCompletionAmbiguityRefusesRatherThanProceeds() {
        let mid = try! NoulAnswer(question: "a", json: ["type": "noul", "noul": 0.5])
        if case .ambiguous = Gate.completion(mid) {} else { XCTFail("0.5 must be ambiguous") }
        let high = try! NoulAnswer(question: "a", json: ["type": "noul", "noul": 0.9])
        if case .alreadyDone = Gate.completion(high) {} else { XCTFail("0.9 must be done") }
        let low = try! NoulAnswer(question: "a", json: ["type": "noul", "noul": 0.1])
        if case .proceed = Gate.completion(low) {} else { XCTFail("0.1 must proceed") }
    }

    func testNilFrameIsNotEligible() {
        // B3: without geometry we cannot prove the control is on screen.
        let e = CapturedElement(handle: Handle(index: 0), path: "/0", role: "AXButton",
                                subrole: nil, identifier: nil, title: "Archive",
                                elementDescription: nil, value: nil, enabled: .enabled,
                                focused: nil, frame: nil, actions: ["AXPress"])
        XCTAssertFalse(CandidateSelection.isEligible(
            e, screens: [CGRect(x: 0, y: 0, width: 1440, height: 900)]))
    }
}

/// The re-validation found a parser bug of mine: `v is Bool` is true for the
/// JSON integers 0 and 1, so strictDouble rejected every legitimate integer
/// probability. The discriminator must be CFBooleanGetTypeID alone.
final class StrictNumberJSONTests: XCTestCase {
    private func parsed(_ s: String) -> Any {
        try! JSONSerialization.jsonObject(with: Data(s.utf8))
    }

    func testJSONIntegersAreAccepted() {
        let o = parsed(#"{"a":0,"b":1}"#) as! [String: Any]
        XCTAssertEqual(strictDouble(o["a"]!), 0.0)
        XCTAssertEqual(strictDouble(o["b"]!), 1.0)
    }

    func testJSONBooleansAreRejected() {
        let o = parsed(#"{"a":false,"b":true}"#) as! [String: Any]
        XCTAssertNil(strictDouble(o["a"]!))
        XCTAssertNil(strictDouble(o["b"]!))
    }

    func testZeroProbabilitySurvivesEndToEndValidation() {
        // A zero probability is extremely common and must not read as invalid.
        let json: [String: Any] = ["type": "choice", "choice": "e01", "confidence": 0.7,
                                   "probabilities": ["e00": 0.0, "e01": 1.0]]
        let a = try! ChoiceAnswer(question: "t", json: json)
        XCTAssertNoThrow(try a.validate(expectedKeys: ["e00", "e01"]))
        XCTAssertEqual(a.pMax, 1.0)
    }
}
