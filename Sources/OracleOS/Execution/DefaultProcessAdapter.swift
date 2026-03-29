import Foundation

public final class DefaultProcessAdapter: ProcessAdapter {
    private let policyEngine: PolicyEngine

    public init(policyEngine: PolicyEngine = PolicyEngine.shared) {
        self.policyEngine = policyEngine
    }

    public func run(_ command: SystemCommand, in workspace: WorkspaceContext?) async throws -> ProcessResult {
        return try runSync(command, in: workspace)
    }

    public func runSync(_ command: SystemCommand, in workspace: WorkspaceContext?) throws -> ProcessResult {
        let process = Process()
        process.currentDirectoryURL = workspace?.rootURL
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = sanitizedEnvironment()

        try process.run()
        process.waitUntilExit()

        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: out,
            stderr: err
        )
    }

    private struct DefaultBackgroundProcess: BackgroundProcess {
        let process: Process
        var processIdentifier: Int32 { process.processIdentifier }
        func terminate() { process.terminate() }
    }

    public func spawnBackground(_ command: SystemCommand, in workspace: WorkspaceContext?) throws -> any BackgroundProcess {
        let process = Process()
        process.currentDirectoryURL = workspace?.rootURL
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.standardError
        process.environment = sanitizedEnvironment()
        try process.run()
        return DefaultBackgroundProcess(process: process)
    }

    private func sanitizedEnvironment() -> [String: String] {
        let source = ProcessInfo.processInfo.environment
        let keys = ["PATH", "HOME", "LANG", "LC_ALL", "TMPDIR", "DEVELOPER_DIR"]
        return Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            source[key].map { (key, $0) }
        })
    }
}
