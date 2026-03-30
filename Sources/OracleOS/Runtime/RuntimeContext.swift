import Foundation

/// RuntimeContext provides peripheral services and adapters for the runtime environment.
/// NOTE: This is NOT the authoritative execution kernel. RuntimeKernel owns execution truth.
/// RuntimeContext provides integration services like tracing, memory, browser control, etc.
///
/// IMPORTANT: RuntimeContext must receive services from RuntimeContainer.
/// Do NOT create services here that should be shared across the runtime.
@MainActor
public final class RuntimeContext {
    // MARK: - Configuration
    public let config: RuntimeConfig

    // MARK: - Tracing & Observability
    public let traceRecorder: TraceRecorder
    public let traceStore: ExperienceStore
    public let artifactWriter: FailureArtifactWriter
    public let metricsRecorder: MetricsRecorder
    public private(set) lazy var telemetry: RuntimeTelemetry = RuntimeTelemetry(context: self)

    // MARK: - Peripheral Services (not execution-critical)
    public let approvalStore: ApprovalStore
    public let graphStore: GraphStore
    public let memoryStore: UnifiedMemoryStore
    public let stateAbstraction: StateAbstraction
    public let recoveryEngine: RecoveryEngine
    public let architectureEngine: ArchitectureEngine
    public let experimentManager: ExperimentManager
    public let stateMemoryIndex: StateMemoryIndex
    public let searchController: SearchController
    public let criticLoop: CriticLoop
    public let stateAbstractionEngine: StateAbstractionEngine

    // MARK: - External Adapters (browser, automation)
    public let automationHost: AutomationHost
    public let browserController: BrowserController
    public let browserPageStateBuilder: BrowserPageStateBuilder

    // MARK: - Execution Adapters (from kernel, not owned here)
    public let policyEngine: PolicyEngine
    public let workspaceRunner: WorkspaceRunner
    public let repositoryIndexer: RepositoryIndexer

    /// Primary initializer: creates RuntimeContext from a RuntimeContainer.
    /// This ensures all shared services come from the same authority.
    public init(
        container: RuntimeContainer,
        automationHost: AutomationHost = .live(),
        browserController: BrowserController = BrowserController(),
        browserPageStateBuilder: BrowserPageStateBuilder = BrowserPageStateBuilder(),
        stateAbstraction: StateAbstraction = StateAbstraction(),
        recoveryEngine: RecoveryEngine = RecoveryEngine(),
        architectureEngine: ArchitectureEngine = ArchitectureEngine(),
        experimentManager: ExperimentManager = ExperimentManager(),
        criticLoop: CriticLoop = CriticLoop(),
        stateAbstractionEngine: StateAbstractionEngine = StateAbstractionEngine()
    ) {
        // Pull shared services from container - single source of truth
        self.config = container.config
        self.traceRecorder = container.traceRecorder
        self.traceStore = container.traceStore
        self.artifactWriter = container.artifactWriter
        self.metricsRecorder = container.metricsRecorder
        self.approvalStore = container.approvalStore
        self.graphStore = container.graphStore
        self.memoryStore = container.memoryStore
        self.stateMemoryIndex = container.stateMemoryIndex
        self.searchController = container.searchController
        self.policyEngine = container.policyEngine
        self.workspaceRunner = container.workspaceRunner
        self.repositoryIndexer = container.repositoryIndexer

        // Peripheral services that don't need sharing
        self.stateAbstraction = stateAbstraction
        self.recoveryEngine = recoveryEngine
        self.architectureEngine = architectureEngine
        self.experimentManager = experimentManager
        self.criticLoop = criticLoop
        self.stateAbstractionEngine = stateAbstractionEngine

        // External adapters
        self.automationHost = automationHost
        self.browserController = browserController
        self.browserPageStateBuilder = browserPageStateBuilder
    }

    @available(*, unavailable, message: "Use init(container:) with RuntimeBootstrap.makeBootstrappedRuntime()")
    public init(
        config: RuntimeConfig = .live(),
        traceRecorder: TraceRecorder,
        traceStore: ExperienceStore,
        artifactWriter: FailureArtifactWriter,
        policyEngine: PolicyEngine,
        approvalStore: ApprovalStore,
        graphStore: GraphStore = GraphStore(),
        memoryStore: UnifiedMemoryStore = UnifiedMemoryStore(),
        stateAbstraction: StateAbstraction = StateAbstraction(),
        recoveryEngine: RecoveryEngine = RecoveryEngine(),
        workspaceRunner: WorkspaceRunner = WorkspaceRunner(),
        repositoryIndexer: RepositoryIndexer = RepositoryIndexer(),
        architectureEngine: ArchitectureEngine = ArchitectureEngine(),
        experimentManager: ExperimentManager = ExperimentManager(),
        automationHost: AutomationHost = .live(),
        browserController: BrowserController = BrowserController(),
        browserPageStateBuilder: BrowserPageStateBuilder = BrowserPageStateBuilder(),
        stateMemoryIndex: StateMemoryIndex = StateMemoryIndex(),
        searchController: SearchController? = nil,
        metricsRecorder: MetricsRecorder = MetricsRecorder()
    ) {
        self.config = config
        self.traceRecorder = traceRecorder
        self.traceStore = traceStore
        self.artifactWriter = artifactWriter
        self.policyEngine = policyEngine
        self.approvalStore = approvalStore
        self.graphStore = graphStore
        self.memoryStore = memoryStore
        self.stateAbstraction = stateAbstraction
        self.recoveryEngine = recoveryEngine
        self.workspaceRunner = workspaceRunner
        self.repositoryIndexer = repositoryIndexer
        self.architectureEngine = architectureEngine
        self.experimentManager = experimentManager
        self.automationHost = automationHost
        self.browserController = browserController
        self.browserPageStateBuilder = browserPageStateBuilder
        self.stateMemoryIndex = stateMemoryIndex
        self.searchController = searchController ?? SearchController(
            generator: CandidateGenerator(
                stateMemoryIndex: stateMemoryIndex,
                graphStore: graphStore
            )
        )
        self.metricsRecorder = metricsRecorder
        self.criticLoop = CriticLoop()
        self.stateAbstractionEngine = StateAbstractionEngine()
    }

    @available(*, unavailable, message: "Use RuntimeBootstrap.makeBootstrappedRuntime() and init(container:)")
    public static func live(
        config: RuntimeConfig = .live(),
        traceRecorder: TraceRecorder,
        traceStore: ExperienceStore,
        artifactWriter: FailureArtifactWriter,
        policyEngine: PolicyEngine? = nil,
        workspaceRunner: WorkspaceRunner? = nil,
        repositoryIndexer: RepositoryIndexer? = nil
    ) -> RuntimeContext {
        fatalError("RuntimeContext.live() is no longer available. Use RuntimeBootstrap.makeBootstrappedRuntime()")
    }
}
