import Foundation

public enum RuntimeBootstrap {
    public static func makeDefault(configuration: RuntimeConfig) throws -> RuntimeContainer {
        
        let rootURL = configuration.traceDirectory

        // Create WAL first for crash safety
        let wal = try CommitWAL(root: rootURL)
        let eventStore = try FileEventStore(root: rootURL)

        let compositeReducer = CompositeStateReducer(reducers: [
            MemoryStateReducer(),
            UIStateReducer(),
            RuntimeStateReducer(),
            ProjectStateReducer()
        ])

        // Create CommitCoordinator with WAL
        let commitCoordinator = CommitCoordinator(
            eventStore: eventStore,
            reducers: [compositeReducer],
            wal: wal
        )

        // Create WorldStateProvider that reads from CommitCoordinator
        let stateProvider = RuntimeWorldStateProvider { [weak commitCoordinator] in
            await commitCoordinator?.currentState ?? WorldStateModel()
        }
        
        let policyEngine = PolicyEngine.shared
        let processAdapter = DefaultProcessAdapter(policyEngine: policyEngine)
        
        let commandRouter = CommandRouter(
            automationHost: nil,
            workspaceRunner: WorkspaceRunner(processAdapter: processAdapter),
            repositoryIndexer: RepositoryIndexer(processAdapter: processAdapter)
        )

        // Create executor with state provider and preconditions
        let executor = VerifiedExecutor(
            policyEngine: policyEngine,
            commandRouter: commandRouter,
            preconditionsValidator: PreconditionsValidator(),
            postconditionsValidator: PostconditionsValidator(),
            stateProvider: stateProvider
        )
        
        let planner = MainPlanner()

        return RuntimeContainer(
            planner: planner,
            executor: executor,
            commitCoordinator: commitCoordinator,
            eventStore: eventStore,
            reducer: compositeReducer,
            policyEngine: policyEngine,
            processAdapter: processAdapter,
            commandRouter: commandRouter
        )
    }
}
