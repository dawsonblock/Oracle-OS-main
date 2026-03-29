import Foundation

public final class RuntimeContainer: @unchecked Sendable {
    public let planner: any Planner
    public let executor: VerifiedExecutor
    public let commitCoordinator: CommitCoordinator
    public let eventStore: any EventStore
    public let reducer: any EventReducer
    public let policyEngine: PolicyEngine
    public let processAdapter: ProcessAdapter
    public let commandRouter: CommandRouter

    public init(
        planner: any Planner,
        executor: VerifiedExecutor,
        commitCoordinator: CommitCoordinator,
        eventStore: any EventStore,
        reducer: any EventReducer,
        policyEngine: PolicyEngine,
        processAdapter: ProcessAdapter,
        commandRouter: CommandRouter
    ) {
        self.planner = planner
        self.executor = executor
        self.commitCoordinator = commitCoordinator
        self.eventStore = eventStore
        self.reducer = reducer
        self.policyEngine = policyEngine
        self.processAdapter = processAdapter
        self.commandRouter = commandRouter
    }
}

