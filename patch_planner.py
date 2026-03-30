import re

with open('Sources/OracleOS/Planning/MainPlanner+Planner.swift', 'r') as f:
    text = f.read()

# Replace .code(CodeAction(name: "modifyFile", filePath: path, patch: patch))
# With .file(FileMutationSpec(operation: .write, path: path, content: patch))

text = text.replace(
    'payload: .code(CodeAction(name: "modifyFile", filePath: path, patch: patch)),',
    'payload: .file(FileMutationSpec(operation: .write, path: path, content: patch)),'
)

with open('Sources/OracleOS/Planning/MainPlanner+Planner.swift', 'w') as f:
    f.write(text)

print("MainPlanner+Planner patched")
