import Foundation

@MainActor
public enum RuntimeBootstrap {

    // MARK: - Primary Entry Point

    /// Creates a fully bootstrapped runtime with recovery completed.
    /// This is the ONLY authorized way to create the runtime.
    /// All entry points (MCP, Controller, CLI) MUST use this.
    public static func makeBootstrappedRuntime(
        configuration: RuntimeConfig = .live()
    ) async throws -> BootstrappedRuntime {
        let container = try makeContainer(configuration: configuration)

        // Run recovery BEFORE runtime becomes available
        let recoveryReport = try await container.commitCoordinator.recoverIfNeeded()
        container.recordRecovery(recoveryReport)

        let orchestrator = RuntimeOrchestrator(container: container)

        return BootstrappedRuntime(
            container: container,
            orchestrator: orchestrator,
            recoveryReport: recoveryReport
        )
    }

    /// Synchronous bootstrap for contexts that cannot await.
    /// Recovery will be run on first use. Prefer async version.
    @available(*, unavailable, message: "Use async makeBootstrappedRuntime() instead across all surfaces")
    public static func makeDefault(configuration: RuntimeConfig) throws -> RuntimeContainer {
        return try makeContainer(configuration: configuration)
    }

    // MARK: - Internal Assembly
    
    /// Full container creation with all shared services
    private static func makeContainer(configuration: RuntimeConfig) throws -> RuntimeContainer {
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

        let workspaceRunner = WorkspaceRunner(processAdapter: processAdapter)
        let repositoryIndexer = RepositoryIndexer(processAdapter: processAdapter)

        let commandRouter = CommandRouter(
            automationHost: nil,
            workspaceRunner: workspaceRunner,
            repositoryIndexer: repositoryIndexer
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

        // Create shared runtime services ONCE here
        let traceRecorder = TraceRecorder()
        let traceStore = ExperienceStore()
        let artifactWriter = FailureArtifactWriter()
        let approvalStore = ApprovalStore(rootDirectory: configuration.approvalsDirectory)
        let metricsRecorder = MetricsRecorder()
        
        // Create shared stateful read-side services (MainActor-dependent)
        let graphStore = GraphStore()
        let memoryStore = UnifiedMemoryStore()
        let stateMemoryIndex = StateMemoryIndex()
        let searchController = SearchController(
            generator: CandidateGenerator(
                stateMemoryIndex: stateMemoryIndex,
                graphStore: graphStore
            )
        )

        return RuntimeContainer(
            planner: planner,
            executor: executor,
            commitCoordinator: commitCoordinator,
            eventStore: eventStore,
            reducer: compositeReducer,
            policyEngine: policyEngine,
            processAdapter: processAdapter,
            commandRouter: commandRouter,
            workspaceRunner: workspaceRunner,
            repositoryIndexer: repositoryIndexer,
            config: configuration,
            traceRecorder: traceRecorder,
            traceStore: traceStore,
            artifactWriter: artifactWriter,
            approvalStore: approvalStore,
            metricsRecorder: metricsRecorder,
            graphStore: graphStore,
            memoryStore: memoryStore,
            stateMemoryIndex: stateMemoryIndex,
            searchController: searchController
        )
    }
}
