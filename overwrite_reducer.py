import os

content = """import Foundation

public struct RuntimeStateReducer: EventReducer {
    public init() {}

    public func apply(events: [EventEnvelope], to state: inout WorldStateModel) {
        for envelope in events {
            guard let event = DomainEventCodec.decode(from: envelope) else { continue }

            state.update { snapshot in
                switch event {
                case .intentReceived(let payload):
                    return snapshot.copy(
                        cycleCount: snapshot.cycleCount + 1,
                        notes: Array((snapshot.notes + ["lastIntentID=\\(payload.intentID.uuidString)"]).suffix(25))
                    )

                case .planGenerated(let payload):
                    return snapshot.copy(
                        notes: Array((snapshot.notes + ["lastCommandKind=\\(payload.commandKind)"]).suffix(25))
                    )

                case .commandExecuted(let payload):
                    return snapshot.copy(
                        notes: Array((snapshot.notes + ["lastExecutionStatus=\\(payload.status)"] + payload.notes.prefix(3)).suffix(25))
                    )

                case .commandFailed(let payload):
                    var notes = snapshot.notes
                    notes.append("lastFailure=\\(payload.error)")
                    if let kind = payload.commandKind {
                        notes.append("lastCommandKind=\\(kind)")
                    }
                    return snapshot.copy(notes: Array(notes.suffix(25)))

                case .evaluationCompleted(let payload):
                    return snapshot.copy(
                        notes: Array((snapshot.notes + ["criticOutcome=\\(payload.criticOutcome)"]).suffix(25))
                    )

                default:
                    return snapshot
                }
            }
        }
    }
}
"""

os.makedirs(os.path.dirname('Sources/OracleOS/State/Reducers/RuntimeStateReducer.swift'), exist_ok=True)
with open('Sources/OracleOS/State/Reducers/RuntimeStateReducer.swift', 'w') as f:
    f.write(content)
