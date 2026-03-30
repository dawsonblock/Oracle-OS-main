with open("Sources/OracleOS/Code/Execution/WorkspaceRunner.swift", "r") as f:
    text = f.read()

text = text.replace("""    // MARK: - Legacy CommandSpec-based execution (for backwards compatibility)

        switch category {""", """    // MARK: - Legacy CommandSpec-based execution (for backwards compatibility)
    private func policy(for category: CodeCommandCategory) -> CommandExecutionPolicy {
        switch category {""")

with open("Sources/OracleOS/Code/Execution/WorkspaceRunner.swift", "w") as f:
    f.write(text)
