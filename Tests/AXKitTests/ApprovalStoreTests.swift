import XCTest

@testable import AXKit

/// Minimal atomic counter; NSLock is enough and avoids NSMutableArray's
/// `count` shadowing under Swift 6.
final class Counter: @unchecked Sendable {
    final class Cell: @unchecked Sendable {
        private var n = 0
        private let lock = NSLock()
        func increment() { lock.lock(); n += 1; lock.unlock() }
        var value: Int { lock.lock(); defer { lock.unlock() }; return n }
    }
    let succeeded = Cell()
    let failed = Cell()
}

/// Hermetic: every case uses a disposable temp directory. No desktop, no
/// network, no shared state.
final class ApprovalStoreTests: XCTestCase {

    private var dir: URL!
    private var store: ApprovalStore!

    override func setUpWithError() throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("jevscope-test-\(UUID().uuidString)")
        store = ApprovalStore(root: dir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func record(token: String = String(repeating: "a", count: 64),
                        generation: Int = 1,
                        arguments: String? = nil,
                        thresholds: String = "thresholds-v1") -> ApprovalRecord {
        ApprovalRecord(token: token, generation: generation,
                       appBundleID: "com.example.x", appLaunchID: "123:1.0",
                       elementPath: "/0/1/2",
                       elementFingerprint: Fingerprint(role: "AXButton", subrole: nil,
                                                        identifier: nil, title: "Archive",
                                                        elementDescription: nil),
                       primitive: .press, arguments: arguments,
                       thresholdsDigest: thresholds, questionVersion: "v1")
    }

    // MARK: single use

    func testIssuedRecordIsConsumableExactlyOnce() throws {
        let rec = record()
        try store.issue(rec)
        _ = try store.consume(rec.token)
        XCTAssertThrowsError(try store.consume(rec.token)) { error in
            guard case ApprovalError.alreadyConsumed = error else {
                return XCTFail("second consume must fail as alreadyConsumed, got \(error)")
            }
        }
    }

    func testConsumedStateIsPersisted() throws {
        let rec = record()
        try store.issue(rec)
        _ = try store.consume(rec.token)
        let reloaded = try store.load(rec.token)
        XCTAssertEqual(reloaded.state, .consumed,
                       "consumption must survive a fresh load, not just in memory")
    }

    func testConcurrentConsumeAdmitsExactlyOneWinner() throws {
        let rec = record()
        try store.issue(rec)

        // 32 threads racing to consume the same token.
        let counter = Counter()
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            do {
                _ = try self.store.consume(rec.token)
                counter.succeeded.increment()
            } catch {
                counter.failed.increment()
            }
        }
        XCTAssertEqual(counter.succeeded.value, 1,
                       "atomic consumption must admit exactly one dispatch")
        XCTAssertEqual(counter.failed.value, 31)
    }

    // MARK: expiry

    func testExpiredRecordIsRefused() throws {
        let rec = record()
        try store.issue(rec)
        let later = rec.issuedAt.addingTimeInterval(ApprovalStore.validitySeconds + 1)
        XCTAssertThrowsError(try store.consume(rec.token, now: later)) { error in
            guard case ApprovalError.expired = error else {
                return XCTFail("expected expired, got \(error)")
            }
        }
    }

    func testJustInsideValidityIsStillConsumable() throws {
        let rec = record()
        try store.issue(rec)
        let inside = rec.issuedAt.addingTimeInterval(ApprovalStore.validitySeconds - 1)
        XCTAssertNoThrow(try store.consume(rec.token, now: inside))
    }

    // MARK: binding

    func testUnknownTokenIsNotFound() {
        XCTAssertThrowsError(try store.consume(String(repeating: "f", count: 64))) { error in
            guard case ApprovalError.notFound = error else {
                return XCTFail("expected notFound, got \(error)")
            }
        }
    }

    func testMalformedTokenIsRejectedBeforeAnyFileAccess() {
        XCTAssertThrowsError(try store.load("../../etc/passwd")) { error in
            guard case ApprovalError.notFound = error else {
                return XCTFail("path traversal must be rejected, got \(error)")
            }
        }
        XCTAssertThrowsError(try store.load("short"))
    }

