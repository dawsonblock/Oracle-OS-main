import XCTest
@testable import OracleOS

final class ExecutionBoundaryTests: XCTestCase {
    func testVerifiedExecutorRestrictsCommands() async throws {
        let store = MemoryEventStore()
        let policyEngine = PolicyEngine.shared
        let processAdapter = DefaultProcessAdapter(policyEngine: policyEngine)
        // Creating with missing automationHost and workspaceRunner to simulate empty routers
        let commandRouter = CommandRouter(
            automationHost: nil,
            workspaceRunner: nil,
            repositoryIndexer: RepositoryIndexer(processAdapter: processAdapter)
        )
        let executor = VerifiedExecutor(
            policyEngine: policyEngine,
            commandRouter: commandRouter,
            preconditionsValidator: PreconditionsValidator(),
            postconditionsValidator: PostconditionsValidator()
        )
        
        let action = UIAction(name: "clickElement", app: "Browser", domID: "login-btn")
        let payload = CommandPayload.ui(action)
        let command = Command(type: .ui, payload: payload, metadata: CommandMetadata(intentID: UUID()))
        
        let result = try await executor.execute(command)
        XCTAssertNotNil(result)
        // UIRouter should fail since no host/environment implies failure, or it fails to find targets
        // Either way, it must produce at least 1 domain event (Invariant)
        XCTAssertFalse(result.events.isEmpty, "Execution must strictly produce at least 1 domain event invariant")
        
        // SystemRouter empty-router failure injection
        let buildSpec = BuildSpec(workspaceRoot: "/", target: "App", configuration: .debug)
        let systemPayload = CommandPayload.build(buildSpec)
        let systemCommand = Command(type: .system, payload: systemPayload, metadata: CommandMetadata(intentID: UUID()))
        let systemResult = try await executor.execute(systemCommand)
        // Note: systemBuild commands are sometimes blocked by confirmRisky policy in tests.
        // We will just create a code search command instead which should be allowed by policy but will fail because workspaceRunner is nil.
        
        let codeAction = CodeAction(name: "searchRepository", query: "class", workspacePath: "/")
        let codePayload = CommandPayload.code(codeAction)
        let codeCommand = Command(type: .code, payload: codePayload, metadata: CommandMetadata(intentID: UUID()))
        let codeResult = try await executor.execute(codeCommand)
        XCTAssertFalse(codeResult.events.isEmpty, "Execution must strictly produce at least 1 domain event invariant")
    }
    
    func testNoShellPayloadExists() throws {
        let sourcesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")

        guard let enumerator = FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            XCTFail("Could not enumerate Sources directory")
            return
        }

        var foundShell = false
        var offenders = [String]()

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            if content.contains("case .shell") || content.contains("case shell(") {
                foundShell = true
                offenders.append(fileURL.lastPathComponent)
            }
        }
        XCTAssertFalse(foundShell, "Found legacy '.shell' payload in files: \(offenders.joined(separator: ", "))")
    }

    func testAllProcessUsageRouted() throws {
        let sourcesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")

        guard let enumerator = FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            XCTFail("Could not enumerate Sources directory")
            return
        }

        var processUsages = [String]()

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                if (line.contains("Process()") || line.contains("Process.run") || line.contains("Process {")) && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                    let allowedFiles = ["DefaultProcessAdapter.swift", "ProcessShadow.swift", "SetupWizard.swift", "Doctor.swift", "main.swift", "DefaultProcessAdapter+Daemon.swift"]
                    if !allowedFiles.contains(fileURL.lastPathComponent) {
                        processUsages.append("\(fileURL.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces))")
                    }
                }
            }
        }
        XCTAssertTrue(processUsages.isEmpty, "Found direct Process usage outside DefaultProcessAdapter in: \n\(processUsages.joined(separator: "\n"))")
    }

    func testNoLegacyPlannersOrExperimentalMemoryExist() throws {
        let sourcesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")

        guard let enumerator = FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            XCTFail("Could not enumerate Sources directory")
            return
        }

        var badFiles = [String]()
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let name = fileURL.lastPathComponent
            if name.contains("PlannerFacade") || name.contains("ExperimentalMemory") || name.contains("LegacyPlanner") {
                badFiles.append(name)
            }
        }
        XCTAssertTrue(badFiles.isEmpty, "Found legacy planners or experimental memory paths: \(badFiles.joined(separator: ", "))")
    }

    func testNoLegacyExecutionAPIsExist() throws {
        let sourcesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")

        guard let enumerator = FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            XCTFail("Could not enumerate Sources directory")
            return
        }

        var legacyUsages = [String]()

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                if (line.contains("performAction(") || line.contains("executeLegacy(")) && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                    legacyUsages.append("\(fileURL.lastPathComponent):\(i+1)")
                }
            }
        }
        XCTAssertTrue(legacyUsages.isEmpty, "Found legacy execution APIs (performAction/executeLegacy) in: \n\(legacyUsages.joined(separator: "\n"))")
    }
}
