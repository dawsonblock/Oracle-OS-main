import re

with open("Sources/oracle/SetupWizard.swift", "r") as f:
    text = f.read()

# Fix the boolean autoclosure issue by moving it out
old_bool = """        let claudeExists = FileManager.default.isExecutableFile(atPath: "/usr/local/bin/claude")
            || FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/claude")
            || (await runShell("which claude 2>/dev/null").exitCode == 0)"""

new_bool = """        let claudeInPath = await runShell("which claude 2>/dev/null").exitCode == 0
        let claudeExists = FileManager.default.isExecutableFile(atPath: "/usr/local/bin/claude")
            || FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/claude")
            || claudeInPath"""
text = text.replace(old_bool, new_bool)

# Fix missing async on the functions themselves
text = text.replace("private func runShell(_ command: String) -> ShellResult {", "private func runShell(_ command: String) async -> ShellResult {")
text = text.replace("private func runShell(_ command: String) async async -> ShellResult {", "private func runShell(_ command: String) async -> ShellResult {")

text = text.replace("private func runShellLive(_ executable: String, args: [String]) -> Int32 {", "private func runShellLive(_ executable: String, args: [String]) async -> Int32 {")
text = text.replace("private func runShellLive(_ executable: String, args: [String]) async async -> Int32 {", "private func runShellLive(_ executable: String, args: [String]) async -> Int32 {")

# Fix missing await
text = text.replace("if !downloadModel() {", "if await !downloadModel() {")

with open("Sources/oracle/SetupWizard.swift", "w") as f:
    f.write(text)

