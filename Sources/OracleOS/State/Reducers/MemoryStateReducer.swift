import Foundation

public struct MemoryStateReducer: EventReducer {
    public init() {}

    public func apply(events: [EventEnvelope], to state: inout WorldStateModel) {
        for envelope in events {
            guard let event = DomainEventCodec.decode(from: envelope) else { continue }
            guard case .memoryRecorded(let payload) = event else { continue }

            state.update { snapshot in
                snapshot.copy(
                    knowledgeSignals: Array((snapshot.knowledgeSignals + [payload.category]).suffix(20)),
                    notes: Array((snapshot.notes + ["lastMemoryKey=\(payload.key ?? "unknown")"]).suffix(25))
                )
            }
        }
    }
}
