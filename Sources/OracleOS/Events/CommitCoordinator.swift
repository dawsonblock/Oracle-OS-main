import Foundation

/// Orchestrates the commit flow: appends events → runs reducers → emits new snapshot.
/// INVARIANT: No state write may bypass CommitCoordinator.
public actor CommitCoordinator {
    private let eventStore: EventStore
    private let reducers: [any EventReducer]
    private let wal: CommitWAL?
    private(set) var currentState: WorldStateModel

    /// Recovery state to ensure idempotent startup
    private enum RecoveryState {
        case notStarted
        case running
        case completed(RecoveryReport)
    }
    private var recoveryState: RecoveryState = .notStarted

    public init(
        eventStore: EventStore,
        reducers: [any EventReducer],
        wal: CommitWAL? = nil,
        initialState: WorldStateModel = WorldStateModel()
    ) {
        self.eventStore = eventStore
        self.reducers = reducers
        self.wal = wal
        self.currentState = initialState
    }

    /// Recover any pending commits from WAL after crash.
    /// MUST be called at startup before accepting new commits.
    /// Idempotent: subsequent calls return the same report.
    @discardableResult
    public func recoverIfNeeded() async throws -> RecoveryReport {
        // Return cached result if already completed
        if case .completed(let report) = recoveryState {
            return report
        }

        // Guard against concurrent recovery
        guard case .notStarted = recoveryState else {
            // Wait for ongoing recovery - return no-op report
            return .noRecoveryNeeded
        }

        recoveryState = .running

        guard let wal = wal, let pending = try wal.readPending() else {
            let report = RecoveryReport.noRecoveryNeeded
            recoveryState = .completed(report)
            return report
        }

        // Replay pending events to event store
        try await eventStore.append(contentsOf: pending)
        for reducer in reducers {
            reducer.apply(events: pending, to: &currentState)
        }
        try wal.clear()

        let report = RecoveryReport(
            didRecover: true,
            walEntriesRecovered: pending.count,
            eventsReplayed: pending.count,
            rebuiltSnapshotID: UUID(),
            completedAt: Date()
        )
        recoveryState = .completed(report)
        return report
    }

    public func commit(_ envelopes: [EventEnvelope]) async throws -> CommitReceipt {
        guard !envelopes.isEmpty else {
            throw CommitError.emptyCommit
        }

        // Assign sequence numbers to envelopes before appending
        var numberedEnvelopes = envelopes
        for i in 0..<numberedEnvelopes.count {
            let seq = try await eventStore.nextSequenceNumber()
            // Create new envelope with sequence number (struct is immutable)
            let old = numberedEnvelopes[i]
            numberedEnvelopes[i] = EventEnvelope(
                id: old.id,
                sequenceNumber: seq,
                commandID: old.commandID,
                intentID: old.intentID,
                timestamp: old.timestamp,
                eventType: old.eventType,
                payload: old.payload
            )
        }

        // Write to WAL before appending to event store
        if let wal = wal {
            try wal.writePending(numberedEnvelopes)
        }

        try await eventStore.append(contentsOf: numberedEnvelopes)

        // Clear WAL after successful append
        if let wal = wal {
            try wal.clear()
        }

        for reducer in reducers {
            reducer.apply(events: numberedEnvelopes, to: &currentState)
        }

        return CommitReceipt(
            firstSequenceNumber: numberedEnvelopes.first?.sequenceNumber ?? 0,
            lastSequenceNumber: numberedEnvelopes.last?.sequenceNumber ?? 0,
            eventIDs: numberedEnvelopes.map(\.id),
            snapshotID: UUID(),
            summary: "Committed \(numberedEnvelopes.count) event(s)"
        )
    }

    /// Returns a copy of the current state to prevent direct mutation.
    /// Returns WorldModelSnapshot (value type) from the model's snapshot property.
    public func snapshot() -> WorldModelSnapshot {
        // WorldStateModel.snapshot returns WorldModelSnapshot (a struct/value type)
        // This is the safe way to expose state without giving mutable access
        return currentState.snapshot
    }
}
