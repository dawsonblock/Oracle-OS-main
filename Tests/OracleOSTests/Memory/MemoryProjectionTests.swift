import XCTest
@testable import OracleOS

/// Phase 4: Memory Projection Tests
/// Verify that projections transform events into effects without executing side effects.
class MemoryProjectionTests: XCTestCase {

    // MARK: - Strategy Memory Projection

    func testStrategyProjectionCreatesControlRecord() {
        let store = StrategyMemory()
        let projection = StrategyMemoryProjection(store: store)

        let (record, effects) = projection.projectControl(
            app: "Chrome",
            label: "Sign in button",
            role: "button",
            elementID: "btn-123"
        )

        XCTAssertEqual(record.app, "Chrome")
        XCTAssertEqual(record.label, "Sign in button")
        XCTAssertEqual(effects.count, 1)
        XCTAssertTrue(effects[0].isUrgent)
    }

    func testStrategyProjectionCreatesFailureRecord() {
        let store = StrategyMemory()
        let projection = StrategyMemoryProjection(store: store)

        let (record, effects) = projection.projectFailure(
            app: "Chrome",
            reason: "Element became stale",
            action: "click"
        )

        XCTAssertEqual(record.app, "Chrome")
        XCTAssertEqual(effects.count, 1)
        XCTAssertTrue(effects[0].isUrgent)
    }

    func testStrategyProjectionEffectContainsControl() {
        let store = StrategyMemory()
        let projection = StrategyMemoryProjection(store: store)

        let (_, effects) = projection.projectControl(
            app: "Chrome",
            label: "button",
            role: "button",
            elementID: "id"
        )

        guard case .recordControl(let control) = effects[0].kind else {
            XCTFail("Effect should be recordControl")
            return
        }

        XCTAssertEqual(control.app, "Chrome")
    }

    func testStrategyProjectionEffectContainsFailure() {
        let store = StrategyMemory()
        let projection = StrategyMemoryProjection(store: store)

        let (_, effects) = projection.projectFailure(
            app: "Chrome",
            reason: "Timeout",
            action: "click"
        )

        guard case .recordFailure(let failure) = effects[0].kind else {
            XCTFail("Effect should be recordFailure")
            return
        }

        XCTAssertEqual(failure.app, "Chrome")
    }

    // MARK: - Execution Memory Projection

    func testExecutionProjectionCreatesRecord() {
        let store = StrategyMemory()
        let execStore = ExecutionMemoryStore(store: store)
        let projection = ExecutionMemoryProjection(store: execStore)

        let (record, effects) = projection.projectCommandExecution(
            category: "build",
            workspaceRoot: "/tmp/project",
            success: true
        )

        XCTAssertEqual(record.category, "build")
        XCTAssertEqual(record.workspaceRoot, "/tmp/project")
        XCTAssertTrue(record.success)
        XCTAssertEqual(effects.count, 1)
    }

    func testExecutionProjectionDeferredEffect() {
        let store = StrategyMemory()
        let execStore = ExecutionMemoryStore(store: store)
        let projection = ExecutionMemoryProjection(store: execStore)

        let (_, effects) = projection.projectCommandExecution(
            category: "test",
            workspaceRoot: "/tmp",
            success: false
        )

        // Failed commands are deferred (priority = 0)
        XCTAssertFalse(effects[0].isUrgent)
    }

    // MARK: - Pattern Memory Projection

    func testPatternProjectionSuccessPriority() {
        let store = StrategyMemory()
        let patternStore = PatternMemoryStore(store: store)
        let projection = PatternMemoryProjection(store: patternStore)

        let (_, successEffects) = projection.projectStrategyAttempt(
            kind: "gradual-scroll",
            success: true
        )

        let (_, failureEffects) = projection.projectStrategyAttempt(
            kind: "gradual-scroll",
            success: false
        )

        XCTAssertTrue(successEffects[0].isUrgent, "Successful patterns should be urgent")
        XCTAssertFalse(failureEffects[0].isUrgent, "Failed patterns should be deferred")
    }

    // MARK: - Effect Types

    func testMemoryEffectCriticalFlag() {
        let critical = MemoryEffect(.recordControl(
            KnownControl(
                key: "test",
                app: "test",
                label: nil,
                role: nil,
                elementID: nil,
                successCount: 1,
                lastUsed: Date()
            )
        ), priority: 2)

        let urgent = MemoryEffect(.recordControl(
            KnownControl(
                key: "test",
                app: "test",
                label: nil,
                role: nil,
                elementID: nil,
                successCount: 1,
                lastUsed: Date()
            )
        ), priority: 1)

        let deferred = MemoryEffect(.recordControl(
            KnownControl(
                key: "test",
                app: "test",
                label: nil,
                role: nil,
                elementID: nil,
                successCount: 1,
                lastUsed: Date()
            )
        ), priority: 0)

        XCTAssertTrue(critical.isCritical)
        XCTAssertTrue(critical.isUrgent)
        
        XCTAssertFalse(urgent.isCritical)
        XCTAssertTrue(urgent.isUrgent)
        
        XCTAssertFalse(deferred.isCritical)
        XCTAssertFalse(deferred.isUrgent)
    }

