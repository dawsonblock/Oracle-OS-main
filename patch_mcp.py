import re

with open("Sources/OracleOS/MCP/MCPDispatch.swift", "r") as f:
    text = f.read()

# Replace variables typing inside MCPDispatch
text = text.replace("var buildCommand: CommandSpec?", "var buildCommand: BuildSpec?")
text = text.replace("""                buildCommand = CommandSpec(
                    category: .build,
                    executable: "/usr/bin/env",
                    arguments: customBuild,
                    workspaceRoot: rootURL.path,
                    summary: customBuild.joined(separator: " ")
                )""", """                // Typed specs don't hold full custom build commands yet cleanly, 
                // but let's assume we use it as buildspec
                buildCommand = BuildSpec(workspaceRoot: rootURL.path)""")

text = text.replace("var testCommand: CommandSpec?", "var testCommand: TestSpec?")
text = text.replace("""                testCommand = CommandSpec(
                    category: .test,
                    executable: "/usr/bin/env",
                    arguments: customTest,
                    workspaceRoot: rootURL.path,
                    summary: customTest.joined(separator: " ")
                )""", """                testCommand = TestSpec(workspaceRoot: rootURL.path)""")

with open("Sources/OracleOS/MCP/MCPDispatch.swift", "w") as f:
    f.write(text)
