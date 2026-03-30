import sys

def patch_bootstrap():
    path = "Sources/OracleOS/Runtime/RuntimeBootstrap.swift"
    with open(path, "r") as f:
        content = f.read()

    new_services = """        let searchController = SearchController(
            generator: CandidateGenerator(
                stateMemoryIndex: stateMemoryIndex,
                graphStore: graphStore
            )
        )
        
        let stateAbstraction = StateAbstraction()
        let recoveryEngine = RecoveryEngine()
        let architectureEngine = ArchitectureEngine()
        let experimentManager = ExperimentManager()
        let criticLoop = CriticLoop()
        let stateAbstractionEngine = StateAbstractionEngine()
        
        let automationHost = AutomationHost.live()
        let browserController = BrowserController()
        let browserPageStateBuilder = BrowserPageStateBuilder()"""

    new_return = """            searchController: searchController,
            stateAbstraction: stateAbstraction,
            recoveryEngine: recoveryEngine,
            architectureEngine: architectureEngine,
            experimentManager: experimentManager,
            criticLoop: criticLoop,
            stateAbstractionEngine: stateAbstractionEngine,
            automationHost: automationHost,
            browserController: browserController,
            browserPageStateBuilder: browserPageStateBuilder
        )"""
    
    content = content.replace("""        let searchController = SearchController(
            generator: CandidateGenerator(
                stateMemoryIndex: stateMemoryIndex,
                graphStore: graphStore
            )
        )""", new_services)

    content = content.replace("            searchController: searchController\n        )", new_return)

    with open(path, "w") as f:
        f.write(content)

patch_bootstrap()
print("Done patching RuntimeBootstrap")
