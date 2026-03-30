import sys

def patch_container():
    path = "Sources/OracleOS/Runtime/RuntimeContainer.swift"
    with open(path, "r") as f:
        content = f.read()

    new_fields = """    // MARK: - Peripheral Services
    public let stateAbstraction: StateAbstraction
    public let recoveryEngine: RecoveryEngine
    public let architectureEngine: ArchitectureEngine
    public let experimentManager: ExperimentManager
    public let criticLoop: CriticLoop
    public let stateAbstractionEngine: StateAbstractionEngine
    
    // MARK: - External Adapters
    public let automationHost: AutomationHost
    public let browserController: BrowserController
    public let browserPageStateBuilder: BrowserPageStateBuilder
    
    // MARK: - Recovery State"""
    
    new_args = """        searchController: SearchController,
        stateAbstraction: StateAbstraction,
        recoveryEngine: RecoveryEngine,
        architectureEngine: ArchitectureEngine,
        experimentManager: ExperimentManager,
        criticLoop: CriticLoop,
        stateAbstractionEngine: StateAbstractionEngine,
        automationHost: AutomationHost,
        browserController: BrowserController,
        browserPageStateBuilder: BrowserPageStateBuilder
    ) {"""

    new_assigns = """        self.searchController = searchController
        self.stateAbstraction = stateAbstraction
        self.recoveryEngine = recoveryEngine
        self.architectureEngine = architectureEngine
        self.experimentManager = experimentManager
        self.criticLoop = criticLoop
        self.stateAbstractionEngine = stateAbstractionEngine
        self.automationHost = automationHost
        self.browserController = browserController
        self.browserPageStateBuilder = browserPageStateBuilder
    }"""
    
    content = content.replace("    // MARK: - Recovery State", new_fields)
    content = content.replace("        searchController: SearchController\n    ) {", new_args)
    content = content.replace("        self.searchController = searchController\n    }", new_assigns)
    
    with open(path, "w") as f:
        f.write(content)

patch_container()
print("Done patching RuntimeContainer")
