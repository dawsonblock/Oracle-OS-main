import re

# 1. Update ExperimentSpec
with open("Sources/OracleOS/Execution/Experiments/ExperimentSpec.swift", "r") as f:
    text = f.read()
text = text.replace("public let buildCommand: CommandSpec?", "public let buildCommand: BuildSpec?")
text = text.replace("public let testCommand: CommandSpec?", "public let testCommand: TestSpec?")
text = text.replace("buildCommand: CommandSpec? = nil,", "buildCommand: BuildSpec? = nil,")
text = text.replace("testCommand: CommandSpec? = nil,", "testCommand: TestSpec? = nil,")
with open("Sources/OracleOS/Execution/Experiments/ExperimentSpec.swift", "w") as f:
    f.write(text)

# 2. Update BuildToolDetector
with open("Sources/OracleOS/Code/Execution/BuildToolDetector.swift", "r") as f:
    text2 = f.read()

# We only implement defaultBuildCommand for BuildSpec and TestSpec! Wait, TestSpec only has `workspaceRoot`, `target`. So we can't capture arguments there right now! We'll just define them.
