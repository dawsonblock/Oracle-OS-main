import Foundation

/// In-memory snapshot store for session-level snapshot persistence.
/// NOTE: This implementation is session-only. Snapshots are not persisted across restarts.
/// For durable storage, replace with SQLite or append-only log backend.
public actor SnapshotStore {
    private var snapshots: [StateSnapshot] = []
    private let maxSnapshots: Int

    public init(maxSnapshots: Int = 100) {
        self.maxSnapshots = maxSnapshots
    }

    public func append(_ snapshot: StateSnapshot) {
        snapshots.append(snapshot)
        if snapshots.count > maxSnapshots {
            snapshots.removeFirst()
        }
    }

    public func latest() -> StateSnapshot? {
        snapshots.last
    }

    public func all() -> [StateSnapshot] {
        snapshots
    }

    public func snapshot(byID id: UUID) -> StateSnapshot? {
        snapshots.first(where: { $0.id == id })
    }

    public func snapshot(atSequence sequenceNumber: Int) -> StateSnapshot? {
        snapshots.first(where: { $0.sequenceNumber == sequenceNumber })
    }

    public func clear() {
        snapshots.removeAll()
    }

    public var count: Int {
        snapshots.count
    }
}
