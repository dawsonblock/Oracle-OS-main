import Foundation

/// The authoritative runtime container.
/// All stateful runtime services must be created here once and shared.
/// Do NOT create competing instances of these services elsewhere.
public final class RuntimeContainer: @unchecked Sendable {
    // MARK: - Kernel Services (authoritative execution path)
    public let planner: any Planner
    public let executor: VerifiedExecutor
    public let commitCoordinator: CommitCoordinator
    public let eventStore: any EventStore
    public let reducer: any EventReducer
    public let policyEngine: PolicyEngine
    public let processAdapter: any ProcessAdapter
    public let commandRouter: CommandRouter

    // MARK: - Configuration
    public let config: RuntimeConfig

    // MARK: - Shared Runtime Services (created once, injected everywhere)
    public let traceRecorder: TraceRecorder
    public let traceStore: ExperienceStore
    public let artifactWriter: FailureArtifactWriter
    public let approvalStore: ApprovalStore
    public let metricsRecorder: MetricsRecorder

    // MARK: - Shared Stateful Read-Side Services
    // These require MainActor for creation. Optional for deprecated sync path.
    private let _graphStore: GraphStore?
    private let _memoryStore: UnifiedMemoryStore?
    private let _stateMemoryIndex: StateMemoryIndex?
    private let _searchController: SearchController?
    
    // Lazy creation for deprecated sync path (creates on MainActor when accessed)
    @MainActor
    public var graphStore: GraphStore {
        if let store = _graphStore { return store }
        fatalError("GraphStore not available. Use RuntimeBootstrap.makeBootstrappedRuntime() for full container.")
    }
    
    @MainActor
    public var memoryStore: UnifiedMemoryStore {
        if let store = _memoryStore { return store }
        fatalError("UnifiedMemoryStore not available. Use RuntimeBootstrap.makeBootstrappedRuntime() for full container.")
    }
    
    @MainActor
    public var stateMemoryIndex: StateMemoryIndex {
        if let index = _stateMemoryIndex { return index }
        fatalError("StateMemoryIndex not available. Use RuntimeBootstrap.makeBootstrappedRuntime() for full container.")
    }
    
    @MainActor
    public var searchController: SearchController {
        if let controller = _searchController { return controller }
        fatalError("SearchController not available. Use RuntimeBootstrap.makeBootstrappedRuntime() for full container.")
    }

    // MARK: - Recovery State
    public private(set) var recoveryReport: RecoveryReport?

    public init(
        planner: any Planner,
        executor: VerifiedExecutor,
        commitCoordinator: CommitCoordinator,
        eventStore: any EventStore,
        reducer: any EventReducer,
        policyEngine: PolicyEngine,
        processAdapter: any ProcessAdapter,
        commandRouter: CommandRouter,
        config: RuntimeConfig,
        traceRecorder: TraceRecorder,
        traceStore: ExperienceStore,
        artifactWriter: FailureArtifactWriter,
        approvalStore: ApprovalStore,
        metricsRecorder: MetricsRecorder,
        graphStore: GraphStore?,
        memoryStore: UnifiedMemoryStore?,
        stateMemoryIndex: StateMemoryIndex?,
        searchController: SearchController?
    ) {
        self.planner = planner
        self.executor = executor
        self.commitCoordinator = commitCoordinator
        self.eventStore = eventStore
        self.reducer = reducer
        self.policyEngine = policyEngine
        self.processAdapter = processAdapter
        self.commandRouter = commandRouter
        self.config = config
        self.traceRecorder = traceRecorder
        self.traceStore = traceStore
        self.artifactWriter = artifactWriter
        self.approvalStore = approvalStore
        self.metricsRecorder = metricsRecorder
        self._graphStore = graphStore
        self._memoryStore = memoryStore
        self._stateMemoryIndex = stateMemoryIndex
        self._searchController = searchController
    }

    /// Records the recovery report after startup recovery completes.
    func recordRecovery(_ report: RecoveryReport) {
        self.recoveryReport = report
    }
}

/// Report returned by CommitCoordinator.recoverIfNeeded().
public struct RecoveryReport: Sendable, Equatable {
    public let didRecover: Bool
    public let walEntriesRecovered: Int
    public let eventsReplayed: Int
    public let rebuiltSnapshotID: UUID?
    public let completedAt: Date

    public init(
        didRecover: Bool,
        walEntriesRecovered: Int,
        eventsReplayed: Int,
        rebuiltSnapshotID: UUID?,
        completedAt: Date
    ) {
        self.didRecover = didRecover
        self.walEntriesRecovered = walEntriesRecovered
        self.eventsReplayed = eventsReplayed
        self.rebuiltSnapshotID = rebuiltSnapshotID
        self.completedAt = completedAt
    }

    public static let noRecoveryNeeded = RecoveryReport(
        didRecover: false,
        walEntriesRecovered: 0,
        eventsReplayed: 0,
        rebuiltSnapshotID: nil,
        completedAt: Date()
    )
}

/// Bundle returned by RuntimeBootstrap containing all runtime components.
/// Use this instead of creating RuntimeContext separately.
public struct BootstrappedRuntime: @unchecked Sendable {
    public let container: RuntimeContainer
    public let orchestrator: RuntimeOrchestrator
    public let recoveryReport: RecoveryReport

    public init(container: RuntimeContainer, orchestrator: RuntimeOrchestrator, recoveryReport: RecoveryReport) {
        self.container = container
        self.orchestrator = orchestrator
        self.recoveryReport = recoveryReport
    }
}