    // MARK: - MemoryEventIngestor

    func testIngestorReturnsEffects() {
        let store = StrategyMemory()
        let unifiedStore = UnifiedMemoryStore(appMemory: store)
        let indexer = RepositoryIndexer(processAdapter: MockProcessAdapter())
        let ingestor = MemoryEventIngestor(repositoryIndexer: indexer, memoryStore: unifiedStore)

        let event = DomainEvent.commandExecuted(CommandExecutedPayload(
            commandKind: "build",
            status: "success",
            durationMs: 5000
        ))

        let effects = ingestor.handle(event)
        XCTAssertGreaterThan(effects.count, 0, "Ingestor should return effects from projection")
    }

    func testIngestorWithoutStore() {
        let indexer = RepositoryIndexer(processAdapter: MockProcessAdapter())
        let ingestor = MemoryEventIngestor(repositoryIndexer: indexer, memoryStore: nil)

        let event = DomainEvent.commandExecuted(CommandExecutedPayload(
            commandKind: "build",
            status: "success",
            durationMs: 5000
        ))

        let effects = ingestor.handle(event)
        // Should not crash without a memory store
        XCTAssertNotNil(effects)
    }

    func testEffectExecution() {
        let store = StrategyMemory()
        let unifiedStore = UnifiedMemoryStore(appMemory: store)
        let indexer = RepositoryIndexer(processAdapter: MockProcessAdapter())
        let ingestor = MemoryEventIngestor(repositoryIndexer: indexer, memoryStore: unifiedStore)

        let control = KnownControl(
            key: "test",
            app: "Chrome",
            label: "button",
            role: "button",
            elementID: "id",
            successCount: 1,
            lastUsed: Date()
        )
        let effect = MemoryEffect(.recordControl(control), priority: 1)

        // Should not throw
        XCTAssertNoThrow {
            try ingestor.executeEffect(effect)
        }
    }

    func testBatchExecution() {
        let store = StrategyMemory()
        let unifiedStore = UnifiedMemoryStore(appMemory: store)
        let indexer = RepositoryIndexer(processAdapter: MockProcessAdapter())
        let ingestor = MemoryEventIngestor(repositoryIndexer: indexer, memoryStore: unifiedStore)

        let effects = [
            MemoryEffect(.recordControl(
                KnownControl(
                    key: "1",
                    app: "Chrome",
                    label: "a",
                    role: "button",
                    elementID: "a",
                    successCount: 1,
                    lastUsed: Date()
                )
            ), priority: 0),
            MemoryEffect(.recordControl(
                KnownControl(
                    key: "2",
                    app: "Chrome",
                    label: "b",
                    role: "button",
                    elementID: "b",
                    successCount: 1,
                    lastUsed: Date()
                )
            ), priority: 2),
        ]

        XCTAssertNoThrow {
            try ingestor.executeBatch(effects)
        }
    }

    func testExecuteWithDeferral() {
        let store = StrategyMemory()
        let unifiedStore = UnifiedMemoryStore(appMemory: store)
        let indexer = RepositoryIndexer(processAdapter: MockProcessAdapter())
        let ingestor = MemoryEventIngestor(repositoryIndexer: indexer, memoryStore: unifiedStore)

        let effects = [
            MemoryEffect(.recordControl(
                KnownControl(
                    key: "1",
                    app: "Chrome",
                    label: "a",
                    role: "button",
                    elementID: "a",
                    successCount: 1,
                    lastUsed: Date()
                )
            ), priority: 0),
            MemoryEffect(.recordControl(
                KnownControl(
                    key: "2",
                    app: "Chrome",
                    label: "b",
                    role: "button",
                    elementID: "b",
                    successCount: 1,
                    lastUsed: Date()
                )
            ), priority: 1),
            MemoryEffect(.recordControl(
                KnownControl(
                    key: "3",
                    app: "Chrome",
                    label: "c",
                    role: "button",
                    elementID: "c",
                    successCount: 1,
                    lastUsed: Date()
                )
            ), priority: 2),
        ]

        let (executed, deferred) = ingestor.executeWithDeferral(effects)

        XCTAssertEqual(deferred.count, 1, "One deferred effect (priority 0)")
        XCTAssertEqual(executed.count, 2, "Two executed effects (priority >= 1)")
    }

    // MARK: - Helper

    private func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
        do {
            _ = try expression()
        } catch {
            XCTFail("Expected no throw, but got: \(error)", file: file, line: line)
        }
    }
}

// MARK: - Mock

private struct CommandExecutedPayload {
    let commandKind: String
    let status: String
    let durationMs: Int
}

private class MockProcessAdapter: ProcessAdapter {
    func execute(_ spec: CommandPayload) throws -> CommandResult {
        fatalError()
    }
}
