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
            // Use an explicit workspace root instead of deriving it from the file path.
            // Align with commandExecuted, which uses the current working directory.
            let workspaceRootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            _ = repositoryIndexer.indexIfNeeded(workspaceRoot: workspaceRootURL)
            
        case .commandExecuted(let payload):
            guard let store = memoryStore else { return }
            // Let memory update itself based on command result
            store.recordCommandResult(
                category: payload.commandKind,
                workspaceRoot: payload.workspaceRoot,
                success: payload.status == "success"
            )
            
        default:
            break
        }
    }
}
