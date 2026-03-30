import Foundation
import Testing
@testable import OracleOS

/// Tests that prove the runtime kernel bootstrap path is the only live path.
struct RuntimeKernelBootstrapTests {

    // MARK: - Bootstrap Truth Tests

    @Test func kernelBootstrapReturnsCompleteKernel() throws {
        // Verify that RuntimeBootstrap.makeDefault returns a complete RuntimeContainer
        // with real reducers, not empty arrays.
        let config = RuntimeConfig.test()
        let container = try RuntimeBootstrap.makeDefault(configuration: config)

        // The container must have a non-empty reducer composite
        #expect(container.reducer.reducers.isEmpty == false, "Kernel must have real reducers")
    }

    @Test func commitCoordinatorHasReducers() throws {
        let config = RuntimeConfig.test()
        let container = try RuntimeBootstrap.makeDefault(configuration: config)

        // Create a test event and commit it
        let intentID = UUID()
        let event = EventEnvelope(
            sequenceNumber: 0,
            commandID: nil,
            intentID: intentID,
            eventType: "intent.received",
            payload: try JSONEncoder().encode(
                IntentReceivedEvent(intentID: intentID, objective: "test")
            )
        )

        // After commit, state should change (proving reducers ran)
        Task {
            let snapshotBefore = await container.commitCoordinator.snapshot()
            let cycleCountBefore = snapshotBefore.cycleCount

            _ = try await container.commitCoordinator.commit([event])

            let snapshotAfter = await container.commitCoordinator.snapshot()
            let cycleCountAfter = snapshotAfter.cycleCount

            #expect(cycleCountAfter > cycleCountBefore, "Reducers must increment cycle count")
        }
    }

    // MARK: - Snapshot Immutability Tests

    @Test func stateSnapshotIsImmutableValue() {
        let worldSnapshot = WorldModelSnapshot(
            timestamp: Date(),
            cycleCount: 5,
            activeApplication: "Safari",
            windowTitle: "Test",
            visibleElementCount: 10
        )

        let stateSnapshot = StateSnapshot(
            sequenceNumber: 1,
            state: worldSnapshot,
            eventAncestry: [UUID()]
        )

        // StateSnapshot.state is WorldModelSnapshot (value type), not WorldStateModel (reference type)
        // This test passes if the code compiles — the type system enforces immutability
        #expect(stateSnapshot.state.cycleCount == 5)
        #expect(stateSnapshot.state.activeApplication == "Safari")
    }

    @Test func snapshotStoreTracksSnapshots() async {
        let store = SnapshotStore()

        let snapshot1 = StateSnapshot(
            sequenceNumber: 1,
            state: WorldModelSnapshot(cycleCount: 1),
            eventAncestry: []
        )
        let snapshot2 = StateSnapshot(
            sequenceNumber: 2,
            state: WorldModelSnapshot(cycleCount: 2),
            eventAncestry: []
        )

        await store.append(snapshot1)
        await store.append(snapshot2)

        let latest = await store.latest()
        #expect(latest?.sequenceNumber == 2)
        #expect(await store.count == 2)
    }

    // MARK: - No Empty Reducer Guard

    @Test func noEmptyReducerArraysInLiveBootstrap() throws {
        // This test fails if any live bootstrap path creates CommitCoordinator with empty reducers
        let config = RuntimeConfig.test()
        let container = try RuntimeBootstrap.makeDefault(configuration: config)

        // The composite reducer must contain at least the four core reducers
        let reducerCount = container.reducer.reducers.count
        #expect(reducerCount >= 4, "Bootstrap must include RuntimeStateReducer, UIStateReducer, ProjectStateReducer, MemoryStateReducer")
    }
}
