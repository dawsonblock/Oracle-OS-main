import Foundation

public enum RuntimeBootstrap {
    public static func makeDefault(configuration: RuntimeConfig) throws -> RuntimeContainer {
        
        let rootURL = configuration.traceDirectory
        let eventStore = try FileEventStore(root: rootURL)

        let compositeReducer = CompositeStateReducer(reducers: [
            MemoryStateReducer(),
            UIStateReducer(),
            RuntimeStateReducer(),
            ProjectStateReducer()
        ])
        
        let policyEngine = PolicyEngine.shared
        let processAdapter = DefaultProcessAdapter(policyEngine: policyEngine)
        
        let commandRouter = CommandRouter(
            automationHost: nil,
            workspaceRunner: WorkspaceRunner(processAdapter: processAdapter),
            repositoryIndexer: RepositoryIndexer(processAdapter: processAdapter)
        )
        let executor = VerifiedExecutor(
            policyEngine: policyEngine,
            commandRouter: commandRouter,
            postconditionsValidator: PostconditionsValidator()
        )
        
        let commitCoordinator = CommitCoordinator(
            eventStore: eventStore,
            reducers: [compositeReducer]
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
