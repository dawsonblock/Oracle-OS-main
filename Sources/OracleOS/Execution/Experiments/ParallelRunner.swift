import Foundation

public final class ParallelRunner: @unchecked Sendable {
    private let workspaceRunner: WorkspaceRunner
    private let repositoryIndexer: RepositoryIndexer
    private let architectureEngine: ArchitectureEngine

    public init(
        workspaceRunner: WorkspaceRunner,
        repositoryIndexer: RepositoryIndexer,
        architectureEngine: ArchitectureEngine = ArchitectureEngine()
    ) {
        self.workspaceRunner = workspaceRunner
        self.repositoryIndexer = repositoryIndexer
        self.architectureEngine = architectureEngine
    }

    public func run(
        spec: ExperimentSpec,
        experimentsRoot: URL,
        architectureRiskScore: Double
    ) async throws -> [ExperimentResult] {
        let workspaceRoot = URL(fileURLWithPath: spec.workspaceRoot, isDirectory: true)
        let workspaceRunner = self.workspaceRunner
        let repositoryIndexer = self.repositoryIndexer
        let architectureEngine = self.architectureEngine

        return try await withThrowingTaskGroup(of: ExperimentResult.self) { group in
            for candidate in spec.candidates {
                group.addTask {
                    let sandbox = try WorktreeSandbox.create(
                        experimentID: spec.id,
                        candidateID: candidate.id,
                        workspaceRoot: workspaceRoot,
                        experimentsRoot: experimentsRoot
                    )
                    try sandbox.apply(candidate)

                    var results: [CommandResult] = []
                    let buildTool = BuildToolDetector.detect(at: URL(fileURLWithPath: sandbox.sandboxPath, isDirectory: true))
                    let buildCommand = spec.buildCommand ?? BuildToolDetector.defaultBuildCommand(
                        for: buildTool,
                        workspaceRoot: URL(fileURLWithPath: sandbox.sandboxPath, isDirectory: true)
                    )
                    let testCommand = spec.testCommand ?? BuildToolDetector.defaultTestCommand(
                        for: buildTool,
                        workspaceRoot: URL(fileURLWithPath: sandbox.sandboxPath, isDirectory: true)
                    )

                    if let buildCommand {
                        results.append(try await self.convertProcessResult(workspaceRunner.runBuild(buildCommand), spec: buildCommand, category: .build))
                    }
                    if results.allSatisfy(\.succeeded), let testCommand {
                        results.append(try await self.convertProcessResult(workspaceRunner.runTest(testCommand), spec: testCommand, category: .test))
                    }

                    let diffSummary = sandbox.diffSummary()
                    let candidateSnapshot = repositoryIndexer.loadPersistedSnapshot(
                        workspaceRoot: URL(fileURLWithPath: sandbox.sandboxPath, isDirectory: true)
                    ) ?? repositoryIndexer.indexIfNeeded(workspaceRoot: URL(fileURLWithPath: sandbox.sandboxPath, isDirectory: true))
                    let architectureReview = architectureEngine.reviewCandidatePatch(
                        goalDescription: spec.goalDescription,
                        snapshot: candidateSnapshot,
                        candidate: candidate,
                        diffSummary: diffSummary
                    )
                    let effectiveArchitectureRisk = max(architectureRiskScore, architectureReview.riskScore)

                    return ExperimentResult(
                        experimentID: spec.id,
                        candidate: candidate,
                        sandboxPath: sandbox.sandboxPath,
                        commandResults: results,
                        diffSummary: diffSummary,
                        architectureRiskScore: effectiveArchitectureRisk,
                        architectureFindings: architectureReview.findings,
                        refactorProposalID: architectureReview.refactorProposal?.id
                    )
                }
            }

            var collected: [ExperimentResult] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }
    }

    private func convertProcessResult(
        _ result: ProcessResult,
        spec: Any,
        category: CodeCommandCategory
    ) -> CommandResult {
        return CommandResult(
            succeeded: result.exitCode == 0,
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            elapsedMs: result.durationMs,
            workspaceRoot: "", // can be derived if needed
            category: category,
            summary: category == .build ? "build" : "test"
        )
    }
}
