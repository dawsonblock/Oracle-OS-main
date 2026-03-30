with open("Sources/OracleOS/Execution/VerifiedExecutor.swift", "r") as f:
    text = f.read()

text = text.replace("case .build, .test, .git, .file, .ui, .code:", "case .build, .test, .git, .file, .ui, .code, .diagnostic, .envSetup, .hostService, .inference:")

with open("Sources/OracleOS/Execution/VerifiedExecutor.swift", "w") as f:
    f.write(text)
