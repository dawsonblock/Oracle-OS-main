import re

path = "Sources/OracleOS/Code/Execution/WorkspaceRunner.swift"
with open(path, "r") as f:
    text = f.read()

# I am deleting everything from `// MARK: - Legacy CommandSpec-based execution` down to `// MARK: - Git Subcommand Policy`
pattern = r"// MARK: - Legacy CommandSpec-based execution \(for backwards compatibility\).*?// MARK: - Git Subcommand Policy"
text = re.sub(pattern, "// MARK: - Git Subcommand Policy", text, flags=re.DOTALL)

# Delete derivedTouchesNetwork(_ spec: CommandSpec)
pattern_touches = r"/// Derive whether a command touches.*?func derivedTouchesNetwork\(_ spec: CommandSpec\) -> Bool \{.*?\n    \}"
text = re.sub(pattern_touches, "", text, flags=re.DOTALL)

# Delete validateGitPolicy(_ spec: CommandSpec)
pattern_validate = r"/// Validate that a git command conforms.*?private func validateGitPolicy\(_ spec: CommandSpec\) throws \{.*?\n    \}"
text = re.sub(pattern_validate, "", text, flags=re.DOTALL)

# Delete isAllowed
pattern_allowed = r"private func isAllowed\(_ spec: CommandSpec\) -> Bool \{.*?\n    \}"
text = re.sub(pattern_allowed, "", text, flags=re.DOTALL)

# Delete allowedExecutable
pattern_exec = r"private func allowedExecutable\(_ executable: String\) -> Bool \{.*?\n    \}"
text = re.sub(pattern_exec, "", text, flags=re.DOTALL)

# Delete sanitizedEnvironment
pattern_env = r"private func sanitizedEnvironment\(\) -> \[String: String\] \{.*?\n    \}"
text = re.sub(pattern_env, "", text, flags=re.DOTALL)

with open(path, "w") as f:
    f.write(text)

