import re

with open("Sources/OracleOS/MCP/MCPDispatch.swift", "r") as f:
    text = f.read()

# Replace the Unified Runtime Bootstrap section up to handle
top_pattern = re.compile(r'// MARK: - Unified Runtime Bootstrap[\s\S]*?(?=public static func handle)', re.MULTILINE)
text = top_pattern.sub("", text)

# Rewrite handle function body
handle_pattern = re.compile(r'public static func handle\(_ params: \[String: Any\]\) -> \[String: Any\] \{[\s\S]*?(?=private static func handleScreenshot)', re.MULTILINE)

new_handle = """public static func handle(_ params: [String: Any]) async -> [String: Any] {
        guard let toolName = params["name"] as? String else {
            return errorContent("Missing tool name")
        }

        let args = params["arguments"] as? [String: Any] ?? [:]
        let startTime = DispatchTime.now()
        Log.info("Tool call: \\(toolName)")

        let actualTimeout = toolName == "oracle_experiment_search" ? 600.0 : toolTimeoutSeconds
        
        do {
            let runtimeCtx = try await MCPRuntimeHolder.shared.getRuntimeContext()
            runtimeCtx.memoryStore.setWorkspaceRoot(FileManager.default.currentDirectoryPath)

            let result: [String: Any] = try await withThrowingTaskGroup(of: [String: Any].self) { group in
                group.addTask {
                    if toolName == "oracle_screenshot" {
                        return handleScreenshot(args)
                    } else {
                        let toolResult = await dispatch(tool: toolName, args: args)
                        return formatResult(toolResult, toolName: toolName)
                    }
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(actualTimeout * 1_000_000_000))
                    throw CancellationError()
                }
                
                guard let firstResult = try await group.next() else {
                    return errorContent("Tool \\(toolName) returned nil response")
                }
                group.cancelAll()
                return firstResult
            }
            
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
            if elapsed > 5000 {
                Log.warn("Tool \\(toolName) took \\(Int(elapsed))ms (slow)")
            } else {
                Log.info("Tool \\(toolName) completed in \\(Int(elapsed))ms")
            }
            return result

        } catch is CancellationError {
            Log.error("Tool \\(toolName) TIMED OUT after \\(Int(actualTimeout))s")
            return errorContent("Tool \\(toolName) timed out after \\(Int(actualTimeout))s")
        } catch {
            Log.error("Tool \\(toolName) failed with error: \\(error)")
            return errorContent("Tool \\(toolName) failed: \\(error)")
        }
    }

    """
text = handle_pattern.sub(new_handle, text)

# Rewrite dispatch signature
text = text.replace("private static func dispatch(tool: String, args: [String: Any]) -> ToolResult {",
                    "private static func dispatch(tool: String, args: [String: Any]) async -> ToolResult {")

# Insert locals at the top of dispatch
dispatch_start = "private static func dispatch(tool: String, args: [String: Any]) async -> ToolResult {"
locals_insert = """
        let runtimeContext = try! await MCPRuntimeHolder.shared.getRuntimeContext()
        let bootstrapped = try! await MCPRuntimeHolder.shared.getBootstrappedRuntime()
        let runtimeContainer = bootstrapped.container
        let runtime = bootstrapped.orchestrator
"""
text = text.replace(dispatch_start, dispatch_start + locals_insert)

# Remove the Task wrapper for oracle_experiment_search block
exp_pattern = re.compile(r'let sema = DispatchSemaphore\(value: 0\)\s*var runResult: ToolResult\?\s*// This MUST hop onto a new Task because dispatch\(\) is synchronous\s*// but run\(\) is async\.\s*Task \{\s*do \{\s*let results = try await runtimeContext\.experimentManager\.run\(spec: spec\)')
text = exp_pattern.sub("do {\n                    let results = try await runtimeContext.experimentManager.run(spec: spec)", text)

end_task_pattern = re.compile(r'runResult = ToolResult\(success: true, data: \["results": serialized\]\)\s*\} catch \{\s*runResult = ToolResult\(\s*success: false,\s*error: "Experiment failed: \\\(error\)"\s*\)\s*\}\s*sema\.signal\(\)\s*\}\s*sema\.wait\(\)\s*return runResult \?\? ToolResult\(success: false, error: "Task failed to set runResult"\)')
text = end_task_pattern.sub(r'return ToolResult(success: true, data: ["results": serialized])\n                } catch {\n                    return ToolResult(\n                        success: false,\n                        error: "Experiment failed: \\(error)"\n                    )\n                }', text)


with open("Sources/OracleOS/MCP/MCPDispatch.swift+", "w") as f:
    f.write(text)