    func testBindingMismatchOnEveryComponent() throws {
        let base = record()
        try store.issue(base)
        func expectMismatch(_ other: ApprovalRecord, _ what: String) {
            XCTAssertThrowsError(try store.verify(base, against: other),
                                 "\(what) must invalidate the record") { error in
                guard case ApprovalError.bindingMismatch = error else {
                    return XCTFail("\(what): expected bindingMismatch, got \(error)")
                }
            }
        }
        var g = base; g.generation = 2
        expectMismatch(g, "generation")
        var l = base; l.appLaunchID = "999:9"
        expectMismatch(l, "appLaunchID")
        var p = base; p.elementPath = "/9/9/9"
        expectMismatch(p, "elementPath")
        var f = base; f.elementFingerprint.title = "Delete"
        expectMismatch(f, "fingerprint")
        var t = base; t.thresholdsDigest = "thresholds-v2"
        expectMismatch(t, "thresholds")
        var q = base; q.questionVersion = "v2"
        expectMismatch(q, "questionVersion")
    }

    func testIdentityRecordRoundTripsIncludingLiteralArguments() throws {
        // setValue needs the argument TEXT, not only its digest (Codex B3 note).
        let rec = record(arguments: "cats")
        try store.issue(rec)
        let back = try store.load(rec.token)
        XCTAssertEqual(back.arguments, "cats")
        XCTAssertEqual(back.argumentsDigest, Gate.sha256Hex("cats"))
        XCTAssertNil(record().arguments, "press must carry no argument text")
    }

    func testPurgeRemovesOldRecordsOnly() throws {
        let old = ApprovalRecord(token: String(repeating: "a", count: 64),
                                 generation: 1, appBundleID: "c", appLaunchID: "l",
                                 elementPath: "/0",
                                 elementFingerprint: Fingerprint(role: "AXButton", subrole: nil,
                                                                 identifier: nil, title: "t",
                                                                 elementDescription: nil),
                                 primitive: .press, arguments: nil,
                                 thresholdsDigest: "t", questionVersion: "v1",
                                 issuedAt: Date(timeIntervalSinceNow: -7200))
        try store.issue(old)
        store.purge(olderThan: 3600, now: Date())
        XCTAssertThrowsError(try store.load(old.token))
    }

    // MARK: trace redaction (SPEC §10.3)

    func testTraceCarriesDigestsNotText() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("jevscope-trace-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let w = TraceWriter(directory: dir)
        let tmp = URL(fileURLWithPath: w.path)
        var e = TraceEntry(phase: "decide")
        e.decision = "act press e00"
        e.token = String(repeating: "b", count: 64)
        e.goalDigest = Gate.sha256Hex("send my password hunter2")
        e.goalLength = 24
        e.requestDigest = Gate.sha256Hex("{\"secret\":\"body\"}")
        w.write(e)
        let text = (try? String(contentsOf: tmp, encoding: .utf8)) ?? ""
        XCTAssertFalse(text.contains("hunter2"), "raw goal text must never be written")
        XCTAssertFalse(text.contains("secret"), "raw request body must never be written")
        XCTAssertTrue(text.contains("goalDigest"))
        XCTAssertTrue(text.contains("requestDigest"))
        XCTAssertEqual(text.split(separator: "\n").count, 1, "one JSON object per line")
    }
}
/// SPEC §8.4: the scripted backend makes the dangerous paths testable, and the
/// ACTION LOG COUNT is the assertion — not the message.
final class ScriptedBackendTests: XCTestCase {

    private func element(_ title: String, path: String,
                         focused: Bool = false) -> CapturedElement {
        CapturedElement(handle: Handle(index: 0), path: path, role: "AXButton",
                        subrole: nil, identifier: nil, title: title,
                        elementDescription: nil, value: nil, enabled: .enabled,
                        focused: focused, frame: Frame(x: 10, y: 10, width: 80, height: 30),
                        actions: ["AXPress"])
    }

