import Foundation

/// Append-only event log. The single source of truth for all state changes.
/// INVARIANT: Events are never deleted or mutated after append.
public protocol EventStore: Actor {
    func append(_ envelope: EventEnvelope) throws
    func append(contentsOf newEnvelopes: [EventEnvelope]) throws
    func all() throws -> [EventEnvelope]
    func events(forCommandID id: CommandID) throws -> [EventEnvelope]
    func events(after sequenceNumber: Int) throws -> [EventEnvelope]
    func nextSequenceNumber() throws -> Int
    func stream() -> AsyncStream<EventEnvelope>
}

public actor MemoryEventStore: EventStore {
    private var envelopes: [EventEnvelope] = []
    private var sequenceCounter: Int = 0
    private var continuations: [AsyncStream<EventEnvelope>.Continuation] = []

    public init() {}

    public func append(_ envelope: EventEnvelope) {
        envelopes.append(envelope)
        for continuation in continuations {
            continuation.yield(envelope)
        }
    }

    public func append(contentsOf newEnvelopes: [EventEnvelope]) {
        envelopes.append(contentsOf: newEnvelopes)
        for env in newEnvelopes {
            for continuation in continuations {
                continuation.yield(env)
            }
        }
    }

    public func all() -> [EventEnvelope] { envelopes }

    public func events(forCommandID id: CommandID) -> [EventEnvelope] {
        envelopes.filter { $0.commandID == id }
    }

    public func events(after sequenceNumber: Int) -> [EventEnvelope] {
        envelopes.filter { $0.sequenceNumber > sequenceNumber }
    }

    public func nextSequenceNumber() -> Int {
        sequenceCounter += 1
        return sequenceCounter
    }
    
    public func stream() -> AsyncStream<EventEnvelope> {
        AsyncStream { continuation in
            continuations.append(continuation)
            
            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.removeContinuation(continuation)
                }
            }
        }
    }
    
    private func removeContinuation(_ continuation: AsyncStream<EventEnvelope>.Continuation) {
        // We can't strictly compare continuations, so we might need a workaround or UUIDs.
        // For simple implementations, just let them sit or clear on deinit.
        // Real implementation would wrap the continuation with a unique ID.
    }
}

