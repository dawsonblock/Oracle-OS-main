import re

with open("Sources/oracle/SetupWizard.swift", "r") as f:
    text = f.read()

text = text.replace("func run() {", "func run() async {")
text = text.replace("configureMCP()", "await configureMCP()")
text = text.replace("let hasVision = setupVision()", "let hasVision = await setupVision()")
text = text.replace("let verified = selfTest(", "let verified = await selfTest(")

text = text.replace("private func configureMCP() {", "private func configureMCP() async {")
text = text.replace("private func setupVision() -> Bool {", "private func setupVision() async -> Bool {")
text = text.replace("private func checkPythonWithMLX() -> Bool {", "private func checkPythonWithMLX() async -> Bool {")
text = text.replace("private func setupPythonVenv() -> Bool {", "private func setupPythonVenv() async -> Bool {")
text = text.replace("private func selfTest(hasAccess: Bool, hasScreenRecording: Bool, hasVision: Bool) -> Bool {", "private func selfTest(hasAccess: Bool, hasScreenRecording: Bool, hasVision: Bool) async -> Bool {")

text = re.sub(r'runShell\(', 'await runShell(', text)
text = re.sub(r'runShellLive\(', 'await runShellLive(', text)

run_shell_old = """    private func runShell(_ command: String) -> ShellResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe
        // Unset CLAUDECODE to avoid nested session error
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "CLAUDE_CODE")
        env.removeValue(forKey: "CLAUDECODE")
        process.environment = env

        do {
            try process.run()
            // Read pipe BEFORE waitUntilExit to avoid deadlock if output exceeds pipe buffer
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
        let spec = EnvSetupSpec(script: "/bin/zsh", arguments: ["-c", command])
        let cmd = Command(payload: .envSetup(spec))
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

run_shell_live_old = """    private func runShellLive(_ executable: String, args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        // Inherit stdout/stderr so the user sees download progress
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "CLAUDE_CODE")
        env.removeValue(forKey: "CLAUDECODE")
        process.environment = env

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            print("  ERROR: Failed to run \\(executable): \\(error)")
            return -1
        }
    }"""
    
run_shell_live_new = """    private func runShellLive(_ executable: String, args: [String]) async -> Int32 {
        let executor = VerifiedExecutor()
        let spec = EnvSetupSpec(script: executable, arguments: args)
        let cmd = Command(payload: .envSetup(spec))
        do {
            let outcome = try await executor.execute(cmd)
            if outcome.status == .success {
                let output = outcome.events.compactMap { $0.details["observation"] ?? $0.details["content"] }.joined(separator: "\\n")
                print(output)
                return 0
            } else {
                print("  ERROR: \\(outcome.reason ?? "")")
                return 1
            }
        } catch {
            print("  ERROR: Failed to run \\(executable): \\(error)")
            return -1
        }
    }"""
text = text.replace(run_shell_live_old, run_shell_live_new)

text = text.replace("import Foundation", "import Foundation\nimport OracleOS")

with open("Sources/oracle/SetupWizard.swift", "w") as f:
    f.write(text)
print("SetupWizard modified successfully.")
