import re

with open('Sources/OracleOS/MCP/MCPDispatch.swift', 'r') as f:
    content = f.read()

# Replace buildCommand = CommandSpec(...) with buildCommand = BuildSpec(workspaceRoot: workspaceRoot)
p1 = r' +buildCommand = CommandSpec\(\s*category: \.build,\s*executable: "/usr/bin/env",\s*arguments: customBuild,\s*workspaceRoot: workspaceRoot,\s*summary: customBuild\.joined\(separator: " "\)\s*\)'
r1 = '                buildCommand = BuildSpec(workspaceRoot: workspaceRoot)'
content = re.sub(p1, r1, content, flags=re.MULTILINE)

p2 = r' +testCommand = CommandSpec\(\s*category: \.test,\s*executable: "/usr/bin/env",\s*arguments: customTest,\s*workspaceRoot: workspaceRoot,\s*summary: customTest\.joined\(separator: " "\)\s*\)'
r2 = '                testCommand = TestSpec(workspaceRoot: workspaceRoot)'
content = re.sub(p2, r2, content, flags=re.MULTILINE)

with open('Sources/OracleOS/MCP/MCPDispatch.swift', 'w') as f:
    f.write(content)
