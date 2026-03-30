import re

with open("Sources/OracleOS/MCP/MCPDispatch.swift", "r") as f:
    content = f.read()

# Change `handle` to `async`
content = content.replace("public static func handle(_ params: [String: Any]) -> [String: Any] {", "public static func handle(_ params: [String: Any]) async -> [String: Any] {")

# Remove the old Unified Runtime Bootstrap
bootstrap_pattern = re.compile(r'// MARK: - Unified Runtime Bootstrap[\s\S]*?(?=public static func handle)', re.MULTILINE)

new_bootstrap = """// MARK: - Unified Runtime Bootstrap
    // Handled safely by MCPRuntimeHolder actor to prevent main thread blocking
"""

content = bootstrap_pattern.sub(new_bootstrap + "\n    ", content)

handle_body_pattern = re.compile(r'public static func handle\(_ params: \[String: Any\]\) async -> \[String: Any\] \{[\s\S]*?(?=private static func handleScreenshot)', re.MULTILINE)

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
                        let toolResult = await dispatch(tool: toolName, args: args, runtimeContext: runtimeCtx)
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

content = handle_body_pattern.sub(new_handle, content)

# Now modify dispatch signature
dispatch_sig = "private static func dispatch(tool: String, args: [String: Any]) -> ToolResult {"
new_dispatch_sig = "private static func dispatch(tool: String, args: [String: Any], runtimeContext: RuntimeContext) async -> ToolResult {"
content = content.replace(dispatch_sig, new_dispatch_sig)

with open("Sources/OracleOS/MCP/MCPDispatch.swift", "w") as f:
    f.write(content)
