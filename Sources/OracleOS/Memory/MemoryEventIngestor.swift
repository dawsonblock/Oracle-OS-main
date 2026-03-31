import Foundation

public final class MemoryEventIngestor {
    private let repositoryIndexer: RepositoryIndexer
    private let memoryStore: UnifiedMemoryStore?

    public init(repositoryIndexer: RepositoryIndexer, memoryStore: UnifiedMemoryStore? = nil) {
        self.repositoryIndexer = repositoryIndexer
        self.memoryStore = memoryStore
    }

    public func handle(_ event: DomainEvent) {
        switch event {
        case .fileModified(let payload):
            // TODO: Extract workspace root from path if needed, or assume default
            // For now, trigger re-index
            let pathURL = URL(fileURLWithPath: payload.path)
            let dir = pathURL.deletingLastPathComponent()
            _ = repositoryIndexer.indexIfNeeded(workspaceRoot: dir)
            
        case .commandExecuted(let payload):
            guard let store = memoryStore else { return }
            // Let memory update itself based on command result
            store.recordCommandResult(
                category: payload.commandKind,
                workspaceRoot: FileManager.default.currentDirectoryPath,
                success: payload.status == "success"
            )
            
        default:
            break
        }
    }
}
