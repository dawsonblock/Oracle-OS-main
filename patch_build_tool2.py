import re

with open("Sources/OracleOS/Code/Execution/BuildToolDetector.swift", "r") as f:
    text = f.read()

# Replace CommandSpec? with BuildSpec? or TestSpec?
text = re.sub(
    r"public static func defaultBuildCommand\([^)]*\) -> CommandSpec\? \{[\s\S]*?public static func defaultTestCommand",
    """public static func defaultBuildCommand(
        for buildTool: BuildTool,
        workspaceRoot: URL
    ) -> BuildSpec? {
        // Typed build spec simplifies to just passing the root. WorkspaceRunner applies the tool-specific command.
        return BuildSpec(workspaceRoot: workspaceRoot.path)
    }

    public static func defaultTestCommand""",
    text
)

text = re.sub(
    r"public static func defaultTestCommand\([^)]*\) -> CommandSpec\? \{[\s\S]*?\}",
    """public static func defaultTestCommand(
        for buildTool: BuildTool,
        workspaceRoot: URL
    ) -> TestSpec? {
        // Typed test spec simplifies to just passing the root.
        return TestSpec(workspaceRoot: workspaceRoot.path)
    }
}""",
    text
)

with open("Sources/OracleOS/Code/Execution/BuildToolDetector.swift", "w") as f:
    f.write(text)

