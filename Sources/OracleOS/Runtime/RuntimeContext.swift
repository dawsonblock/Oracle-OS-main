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
        container: RuntimeContainer
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
        self.stateAbstraction = container.stateAbstraction
        self.recoveryEngine = container.recoveryEngine
        self.architectureEngine = container.architectureEngine
        self.experimentManager = container.experimentManager
        self.criticLoop = container.criticLoop
        self.stateAbstractionEngine = container.stateAbstractionEngine

        // External adapters
        self.automationHost = container.automationHost
        self.browserController = container.browserController
        self.browserPageStateBuilder = container.browserPageStateBuilder
    }
}
