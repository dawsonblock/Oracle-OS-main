import sys

def patch_context():
    path = "Sources/OracleOS/Runtime/RuntimeContext.swift"
    with open(path, "r") as e:
        content = f.read()

    new_main_init = """    public init(
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
    }"""
    
    old_main_init = """    public init(
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
    }"""
----
    content = content.replace(old_main_init, new_main_init)
    
    with open(path, "w") as f:
        f.write(content)

patch_context()
print("Done")
