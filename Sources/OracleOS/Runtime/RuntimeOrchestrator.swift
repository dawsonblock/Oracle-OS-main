import Foundation

/// The single entry point for runtime cycle execution.
/// Coordinates: decide → execute → commit → evaluate
public actor RuntimeOrchestrator: IntentAPI {
    private let container: RuntimeContainer
    private let eventStore: any EventStore
    private let commitCoordinator: CommitCoordinator
    private let planner: any Planner
    private let verifiedExecutor: VerifiedExecutor

    public init(
        eventStore: any EventStore,
        commitCoordinator: CommitCoordinator,
        planner: any Planner = MainPlanner(),
        policyEngine: PolicyEngine = .shared,
        automationHost: AutomationHost? = nil,
        workspaceRunner: WorkspaceRunner? = nil,
        repositoryIndexer: RepositoryIndexer = RepositoryIndexer(),
        postconditionsValidator: PostconditionsValidator = PostconditionsValidator(),
        container: RuntimeContainer? = nil
    ) {
        self.eventStore = eventStore
        self.commitCoordinator = commitCoordinator
        self.planner = planner
        let router = CommandRouter(
            automationHost: automationHost,
            workspaceRunner: workspaceRunner,
            repositoryIndexer: repositoryIndexer
        )
        self.verifiedExecutor = VerifiedExecutor(
            policyEngine: policyEngine,
            commandRouter: router,
            postconditionsValidator: postconditionsValidator
        )
        
        // Use provided container or build a fallback mapping missing pieces
        self.container = container ?? RuntimeContainer(
            planner: planner,
            executor: self.verifiedExecutor,
            commitCoordinator: commitCoordinator,
            eventStore: eventStore,
            reducer: CompositeStateReducer(reducers: []),
            policyEngine: policyEngine,
            processAdapter: DefaultProcessAdapter(),
            commandRouter: router
        )
    }

    public init(container: RuntimeContainer) {
        self.container = container
        self.eventStore = container.eventStore
        self.commitCoordinator = container.commitCoordinator
        self.planner = container.planner
        self.verifiedExecutor = container.executor
    }

    public init(
        eventStore: any EventStore,
        commitCoordinator: CommitCoordinator
    ) {
        self.init(
            eventStore: eventStore,
            commitCoordinator: commitCoordinator,
            planner: MainPlanner(),
            container: nil
        )
    }



    private func evaluate(_ outcome: ExecutionOutcome) async -> EvaluationResult {
        let criticOutcome: CriticOutcome
        switch outcome.status {
        case .success:
            criticOutcome = .success
        case .partialSuccess:
            criticOutcome = .partialSuccess
        case .failed, .preconditionFailed, .postconditionFailed, .policyBlocked:
            criticOutcome = .failure
        }

        let needsRecovery = criticOutcome == .failure

        return EvaluationResult(
            commandID: outcome.commandID,
            criticOutcome: criticOutcome,
            needsRecovery: needsRecovery,
            notes: outcome.verifierReport.notes
        )
    }
}

extension RuntimeOrchestrator {
    public func submitIntent(_ intent: Intent) async throws -> IntentResponse {
        let cycleID = UUID()

        let command: Command
        do {
            let state = WorldStateModel(snapshot: await container.commitCoordinator.snapshot())
            command = try await container.planner.plan(intent: intent, state: state)
        } catch {
            return IntentResponse(
                intentID: intent.id,
                outcome: .failed,
                summary: "Planning failed: \(error.localizedDescription)",
                cycleID: cycleID,
                snapshotID: nil,
                timestamp: Date()
            )
        }

        let executionOutcome: ExecutionOutcome
        do {
            executionOutcome = try await container.executor.execute(command)
        } catch {
            executionOutcome = ExecutionOutcome.failure(from: error, command: command)
        }

        do {
            try await container.commitCoordinator.commit(executionOutcome.events)
        } catch {
            return IntentResponse(
                intentID: intent.id,
                outcome: .partialSuccess,
                summary: "Execution succeeded but commit failed: \(error.localizedDescription)",
                cycleID: cycleID,
                snapshotID: nil,
                timestamp: Date()
            )
        }

        _ = await container.commitCoordinator.snapshot()
        let evaluation = await evaluate(executionOutcome)

        let outcome: IntentResponse.Outcome
        switch executionOutcome.status {
        case .success:
            outcome = .success
        case .failed, .preconditionFailed, .postconditionFailed:
            outcome = .failed
        case .policyBlocked:
            outcome = .failed
        case .partialSuccess:
            outcome = .partialSuccess
        }
        
        return IntentResponse(
            intentID: intent.id,
            outcome: outcome,
            summary: "Intent completed: \(intent.objective) - \(executionOutcome.status.rawValue), critic=\(evaluation.criticOutcome.rawValue)",
            cycleID: cycleID,
            snapshotID: nil,
            timestamp: Date()
        )
    }

    public func queryState() async throws -> RuntimeSnapshot {
        let snapshot = await commitCoordinator.snapshot()
        return RuntimeSnapshot(
            id: UUID(),
            timestamp: Date(),
            cycleCount: 0,
            lastIntentID: nil,
            lastCommandKind: nil,
            status: .idle,
            summary: "Runtime state: \(snapshot.visibleElementCount) visible elements, app: \(snapshot.activeApplication ?? "none")"
        )
    }
}
