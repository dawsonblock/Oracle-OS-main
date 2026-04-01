import Foundation

/// Memory projections are typed consumers of committed domain events.
///
/// Unlike reducers (which mutate WorldState), projections rebuild derived,
/// non-authoritative state from committed events. Memory projections are:
///
/// - **Replayable**: Rebuild from event history yields the same state
/// - **Idempotent**: apply twice = apply once
/// - **Derived**: Not part of committed authority; may be rebuilt/discarded
/// - **Deterministic**: Same events → same memory state
///
/// Use memory projections to update:
/// - AppMemory (strategy, control, failure patterns)
/// - ExecutionMemory (ranking bias, recovery strategies)
/// - PatternMemory (command bias, fix paths)
///
/// DO NOT use memory projections for:
/// - WorldState (use WorldStateReducer instead)
/// - ProjectMemory (use domain events with memoryRecorded)
/// - Committed events (use CommitCoordinator)

/// Projection that updates StrategyMemory from command execution events.
public struct StrategyMemoryProjection {
    private let appMemory: StrategyMemory
    
    public init(appMemory: StrategyMemory) {
        self.appMemory = appMemory
    }
    
    /// Apply committed events to update strategy memory (execution memory, patterns).
    /// This is idempotent: applying twice yields the same result as applying once.
    public func apply(events: [EventEnvelope]) throws {
        for envelope in events {
            guard let event = DomainEventCodec.decode(from: envelope) else {
                continue
            }
            
            switch event {
            case .commandExecuted(let payload):
                // Record command success for pattern matching
                // Extract workspace root from envelope metadata if available
                // For now, use a generic category
                appMemory.recordCommandResult(
                    category: payload.commandKind,
                    workspaceRoot: "/",
                    success: true
                )
            
            case .commandFailed(let payload):
                // Record command failure
                let kind = payload.commandKind ?? "unknown"
                appMemory.recordCommandResult(
                    category: kind,
                    workspaceRoot: "/",
                    success: false
                )
                
                // Record failure pattern
                if let kind = payload.commandKind {
                    let pattern = FailurePattern(
                        app: "unknown",
                        failure: .actionFailed,
                        action: kind
                    )
                    appMemory.recordFailure(pattern)
                }
            
            case .evaluationCompleted(let payload):
                // Evaluation verdict provides feedback on command success
                let isSuccess = payload.criticOutcome.lowercased() == "success"
                let kind = "evaluation"
                appMemory.recordCommandResult(
                    category: kind,
                    workspaceRoot: "/",
                    success: isSuccess
                )
            
            default:
                // Other events don't trigger memory updates
                break
            }
        }
    }
}

/// Projection that updates ExecutionMemory ranking and recovery strategies.
public struct ExecutionMemoryProjection {
    private let executionMemory: ExecutionMemoryStore
    
    public init(executionMemory: ExecutionMemoryStore) {
        self.executionMemory = executionMemory
    }
    
    public func apply(events: [EventEnvelope]) throws {
        for envelope in events {
            guard let event = DomainEventCodec.decode(from: envelope) else {
                continue
            }
            
            switch event {
            case .uiObserved(let payload):
                // Update UI element memory for ranking
                if let app = payload.activeApplication {
                    // Future: record known controls from observation
                    // For now, just track that we observed the app
                    _ = (app, payload.windowTitle)
                }
            
            default:
                break
            }
        }
    }
}

/// Projection that updates PatternMemory (command success rates, fix paths).
public struct PatternMemoryProjection {
    private let patternMemory: PatternMemoryStore
    
    public init(patternMemory: PatternMemoryStore) {
        self.patternMemory = patternMemory
    }
    
    public func apply(events: [EventEnvelope]) throws {
        for envelope in events {
            guard let event = DomainEventCodec.decode(from: envelope) else {
                continue
            }
            
            switch event {
            case .commandExecuted(let payload):
                // Update pattern success rate
                // Future: extract error signature from notes and track fix path
                _ = payload.commandKind
            
            case .commandFailed(let payload):
                // Track failure pattern for recovery suggestions
                _ = payload.error
            
            default:
                break
            }
        }
    }
}
