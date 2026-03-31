import re

with open("Sources/OracleOS/Code/Execution/WorkspaceRunner.swift", "r") as f:
    text = f.read()

# Pattern goes from "// MARK: - Legacy CommandSpec-based execution" until the EOF
# Wait, Git Subcommand Policy is below it, but we need derivedTouchesNetwork
parts = text.split("// MARK: - Legacy CommandSpec-based execution (for backwards compatibility)")
top = parts[0]
legacy_and_git = parts[1]

# We want to remove `private func policy(...)`, `public func execute(spec:)`, `private func isAllowed(...)`, `private func allowedExecutable(...)`, `private func sanitizedEnvironment(...)`.
# Let's use regex to surgically pull out `public func execute` and friends, but wait, if it's Legacy, let's remove everything that mentions CommandSpec
