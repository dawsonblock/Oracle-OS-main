import re

# Update ExperimentSpec
with open("Sources/OracleOS/Execution/Experiments/ExperimentSpec.swift", "r") as f:
    text = f.read()
text = text.replace("public let buildCommand: CommandSpec?", "public let buildCommand: BuildSpec?")
text = text.replace("public let testCommand: CommandSpec?", "public let testCommand: TestSpec?")
text = text.replace("buildCommand: CommandSpec? = nil,", "buildCommand: BuildSpec? = nil,")
text = text.replace("testCommand: CommandSpec? = nil,", "testCommand: TestSpec? = nil,")
with open("Sources/OracleOS/Execution/Experiments/ExperimentSpec.swift", "w") as f:
    f.write(text)

# Update ParallelRunner
with open("Sources/OracleOS/Execution/Experiments/ParallelRunner.swift", "r") as f:
    text = f.read()

# buildCommand inside run is assigned by spec.buildCommand.map { CommandSpec(...) }
# Replace that block entirely:
block = r"""                    let buildCommand = spec.buildCommand\.map \{[\s\S]*?\} \?\? BuildToolDetector\.defaultBuildCommand\(
                        for: buildTool,
                        workspaceRoot: URL\(fileURLWithPath: sandbox\.sandboxPath, isDirectory: true\)
                    \)"""
repl = """                    let buildCommand = spec.buildCommand ?? BuildToolDetector.defaultBuildCommand(
                        for: buildTool,
                        workspaceRoot: URL(fileURLWithPath: sandbox.sandboxPath, isDirectory: true)
                    )"""
text = re.sub(block, repl, text)

block2 = r"""                    let testCommand = spec.testCommand\.map \{[\s\S]*?\} \?\? BuildToolDetector\.defaultTestCommand\(
                        for: buildTool,
                        workspaceRoot: URL\(fileURLWithPath: sandbox\.sandboxPath, isDirectory: true\)
                    \)"""
repl2 = """                    let testCommand = spec.testCommand ?? BuildToolDetector.defaultTestCommand(
                        for: buildTool,
                        workspaceRoot: URL(fileURLWithPath: sandbox.sandboxPath, isDirectory: true)
                    )"""
text = re.sub(block2, repl2, text)

text = text.replace("results.append(try await workspaceRunner.execute(spec: buildCommand))", "results.append(try await convertProcessResult(workspaceRunner.runBuild(buildCommand), spec: buildCommand, category: .build))")
text = text.replace("results.append(try await workspaceRunner.execute(spec: testCommand))", "results.append(try await convertProcessResult(workspaceRunner.runTest(testCommand), spec: testCommand, category: .test))")

# Add a helper function to convert ProcessResult to CommandResult inside ParallelRunner
helper = """    private func convertProcessResult(
        _ result: ProcessResult,
        spec: Any,
        category: CodeCommandCategory
    ) -> CommandResult {
        return CommandResult(
            succeeded: result.exitCode == 0,
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            elapsedMs: result.durationMs,
            workspaceRoot: "", // can be derived if needed
            category: category,
            summary: category == .build ? "build" : "test"
        )
    }
}"""
text = text.replace("}\n}", "}\n\n" + helper)

with open("Sources/OracleOS/Execution/Experiments/ParallelRunner.swift", "w") as f:
    f.write(text)
