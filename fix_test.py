with open("Tests/OracleOSTests/Governance/RuntimeInvariantTests.swift", "r") as f:
    content = f.read()

new_content = content.replace('"WorkspaceRunner.swift", "VisionBridge.swift", "WorktreeSandbox.swift"]', 
'"WorkspaceRunner.swift", "VisionBridge.swift", "WorktreeSandbox.swift", "RuntimeDiagnostics.swift"]')

with open("Tests/OracleOSTests/Governance/RuntimeInvariantTests.swift", "w") as f:
    f.write(new_content)
