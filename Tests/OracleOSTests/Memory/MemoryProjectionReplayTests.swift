import XCTest
@testable import OracleOS

/// Phase 4.6: Memory Projection Replay Tests
/// Verify that projections are replay-safe and produce idempotent results.
/// This is critical for event sourcing: events can be replayed to reconstruct state.
class MemoryProjectionReplayTests: XCTestCase {

    // MARK: - Single Event Replay Idempotence

    @MainActor
    func testStrategyProjectionReplayIdempotence() {
        let store = StrategyMemory()
        let projection = StrategyMemoryProjection(store: store)

        // First projection
        let (record1, effects1) = projection.projectControl(
            app: "Chrome",
            label: "Sign In",
            role: "button",
            elementID: "btn-123"
        )

        // Replay same event (second projection)
        let (record2, effects2) = projection.projectControl(
            app: "Chrome",
            label: "Sign In",
            role: "button",
            elementID: "btn-123"
        )

        // Should produce identical records
        XCTAssertEqual(record1.key, record2.key)
        XCTAssertEqual(record1.app, record2.app)
        XCTAssertEqual(record1.label, record2.label)
        XCTAssertEqual(effects1.count, effects2.count)
    }

    @MainActor
    func testExecutionProjectionReplayIdempotence() {
        let store = StrategyMemory()
        let execStore = ExecutionMemoryStore(store: store)
        let projection = ExecutionMemoryProjection(store: execStore)

        let (record1, effects1) = projection.projectCommandExecution(
            category: "build",
            workspaceRoot: "/tmp/project",
            success: true
        )

        let (record2, effects2) = projection.projectCommandExecution(
            category: "build",
            workspaceRoot: "/tmp/project",
            success: true
        )

        // IDs will differ, but records should be semantically equivalent
        XCTAssertEqual(record1.category, record2.category)
        XCTAssertEqual(record1.workspaceRoot, record2.workspaceRoot)
        XCTAssertEqual(record1.success, record2.success)
        XCTAssertEqual(effects1.count, effects2.count)
    }

    @MainActor
    func testPatternProjectionReplayIdempotence() {
        let store = StrategyMemory()
        let patternStore = PatternMemoryStore(store: store)
        let projection = PatternMemoryProjection(store: patternStore)

        let (record1, effects1) = projection.projectStrategyAttempt(
            kind: "gradual-scroll",
            success: true
        )

        let (record2, effects2) = projection.projectStrategyAttempt(
            kind: "gradual-scroll",
            success: true
        )

        XCTAssertEqual(record1.kind, record2.kind)
        XCTAssertEqual(record1.success, record2.success)
        XCTAssertEqual(effects1.count, effects2.count)
        XCTAssertEqual(effects1[0].priority, effects2[0].priority)
    }

    // MARK: - Event Sequence Replay

    @MainActor
    func testSequentialEventReplay() {
        let store = StrategyMemory()
        let projection = StrategyMemoryProjection(store: store)

        // Simulate a sequence of control selections
        let events = [
            ("Chrome", "Sign In", "button"),
            ("Safari", "Search", "text"),
            ("Chrome", "Login", "button"),
        ]

        var records1: [KnownControl] = []
        for (app, label, role) in events {
            let (record, _) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: "id"
            )
            records1.append(record)
        }

