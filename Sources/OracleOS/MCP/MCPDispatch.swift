// MCPDispatch.swift - Thin orchestration layer for MCP tool handling
//
// This file coordinates:
// 1. Bootstrap via MCPRuntimeProvider
// 2. Routing via MCPToolRouter
// 3. Timeout and formatting
//
// Core tool implementations are in MCPToolRouter.
// Runtime access is managed by MCPRuntimeProvider.

import Foundation

/// Thin orchestration for MCP tool calls.
///
/// Responsibilities:
/// - Get bootstrapped runtime (via MCPRuntimeProvider)
/// - Route request to handler (via MCPToolRouter)
/// - Manage timeout wrapping
/// - Format response via MCPBoundary types
///
/// Does NOT:
/// - Implement tools (see MCPToolRouter)
/// - Manage runtime lifecycle (see MCPRuntimeProvider)
/// - Define transport types (see MCPBoundary)
@MainActor
public enum MCPDispatch {

    /// Per-tool-call timeout. Most tools complete in <2s; deep AX tree walks
    /// can take 10-20s for Chrome. 60s is the absolute ceiling.
    private static let toolTimeoutSeconds: TimeInterval = 60

    private struct ResultWrapper: Sendable {
        let payload: MCPToolResponse?
    }

    /// Handle a tools/call request. Returns MCP-formatted result.
    ///
    /// Orchestrates:
    /// 1. Runtime bootstrap (idempotent)
    /// 2. Tool routing (via MCPToolRouter)
    /// 3. Timeout wrapping (prevents hanging)
    /// 4. Response formatting (MCPBoundary types)
    public static func handle(_ request: MCPToolRequest) async -> MCPToolResponse {
        // Step 1: Ensure runtime is bootstrapped
        do {
            let bootstrapped = try await MCPRuntimeProvider.getBootstrappedRuntime()
            bootstrapped.container.memoryStore.setWorkspaceRoot(FileManager.default.currentDirectoryPath)
        } catch {
            return MCPToolResponse.error("Failed to bootstrap runtime kernel: \(error)")
        }

        let toolName = request.name
        let startTime = DispatchTime.now()
        Log.info("Tool call: \(toolName)")

        // Special timeout for long-running experiments
        let actualTimeout = toolName == "oracle_experiment_search" ? 600.0 : toolTimeoutSeconds

        // Step 2: Route request to handler with timeout wrapper
        struct RequestWrapper: Sendable {
            let request: MCPToolRequest
        }
        let argsWrapper = RequestWrapper(request: request)

        let responseWrapper: ResultWrapper
        do {
            responseWrapper = try await withThrowingTaskGroup(of: ResultWrapper.self) { group in
                let wReq = argsWrapper
                
                // Main tool handler task
                group.addTask { @MainActor @Sendable in
                    let toolResult = await MCPToolRouter.dispatch(request: wReq.request)
                    let response = formatResult(toolResult, toolName: toolName)
                    return ResultWrapper(payload: response)
                }

                // Timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(actualTimeout * 1_000_000_000))
                    return ResultWrapper(payload: nil)
                }

                // Wait for first result (either tool completes or timeout)
                if let first = try await group.next() {
                    group.cancelAll()
                    return first
                }
                return ResultWrapper(payload: nil)
            }
        } catch {
            responseWrapper = ResultWrapper(payload: nil)
        }

        // Step 3: Handle response or timeout
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000

        guard let payload = responseWrapper.payload else {
            Log.error("Tool \(toolName) TIMED OUT after \(Int(actualTimeout))s")
            return MCPToolResponse.error("Tool \(toolName) timed out after \(Int(actualTimeout))s")
        }

        // Log performance
        if elapsed > 5000 {
            Log.warn("Tool \(toolName) took \(Int(elapsed))ms (slow)")
        } else {
            Log.info("Tool \(toolName) completed in \(Int(elapsed))ms")
        }

        return payload
    }

    // MARK: - Response Formatting

    /// Format a ToolResult as MCPToolResponse using MCPBoundary types.
    private static func formatResult(_ result: ToolResult, toolName: String) -> MCPToolResponse {
        let dict = result.toDict()

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
           let jsonStr = String(data: data, encoding: .utf8)
        {
            return MCPToolResponse(content: [.text(jsonStr)], isError: !result.success)
        }

        return MCPToolResponse.error("Failed to serialize response for \(toolName)")
    }
}
