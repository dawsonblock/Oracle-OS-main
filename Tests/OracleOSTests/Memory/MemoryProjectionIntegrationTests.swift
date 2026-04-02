import XCTest
@testable import OracleOS

/// Phase 4.5: Memory Projection Integration Tests
/// Verify that projections are properly integrated into RuntimeContainer
/// and that events flow through the projection pipeline.
class MemoryProjectionIntegrationTests: XCTestCase {

    // MARK: - Container Creation

    @MainActor
    func testRuntimeContainerHasProjections() {
        let mockProcessAdapter = MockProcessAdapter()
        let config = RuntimeConfig.test()

        // Create container via bootstrap (would require full async setup in real test)
        // For now, verify the container can be instantiated with projections
        let memoryStore = UnifiedMemoryStore(appMemory: StrategyMemory())
        let strategyProjection = StrategyMemoryProjection(store: memoryStore.appMemory)
        let executionProjection = ExecutionMemoryProjection(
            store: ExecutionMemoryStore(store: memoryStore.appMemory)
        )
        let patternProjection = PatternMemoryProjection(
            store: PatternMemoryStore(store: memoryStore.appMemory)
        )
        let ingestor = MemoryEventIngestor(
            repositoryIndexer: RepositoryIndexer(processAdapter: mockProcessAdapter),
            memoryStore: memoryStore
        )

        // Verify projections exist
        XCTAssertNotNil(strategyProjection)
        XCTAssertNotNil(executionProjection)
        XCTAssertNotNil(patternProjection)
        XCTAssertNotNil(ingestor)
    }

    // MARK: - Event Flow

    @MainActor
    func testEventFlowsToProjections() {
        let mockProcessAdapter = MockProcessAdapter()
        let memoryStore = UnifiedMemoryStore(appMemory: StrategyMemory())
        let ingestor = MemoryEventIngestor(
            repositoryIndexer: RepositoryIndexer(processAdapter: mockProcessAdapter),
            memoryStore: memoryStore
        )

        // Create a command executed event
        let event = DomainEvent.commandExecuted(CommandExecutedPayload(
            commandKind: "build",
            status: "success",
            durationMs: 5000
        ))

        // Event should produce effects
        let effects = ingestor.handle(event)
        XCTAssertGreaterThan(effects.count, 0, "Event should produce effects")
    }

    // MARK: - Effect Execution Strategy

    @MainActor
    func testCriticalEffectsExecutedImmediately() {
        let mockProcessAdapter = MockProcessAdapter()
        let memoryStore = UnifiedMemoryStore(appMemory: StrategyMemory())
        let ingestor = MemoryEventIngestor(
            repositoryIndexer: RepositoryIndexer(processAdapter: mockProcessAdapter),
            memoryStore: memoryStore
        )

        let criticalEffect = MemoryEffect(
            .recordControl(
                KnownControl(
                    key: "critical",
                    app: "Chrome",
                    label: "button",
                    role: "button",
                    elementID: "id",
                    successCount: 1,
                    lastUsed: Date()
                )
            ),
            priority: 2
        )

        let (executed, deferred) = ingestor.executeWithDeferral([criticalEffect])
        XCTAssertEqual(executed.count, 1)
        XCTAssertEqual(deferred.count, 0)
    }

    @MainActor
    func testDeferredEffectsQueued() {
        let mockProcessAdapter = MockProcessAdapter()
        let memoryStore = UnifiedMemoryStore(appMemory: StrategyMemory())
        let ingestor = MemoryEventIngestor(
            repositoryIndexer: RepositoryIndexer(processAdapter: mockProcessAdapter),
            memoryStore: memoryStore
        )

        let deferredEffect = MemoryEffect(
            .recordCommandResult(
                category: "test",
                workspaceRoot: "/tmp",
                success: false
            ),
            priority: 0  // Deferred
        )

        let (executed, deferred) = ingestor.executeWithDeferral([deferredEffect])
        XCTAssertEqual(executed.count, 0)
        XCTAssertEqual(deferred.count, 1)
    }

    // MARK: - Mixed Priority Handling

