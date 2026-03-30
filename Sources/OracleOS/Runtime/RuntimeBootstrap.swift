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
        let container = try await makeContainer(configuration: configuration)

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
    @available(*, deprecated, message: "Use async makeBootstrappedRuntime() instead")
    nonisolated public static func makeDefault(configuration: RuntimeConfig) throws -> RuntimeContainer {
        // For synchronous contexts, we cannot create MainActor-isolated types.
        // This is deprecated - callers should migrate to async version.
        // Create minimal container without MainActor-dependent services.
        return try makeContainerMinimal(configuration: configuration)
    }

    // MARK: - Internal Assembly
    
    /// Full container creation - requires MainActor for shared services
    private static func makeContainer(configuration: RuntimeConfig) async throws -> RuntimeContainer {
        // Create core components first (not MainActor-dependent)
        let (coreComponents, processAdapter) = try makeCore(configuration: configuration)
        
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
            planner: coreComponents.planner,
            executor: coreComponents.executor,
            commitCoordinator: coreComponents.commitCoordinator,
            eventStore: coreComponents.eventStore,
            reducer: coreComponents.reducer,
            policyEngine: coreComponents.policyEngine,
            processAdapter: processAdapter,
            commandRouter: coreComponents.commandRouter,
            config: configuration,
            traceRecorder: coreComponents.traceRecorder,
            traceStore: coreComponents.traceStore,
            artifactWriter: coreComponents.artifactWriter,
            approvalStore: coreComponents.approvalStore,
            metricsRecorder: coreComponents.metricsRecorder,
            graphStore: graphStore,
            memoryStore: memoryStore,
            stateMemoryIndex: stateMemoryIndex,
            searchController: searchController
        )
    }
    
    /// Minimal container for deprecated sync path
    nonisolated private static func makeContainerMinimal(configuration: RuntimeConfig) throws -> RuntimeContainer {
        let (coreComponents, processAdapter) = try makeCore(configuration: configuration)
        
        // For sync path, we need nonisolated-compatible types
        // These services will need to be lazily created by callers
        return RuntimeContainer(
            planner: coreComponents.planner,
            executor: coreComponents.executor,
            commitCoordinator: coreComponents.commitCoordinator,
            eventStore: coreComponents.eventStore,
            reducer: coreComponents.reducer,
            policyEngine: coreComponents.policyEngine,
            processAdapter: processAdapter,
            commandRouter: coreComponents.commandRouter,
            config: configuration,
            traceRecorder: coreComponents.traceRecorder,
            traceStore: coreComponents.traceStore,
            artifactWriter: coreComponents.artifactWriter,
            approvalStore: coreComponents.approvalStore,
            metricsRecorder: coreComponents.metricsRecorder,
            graphStore: nil,
            memoryStore: nil,
            stateMemoryIndex: nil,
            searchController: nil
        )
    }
    
    /// Core components that don't require MainActor
    private struct CoreComponents {
        let planner: MainPlanner
        let executor: VerifiedExecutor
        let commitCoordinator: CommitCoordinator
        let eventStore: FileEventStore
        let reducer: CompositeStateReducer
        let policyEngine: PolicyEngine
        let commandRouter: CommandRouter
        let traceRecorder: TraceRecorder
        let traceStore: ExperienceStore
        let artifactWriter: FailureArtifactWriter
        let approvalStore: ApprovalStore
        let metricsRecorder: MetricsRecorder
    }

    nonisolated private static func makeCore(configuration: RuntimeConfig) throws -> (CoreComponents, DefaultProcessAdapter) {
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

        // Create shared runtime services ONCE here
        let traceRecorder = TraceRecorder()
        let traceStore = ExperienceStore()
        let artifactWriter = FailureArtifactWriter()
        let approvalStore = ApprovalStore(rootDirectory: configuration.approvalsDirectory)
        let metricsRecorder = MetricsRecorder()
        
        let components = CoreComponents(
            planner: planner,
            executor: executor,
            commitCoordinator: commitCoordinator,
            eventStore: eventStore,
            reducer: compositeReducer,
            policyEngine: policyEngine,
            commandRouter: commandRouter,
            traceRecorder: traceRecorder,
            traceStore: traceStore,
            artifactWriter: artifactWriter,
            approvalStore: approvalStore,
            metricsRecorder: metricsRecorder
        )

        return (components, processAdapter)
    }
}
