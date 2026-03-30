with open("Sources/OracleOS/Code/Execution/WorkspaceRunner.swift", "r") as f:
    text = f.read()

text = text.replace(
    "// MARK: - Legacy CommandSpec-based execution",
    "// MARK: - Legacy CommandSpec-based execution\\n\\n    private func policy(for category: CodeCommandCategory) -> CommandExecutionPolicy {"
)

with open("Sources/OracleOS/Code/Execution/WorkspaceRunner.swift", "w") as f:
    f.write(text)