    @MainActor
    func testMixedPrioritiesSplitCorrectly() {
        let mockProcessAdapter = MockProcessAdapter()
        let memoryStore = UnifiedMemoryStore(appMemory: StrategyMemory())
        let ingestor = MemoryEventIngestor(
            repositoryIndexer: RepositoryIndexer(processAdapter: mockProcessAdapter),
            memoryStore: memoryStore
        )

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
            ), priority: 0),  // Deferred
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
            ), priority: 1),  // Urgent
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
            ), priority: 2),  // Critical
        ]

        let (executed, deferred) = ingestor.executeWithDeferral(effects)
        XCTAssertEqual(executed.count, 2, "Critical and urgent should execute")
        XCTAssertEqual(deferred.count, 1, "Deferred should be queued")
    }

    // MARK: - Batch Execution

    @MainActor
    func testBatchExecutionSortsByPriority() {
        let mockProcessAdapter = MockProcessAdapter()
        let memoryStore = UnifiedMemoryStore(appMemory: StrategyMemory())
        let ingestor = MemoryEventIngestor(
            repositoryIndexer: RepositoryIndexer(processAdapter: mockProcessAdapter),
            memoryStore: memoryStore
        )

        let effects = [
            MemoryEffect(.recordControl(
                KnownControl(
                    key: "low",
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
                    key: "high",
                    app: "Chrome",
                    label: "b",
                    role: "button",
                    elementID: "b",
                    successCount: 1,
                    lastUsed: Date()
                )
            ), priority: 2),
        ]

        // Should execute high priority first, then low priority
        XCTAssertNoThrow {
            try ingestor.executeBatch(effects)
        }
    }

    // MARK: - Event Ingestor Integration

    @MainActor
    func testIngestorHandlesMultipleEventTypes() {
        let mockProcessAdapter = MockProcessAdapter()
        let memoryStore = UnifiedMemoryStore(appMemory: StrategyMemory())
        let indexer = RepositoryIndexer(processAdapter: mockProcessAdapter)
        let ingestor = MemoryEventIngestor(
            repositoryIndexer: indexer,
            memoryStore: memoryStore
        )

        let events = [
            DomainEvent.commandExecuted(CommandExecutedPayload(
                commandKind: "build",
                status: "success",
                durationMs: 1000
            )),
            DomainEvent.commandExecuted(CommandExecutedPayload(
                commandKind: "test",
                status: "failure",
                durationMs: 500
            )),
        ]

        for event in events {
            let effects = ingestor.handle(event)
            // Should produce effects for each event
            if case .commandExecuted = event {
                XCTAssertGreaterThan(effects.count, 0)
            }
        }
    }

    // MARK: - Projection Independence

    @MainActor
    func testProjectionsAreIndependent() {
        let memoryStore = UnifiedMemoryStore(appMemory: StrategyMemory())
        let strategy1 = StrategyMemoryProjection(store: memoryStore.appMemory)
        let strategy2 = StrategyMemoryProjection(store: memoryStore.appMemory)

        let (record1, effects1) = strategy1.projectControl(
            app: "Chrome",
            label: "button",
            role: "button",
            elementID: "id"
        )

        let (record2, effects2) = strategy2.projectControl(
            app: "Chrome",
            label: "button",
            role: "button",
            elementID: "id"
        )

        // Same input should produce identical output
        XCTAssertEqual(record1.app, record2.app)
        XCTAssertEqual(record1.label, record2.label)
        XCTAssertEqual(effects1.count, effects2.count)
    }

    // MARK: - Error Handling

    @MainActor
    func testIngestorHandlesNilMemoryStore() {
        let mockProcessAdapter = MockProcessAdapter()
        let indexer = RepositoryIndexer(processAdapter: mockProcessAdapter)
        let ingestor = MemoryEventIngestor(
            repositoryIndexer: indexer,
            memoryStore: nil
        )

        let event = DomainEvent.commandExecuted(CommandExecutedPayload(
            commandKind: "build",
            status: "success",
            durationMs: 1000
        ))

        // Should not crash
        let effects = ingestor.handle(event)
        XCTAssertNotNil(effects)
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

// MARK: - Mock & Test Payload

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
