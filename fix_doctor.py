import re
import sys

def main():
    with open("Sources/oracle/Doctor.swift", "r") as f:
        text = f.read()

    # Step 1: Make `run()` async
    text = text.replace("mutating func run() {", "mutating func run() async {")
    
    # Step 2: Make `checkProcesses()` and `checkAXTree()` wait? 
    # checkProcesses calls runShell
    text = text.replace("private mutating func checkProcesses() {", "private mutating func checkProcesses() async {")
    text = text.replace("checkProcesses()", "await checkProcesses()")
    text = text.replace("let result = runShell(", "let result = await runShell(")

    text = text.replace("private func runShell(_ command: String) -> ShellResult {", "private func runShell(_ command: String) async -> ShellResult {")

    run_shell_old = """    private func runShell(_ command: String) async -> ShellResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "CLAUDE_CODE")
        env.removeValue(forKey: "CLAUDECODE")
        process.environment = env

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            return ShellResult(output: output, exitCode: process.terminationStatus)
        } catch {
            return ShellResult(output: "", exitCode: -1)
        }
    }"""
    
    run_shell_new = """    private func runShell(_ command: String) async -> ShellResult {
        let executor = VerifiedExecutor()
        let spec = DiagnosticSpec(script: command)
        let cmd = Command(payload: .diagnostic(spec))
        do {
            let outcome = try await executor.execute(cmd)
            if outcome.status == .success {
                let output = outcome.events.compactMap { $0.details["observation"] ?? $0.details["content"] }.joined(separator: "\\n")
                return ShellResult(output: output, exitCode: 0)
            } else {
                return ShellResult(output: outcome.reason ?? "", exitCode: 1)
            }
        } catch {
            return ShellResult(output: "\\(error)", exitCode: -1)
        }
    }"""
    text = text.replace(run_shell_old, run_shell_new)

    with open("Sources/oracle/Doctor.swift", "w") as f:
        f.write(text)

if __name__ == "__main__":
    main()