    func testSameRoleReplacementInvalidatesTheFingerprint() throws {
        let b = ScriptedBackend(elements: [element("Archive", path: "/0")],
                               events: [.replaceSameRole(path: "/0")])
        // Read BEFORE via the snapshot, which does not consume the event.
        let before = try b.snapshot(appBundleID: "x", generation: 1).elements[0]
        _ = try b.supports(.press, on: before)      // this applies the event
        let after = try b.reAcquire(path: "/0")
        XCTAssertEqual(before.role, after.role, "the role is deliberately unchanged")
        XCTAssertNotEqual(before.fingerprint, after.fingerprint,
                          "a same-role swap must change the fingerprint")
        XCTAssertEqual(b.actionLog.count, 0)
    }

    func testRowReuseChangesValue() throws {
        let b = ScriptedBackend(elements: [element("Row", path: "/0")],
                               events: [.reuseRow(path: "/0")])
        let before = try b.snapshot(appBundleID: "x", generation: 1).elements[0]
        _ = try b.supports(.press, on: before)
        let after = try b.reAcquire(path: "/0")
        XCTAssertEqual(after.value, "a different document")
        XCTAssertEqual(b.actionLog.count, 0)
    }

    func testAppRestartChangesLaunchIdentity() throws {
        let b = ScriptedBackend(elements: [element("Archive", path: "/0")],
                               events: [.appRestart])
        let before = try b.launchID(appBundleID: "x")
        _ = try b.supports(.press, on: try b.reAcquire(path: "/0"))
        let after = try b.launchID(appBundleID: "x")
        XCTAssertNotEqual(before, after, "a restart must invalidate the binding")
        XCTAssertEqual(b.actionLog.count, 0)
    }

    func testSelectionChangeLeavesFingerprintIntactButIsDetectable() throws {
        let b = ScriptedBackend(elements: [element("Archive", path: "/0", focused: false)],
                               events: [.changeSelection])
        let before = try b.snapshot(appBundleID: "x", generation: 1).elements[0]
        _ = try b.supports(.press, on: before)
        let after = try b.reAcquire(path: "/0")
        XCTAssertEqual(before.fingerprint, after.fingerprint,
                       "selection is not part of the fingerprint by design")
        XCTAssertNotEqual(before.focused, after.focused,
                          "which is exactly why focus needs a live recheck")
    }

    func testTargetBecomingFocusedIsRefusedWithAnEmptyActionLog() throws {
        let b = ScriptedBackend(elements: [element("Field", path: "/0", focused: true)],
                               events: [.targetBecomesFocused])
        XCTAssertThrowsError(
            try b.revalidatePredicate(for: element("Field", path: "/0"),
                                     primitive: .setValue))
        XCTAssertEqual(b.actionLog.count, 0,
                       "B12: a refusal must leave the action log empty")
    }

    func testPreflightReadFailureIsRefusedWithAnEmptyActionLog() throws {
        let b = ScriptedBackend(elements: [element("Archive", path: "/0")],
                               events: [.preflightReadFails(attribute: "AXEnabled")])
        XCTAssertThrowsError(
            try b.revalidatePredicate(for: element("Archive", path: "/0"),
                                     primitive: .press))
        XCTAssertEqual(b.actionLog.count, 0)
    }

    func testCannotCompleteRecordsExactlyOneDispatch() throws {
        // The unknown-outcome counterpart to the empty-log refusal assertions.
        let b = ScriptedBackend(elements: [element("Archive", path: "/0")],
                               events: [.dispatchCannotComplete])
        XCTAssertThrowsError(try b.dispatch(.press, on: element("Archive", path: "/0"),
                                            arguments: nil)) { error in
            guard case AXBackendError.dispatchedUnknownOutcome = error else {
                return XCTFail("expected unknownOutcome, got \(error)")
            }
        }
        XCTAssertEqual(b.actionLog.count, 1, "unknown outcome means dispatched ONCE")
    }

    func testPlainDispatchLogsExactlyOnce() throws {
        let b = ScriptedBackend(elements: [element("Archive", path: "/0")])
        _ = try b.dispatch(.press, on: element("Archive", path: "/0"), arguments: nil)
        XCTAssertEqual(b.actionLog.count, 1)
        XCTAssertEqual(b.actionLog.first?.primitive, "press")
    }
}