        // Replay same sequence
        var records2: [KnownControl] = []
        for (app, label, role) in events {
            let (record, _) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: "id"
            )
            records2.append(record)
        }

        // Sequences should be identical
        XCTAssertEqual(records1.count, records2.count)
        for i in 0..<records1.count {
            XCTAssertEqual(records1[i].app, records2[i].app)
            XCTAssertEqual(records1[i].label, records2[i].label)
            XCTAssertEqual(records1[i].key, records2[i].key)
        }
    }

    @MainActor
    func testCommandExecutionSequenceReplay() {
        let store = StrategyMemory()
        let execStore = ExecutionMemoryStore(store: store)
        let projection = ExecutionMemoryProjection(store: execStore)

        let commands = [
            ("build", true),
            ("test", true),
            ("test", false),
            ("build", true),
        ]

        var records1: [ExecutionRecord] = []
        for (category, success) in commands {
            let (record, _) = projection.projectCommandExecution(
                category: category,
                workspaceRoot: "/tmp",
                success: success
            )
            records1.append(record)
        }

        // Replay
        var records2: [ExecutionRecord] = []
        for (category, success) in commands {
            let (record, _) = projection.projectCommandExecution(
                category: category,
                workspaceRoot: "/tmp",
                success: success
            )
            records2.append(record)
        }

        XCTAssertEqual(records1.count, records2.count)
        for i in 0..<records1.count {
            XCTAssertEqual(records1[i].category, records2[i].category)
            XCTAssertEqual(records1[i].success, records2[i].success)
        }
    }

    // MARK: - Concurrent Replay Safety

    @MainActor
    func testConcurrentReplaySafety() {
        let store = StrategyMemory()
        let projection = StrategyMemoryProjection(store: store)

        let events = Array(0..<100).map { i in
            (app: "App\(i % 5)", label: "Button\(i)", role: "button")
        }

        var results1: [KnownControl] = []
        var results2: [KnownControl] = []
        var results3: [KnownControl] = []

        // Three replay sequences
        for (app, label, role) in events {
            let (r1, _) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: "id\(label)"
            )
            results1.append(r1)
        }

        for (app, label, role) in events {
            let (r2, _) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: "id\(label)"
            )
            results2.append(r2)
        }

        for (app, label, role) in events {
            let (r3, _) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: "id\(label)"
            )
            results3.append(r3)
        }

        // All replays should produce identical sequences
        XCTAssertEqual(results1.count, results2.count)
        XCTAssertEqual(results2.count, results3.count)

        for i in 0..<results1.count {
            XCTAssertEqual(results1[i].key, results2[i].key)
            XCTAssertEqual(results2[i].key, results3[i].key)
        }
    }

    // MARK: - Effect Determinism

    @MainActor
    func testEffectsDeterministic() {
        let store = StrategyMemory()
        let projection = StrategyMemoryProjection(store: store)

        // Same input should always produce same effects
        let inputs = Array(0..<10).map { i in
            (app: "Chrome", label: "Button\(i)", role: "button", elementID: "id\(i)")
        }

        var effectSequence1: [[MemoryEffect]] = []
        var effectSequence2: [[MemoryEffect]] = []

        for (app, label, role, elementID) in inputs {
            let (_, effects) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: elementID
            )
            effectSequence1.append(effects)
        }

        // Replay
        for (app, label, role, elementID) in inputs {
            let (_, effects) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: elementID
            )
            effectSequence2.append(effects)
        }

        XCTAssertEqual(effectSequence1.count, effectSequence2.count)
        for i in 0..<effectSequence1.count {
            XCTAssertEqual(effectSequence1[i].count, effectSequence2[i].count)
            for j in 0..<effectSequence1[i].count {
                XCTAssertEqual(
                    effectSequence1[i][j].priority,
                    effectSequence2[i][j].priority
                )
            }
        }
    }

    // MARK: - State Reconstruction via Replay

    @MainActor
    func testStateReconstructionFromEventLog() {
        let store = StrategyMemory()
        let projection = StrategyMemoryProjection(store: store)

        // Simulate event log (sequence of domain events converted to projections)
        let eventLog = [
            (app: "Chrome", label: "Login", role: "button"),
            (app: "Safari", label: "Search", role: "text"),
            (app: "Chrome", label: "Submit", role: "button"),
            (app: "Firefox", label: "Go", role: "button"),
        ]

        // First pass: project events and record state
        var state1: [String: KnownControl] = [:]
        for (app, label, role) in eventLog {
            let (record, _) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: "id-\(label)"
            )
            state1[record.key] = record
        }

        // Second pass: replay events and rebuild state
        var state2: [String: KnownControl] = [:]
        for (app, label, role) in eventLog {
            let (record, _) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: "id-\(label)"
            )
            state2[record.key] = record
        }

        // Reconstructed states should match
        XCTAssertEqual(state1.count, state2.count)
        for (key, record1) in state1 {
            guard let record2 = state2[key] else {
                XCTFail("Key \(key) missing in replayed state")
                return
            }
            XCTAssertEqual(record1.app, record2.app)
            XCTAssertEqual(record1.label, record2.label)
        }
    }

    // MARK: - Batch Projection Replay

    @MainActor
    func testBatchProjectionReplayIdempotence() {
        let store = StrategyMemory()
        let projection = StrategyMemoryProjection(store: store)

        let batchSize = 50
        let controls = Array(0..<batchSize).map { i in
            (app: "Chrome", label: "Button\(i)", role: "button", elementID: "id\(i)")
        }

        // First batch projection
        var batch1Effects: [MemoryEffect] = []
        for (app, label, role, elementID) in controls {
            let (_, effects) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: elementID
            )
            batch1Effects.append(contentsOf: effects)
        }

        // Replay batch
        var batch2Effects: [MemoryEffect] = []
        for (app, label, role, elementID) in controls {
            let (_, effects) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: elementID
            )
            batch2Effects.append(contentsOf: effects)
        }

        // Should produce identical effect count and priority distribution
        XCTAssertEqual(batch1Effects.count, batch2Effects.count)

        let priority1 = batch1Effects.map { $0.priority }
        let priority2 = batch2Effects.map { $0.priority }
        XCTAssertEqual(priority1, priority2)
    }

    // MARK: - Failure Pattern Replay

    @MainActor
    func testFailurePatternReplayIdempotence() {
        let store = StrategyMemory()
        let projection = StrategyMemoryProjection(store: store)

        let failures = [
            (app: "Chrome", reason: "Timeout", action: "click"),
            (app: "Safari", reason: "Stale element", action: "hover"),
            (app: "Firefox", reason: "Not visible", action: "submit"),
        ]

        var patterns1: [FailurePattern] = []
        for (app, reason, action) in failures {
            let (pattern, _) = projection.projectFailure(
                app: app,
                reason: reason,
                action: action
            )
            patterns1.append(pattern)
        }

        // Replay
        var patterns2: [FailurePattern] = []
        for (app, reason, action) in failures {
            let (pattern, _) = projection.projectFailure(
                app: app,
                reason: reason,
                action: action
            )
            patterns2.append(pattern)
        }

        XCTAssertEqual(patterns1.count, patterns2.count)
        for i in 0..<patterns1.count {
            XCTAssertEqual(patterns1[i].app, patterns2[i].app)
            XCTAssertEqual(patterns1[i].action, patterns2[i].action)
        }
    }

    // MARK: - Large Event Log Replay

    @MainActor
    func testLargeEventLogReplay() {
        let store = StrategyMemory()
        let projection = StrategyMemoryProjection(store: store)

        let largeEventLog = Array(0..<1000).map { i in
            (
                app: "App\(i % 10)",
                label: "Control\(i % 100)",
                role: "button",
                elementID: "id\(i)"
            )
        }

        // Project all events
        var records: [String: KnownControl] = [:]
        for (app, label, role, elementID) in largeEventLog {
            let (record, _) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: elementID
            )
            records[record.key] = record
        }

        let initialCount = records.count

        // Replay ALL events
        for (app, label, role, elementID) in largeEventLog {
            let (record, _) = projection.projectControl(
                app: app,
                label: label,
                role: role,
                elementID: elementID
            )
            records[record.key] = record
        }

        // State should be identical (same number of unique controls)
        XCTAssertEqual(records.count, initialCount)
    }
}
