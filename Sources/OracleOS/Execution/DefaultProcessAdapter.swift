import Foundation

public final class DefaultProcessAdapter: ProcessAdapter {
    private let policyEngine: PolicyEngine
    
    /// Maximum output size per stream (stdout/stderr). Prevents memory exhaustion from runaway processes.
    /// Default 10MB should handle most legitimate outputs while protecting against infinite streams.
    public static let defaultMaxOutputBytes: Int = 10 * 1024 * 1024
    
    /// Default timeout for process execution. 60 seconds is generous for most commands.
    public static let defaultTimeoutSeconds: TimeInterval = 60

    public init(policyEngine: PolicyEngine = PolicyEngine.shared) {
        self.policyEngine = policyEngine
    }

    public func run(_ command: SystemCommand, in workspace: WorkspaceContext?) async throws -> ProcessResult {
        return try await runWithTimeout(command, in: workspace, timeout: Self.defaultTimeoutSeconds)
    }

    /// Run a command with proper concurrent pipe draining to avoid deadlocks.
    /// Pipes are drained concurrently while the process runs, preventing buffer exhaustion.
    public func runWithTimeout(
        _ command: SystemCommand,
        in workspace: WorkspaceContext?,
        timeout: TimeInterval = defaultTimeoutSeconds,
        maxOutputBytes: Int = defaultMaxOutputBytes
    ) async throws -> ProcessResult {
        let process = Process()
        process.currentDirectoryURL = workspace?.rootURL
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = sanitizedEnvironment()

        // Start the process
        try process.run()
        
        // Drain pipes concurrently to prevent deadlock.
        // Key insight: we must read from pipes WHILE the process runs,
        // not after waitUntilExit(). If pipes fill (64KB), process blocks.
        async let stdoutData = drainPipe(stdout, maxBytes: maxOutputBytes)
        async let stderrData = drainPipe(stderr, maxBytes: maxOutputBytes)
        
        // Wait for process with timeout
        let completed = await waitForProcess(process, timeout: timeout)
        
        if !completed {
            process.terminate()
            // Give it a moment to clean up
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if process.isRunning {
                process.interrupt() // SIGINT
            }
        }
        
        // Collect drained output
        let out = await stdoutData
        let err = await stderrData
        
        let exitCode = completed ? process.terminationStatus : -1
        return ProcessResult(
            exitCode: exitCode,
            stdout: String(data: out, encoding: .utf8) ?? "",
            stderr: completed ? String(data: err, encoding: .utf8) ?? "" : "Process timed out after \(Int(timeout))s"
        )
    }
    
    /// Synchronous version for backward compatibility - uses dispatch queues for concurrent draining.
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

        // Concurrent pipe draining using dispatch queues
        var stdoutData = Data()
        var stderrData = Data()
        let maxBytes = Self.defaultMaxOutputBytes
        
        let stdoutQueue = DispatchQueue(label: "oracle.process.stdout")
        let stderrQueue = DispatchQueue(label: "oracle.process.stderr")
        let group = DispatchGroup()
        
        group.enter()
        stdoutQueue.async {
            stdoutData = self.drainPipeSync(stdout, maxBytes: maxBytes)
            group.leave()
        }
        
        group.enter()
        stderrQueue.async {
            stderrData = self.drainPipeSync(stderr, maxBytes: maxBytes)
            group.leave()
        }

        try process.run()
        
        // Wait for pipes to drain AND process to exit (in either order)
        // The pipes will close when the process exits
        group.wait()
        process.waitUntilExit()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
    
    // MARK: - Pipe Draining
    
    /// Drain a pipe asynchronously with bounded output.
    private func drainPipe(_ pipe: Pipe, maxBytes: Int) async -> Data {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let data = self.drainPipeSync(pipe, maxBytes: maxBytes)
                continuation.resume(returning: data)
            }
        }
    }
    
    /// Drain a pipe synchronously with bounded output.
    private func drainPipeSync(_ pipe: Pipe, maxBytes: Int) -> Data {
        var accumulated = Data()
        let handle = pipe.fileHandleForReading
        
        // Read in chunks to allow for bounding
        let chunkSize = 64 * 1024 // 64KB chunks
        
        while true {
            let chunk = handle.readData(ofLength: chunkSize)
            if chunk.isEmpty {
                break // EOF
            }
            
            let remaining = maxBytes - accumulated.count
            if remaining <= 0 {
                // Truncate - we've hit the limit
                break
            }
            
            if chunk.count <= remaining {
                accumulated.append(chunk)
            } else {
                accumulated.append(chunk.prefix(remaining))
                break
            }
        }
        
        return accumulated
    }
    
    /// Wait for a process to exit with timeout.
    private func waitForProcess(_ process: Process, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        
        // Poll for completion
        while process.isRunning {
            if Date() > deadline {
                return false // Timed out
            }
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        return true
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
