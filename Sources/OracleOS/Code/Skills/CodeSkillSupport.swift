import Foundation

public enum CodeSkillResolutionError: Error, Sendable, Equatable {
    case missingWorkspace
    case noRepositorySnapshot
    case noRelevantFiles(String)
    case ambiguousEditTarget(String)

    public var failureClass: FailureClass {
        switch self {
        case .missingWorkspace:
            return .workspaceScopeViolation
        case .noRepositorySnapshot, .noRelevantFiles:
            return .noRelevantFiles
        case .ambiguousEditTarget:
            return .ambiguousEditTarget
        }
    }
}

enum CodeSkillSupport {
    static func workspaceRoot(taskContext: TaskContext, state: WorldState) throws -> URL {
        if let workspaceRoot = taskContext.workspaceRoot {
            return URL(fileURLWithPath: workspaceRoot, isDirectory: true)
        }
        if let snapshotRoot = state.repositorySnapshot?.workspaceRoot {
            return URL(fileURLWithPath: snapshotRoot, isDirectory: true)
        }
        throw CodeSkillResolutionError.missingWorkspace
    }

    static func repositorySnapshot(state: WorldState, workspaceRoot: URL) throws -> RepositorySnapshot {
        if let repositorySnapshot = state.repositorySnapshot {
            return repositorySnapshot
        }
        throw CodeSkillResolutionError.noRepositorySnapshot
    }

    static func preferredPath(
        taskContext: TaskContext,
        state: WorldState,
memoryStore: UnifiedMemoryStore,
        failureOutput: String? = nil
    ) throws -> String {
        let workspaceRoot = try workspaceRoot(taskContext: taskContext, state: state)
        let snapshot = try repositorySnapshot(state: state, workspaceRoot: workspaceRoot)
        let memoryInfluence = MemoryRouter(memoryStore: memoryStore).influence(
            for: MemoryQueryContext(
                taskContext: taskContext,
                worldState: state,
                errorSignature: failureOutput
            )
        )

        if let preferredPath = memoryInfluence.preferredFixPath {
            return preferredPath
        }

        let queryEngine = CodeQueryEngine()
        var rankedMatches: [RankedCodeCandidate] = []
        if let failureOutput, !failureOutput.isEmpty {
            rankedMatches = queryEngine.findLikelyRootCause(
                failureDescription: failureOutput,
                in: snapshot
            )
        }

        if let best = rankedMatches.first {
            if let next = rankedMatches.dropFirst().first,
               abs(best.score - next.score) < 0.15,
               best.path != next.path
            {
                throw CodeSkillResolutionError.ambiguousEditTarget(
                    rankedMatches.prefix(3).map { $0.path }.joined(separator: ", ")
                )
            }
            return best.path
        }

        let fallbackMatches = snapshot.files
                .filter { !$0.isDirectory && ($0.path.hasSuffix(".swift") || $0.path.hasSuffix(".ts") || $0.path.hasSuffix(".js")) }
                .map { $0.path }
        guard let first = fallbackMatches.first else {
            throw CodeSkillResolutionError.noRelevantFiles(taskContext.goal.description)
        }
        if fallbackMatches.count > 1 {
            let rest = fallbackMatches.dropFirst()
            if rest.contains(where: { $0 != first }) {
                throw CodeSkillResolutionError.ambiguousEditTarget(fallbackMatches.prefix(3).joined(separator: ", "))
            }
        }
        return first
    }

    static func command(
        category: CodeCommandCategory,
        workspaceRoot: URL,
        workspaceRelativePath: String? = nil,
        summary: String,
        arguments: [String] = [],
        touchesNetwork: Bool = false
    ) -> CommandPayload {
        let root = workspaceRoot.path
        let path = workspaceRelativePath ?? ""
        switch category {
        case .build:
            return .build(BuildSpec(workspaceRoot: root))
        case .test:
            return .test(TestSpec(workspaceRoot: root))
        case .gitStatus:
            return .git(GitSpec(operation: .status, args: arguments, workspaceRoot: root))
        case .gitCommit:
            return .git(GitSpec(operation: .commit, args: arguments, workspaceRoot: root))
        case .gitBranch:
            return .git(GitSpec(operation: .branch, args: arguments, workspaceRoot: root))
        case .gitPush:
            return .git(GitSpec(operation: .push, args: arguments, workspaceRoot: root))
        case .editFile, .writeFile, .generatePatch:
            return .file(FileMutationSpec(path: path, operation: .write, content: nil, workspaceRoot: root))
        case .openFile:
            return .code(CodeAction(name: "readFile", filePath: path, workspacePath: root))
        case .searchCode, .indexRepository:
            return .code(CodeAction(name: "searchRepository", query: summary, workspacePath: root))
        default:
            return .code(CodeAction(name: category.rawValue, query: summary, workspacePath: root))
        }
    }
}
