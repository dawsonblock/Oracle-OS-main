with open("Sources/OracleOS/Common/Diagnostics/RuntimeDiagnostics.swift", "r") as f:
    content = f.read()

new_content = content.replace("let indexer = RepositoryIndexer(processAdapter: DefaultProcessAdapter())", 
"""let policyEngine = PolicyEngine.shared
        let indexer = RepositoryIndexer(processAdapter: DefaultProcessAdapter(policyEngine: policyEngine))""")

with open("Sources/OracleOS/Common/Diagnostics/RuntimeDiagnostics.swift", "w") as f:
    f.write(new_content)
