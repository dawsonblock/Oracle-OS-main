import Foundation

/// Refactored MemoryEventIngestor using the projection pattern.
/// Transforms domain events into memory mutations via typed projections.
/// Side effects (writes) are returned but not executed by the ingestor.
/// The caller decides whether to execute them immediately or queue them.
public final class MemoryEventIngestor {
    private let repositoryIndexer: RepositoryIndexer
    private let memoryStore: UnifiedMemoryStore?
    private let strategyProjection: StrategyMemoryProjection?
    private let executionProjection: ExecutionMemoryProjection?
    private let patternProjection: PatternMemoryProjection?

    public init(
        repositoryIndexer: RepositoryIndexer,
        memoryStore: UnifiedMemoryStore? = nil
    ) {
        self.repositoryIndexer = repositoryIndexer
        self.memoryStore = memoryStore

        // Initialize projections from the memory store
        if let store = memoryStore {
            self.strategyProjection = StrategyMemoryProjection(store: store.appMemory)
            self.executionProjection = ExecutionMemoryProjection(
                store: ExecutionMemoryStore(store: store.appMemory)
            )
            self.patternProjection = PatternMemoryProjection(
                store: PatternMemoryStore(store: store.appMemory)
            )
        } else {
            self.strategyProjection = nil
            self.executionProjection = nil
            self.patternProjection = nil
        }
    }

    /// Handle a domain event and return computed effects (not executed).
    /// Separates computation (projection) from side effects (execution).
    public func handle(_ event: DomainEvent) -> [MemoryEffect] {
        var effects: [MemoryEffect] = []

        switch event {
        case .fileModified(let payload):
            // Re-index repository on file modifications
            let pathURL = URL(fileURLWithPath: payload.path)
            let dir = pathURL.deletingLastPathComponent()
            _ = repositoryIndexer.indexIfNeeded(workspaceRoot: dir)
            // No memory projection needed for file modifications

        case .commandExecuted(let payload):
            // Project command execution into execution memory
            if let projection = executionProjection {
                let (_, commandEffects) = projection.projectCommandExecution(
                    category: payload.commandKind,
                    workspaceRoot: FileManager.default.currentDirectoryPath,
                    success: payload.status == "success"
                )
                effects.append(contentsOf: commandEffects)
            }

        default:
            break
        }

        return effects
    }

    /// Execute a memory effect synchronously.
    /// Only call this for critical/urgent effects; defer others to background processing.
    public func executeEffect(_ effect: MemoryEffect) throws {
        switch effect.kind {
        case .recordControl:
            try strategyProjection?.executeEffect(effect)
        case .recordFailure:
            try strategyProjection?.executeEffect(effect)
        case .recordCommandResult:
            try executionProjection?.executeEffect(effect)
        }
    }

    /// Batch execute multiple effects.
    /// Effects are sorted by priority (critical first).
    public func executeBatch(_ effects: [MemoryEffect]) throws {
        let sorted = effects.sorted { $0.priority > $1.priority }
        for effect in sorted {
            try executeEffect(effect)
        }
    }

    /// Execute critical/urgent effects synchronously, queue others for deferred processing.
    public func executeWithDeferral(_ effects: [MemoryEffect]) -> (executed: [MemoryEffect], deferred: [MemoryEffect]) {
        let deferred = effects.filter { !$0.isUrgent && !$0.isCritical }
        let immediate = effects.filter { $0.isUrgent || $0.isCritical }

        for effect in immediate {
            try? executeEffect(effect)
        }

        return (executed: immediate, deferred: deferred)
    }
}
