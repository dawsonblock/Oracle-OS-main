import Foundation

public struct SystemCommand: Sendable {
    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol BackgroundProcess: Sendable {
    var processIdentifier: Int32 { get }
    func terminate()
}

public protocol ProcessAdapter: Sendable {
    func run(_ command: SystemCommand, in workspace: WorkspaceContext?) async throws -> ProcessResult
    func runSync(_ command: SystemCommand, in workspace: WorkspaceContext?) throws -> ProcessResult
    
    /// Spawns a background process and returns a handle.
    func spawnBackground(_ command: SystemCommand, in workspace: WorkspaceContext?) throws -> any BackgroundProcess
}
