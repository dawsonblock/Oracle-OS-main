import Foundation

/// Routes MCP tool requests to handlers.
///
/// This is the single dispatch point that maps tool names to handler functions.
/// All routing logic lives here; MCPDispatch is thin orchestration only.
@MainActor
enum MCPToolRouter {
    
    /// Route a tool request to its handler and return the result.
    ///
    /// This function is pure dispatch: it takes a request and produces a ToolResult.
    /// It does not handle timeouts, formatting, or error recovery.
    /// Those concerns are in MCPDispatch.
    static func dispatch(request: MCPToolRequest) async -> ToolResult {
        let toolName = request.name
        let args = request.arguments
        
        // Route by tool name to the appropriate handler
        let result: ToolResult = switch toolName {
        // Focus/app control
        case "oracle_focus":
            await focusTool(request)
        case "oracle_click":
            await clickTool(request)
        case "oracle_type":
            await typeTool(request)
        case "oracle_press":
            await pressTool(request)
        case "oracle_scroll":
            await scrollTool(request)
        case "oracle_wait":
            await waitTool(request)
        
        // Code
        case "oracle_list":
            await listTool(request)
        case "oracle_read":
            await readTool(request)
        case "oracle_search":
            await searchTool(request)
        case "oracle_edit":
            await editTool(request)
        case "oracle_build":
            await buildTool(request)
        case "oracle_test":
            await testTool(request)
        case "oracle_run":
            await runTool(request)
        
        // Recipes
        case "oracle_recipe_list":
            await recipeListTool(request)
        case "oracle_recipe_load":
            await recipeLoadTool(request)
        case "oracle_recipe_save":
            await recipeSaveTool(request)
        case "oracle_recipe_run":
            await recipeRunTool(request)
        case "oracle_recipe_resume":
            await recipeResumeTool(request)
        
        // Approvals
        case "oracle_approval_list":
            await approvalListTool(request)
        case "oracle_approval_approve":
            await approvalApproveTool(request)
        case "oracle_approval_reject":
            await approvalRejectTool(request)
        
        // Diagnostics
        case "oracle_health":
            await healthTool(request)
        case "oracle_diagnostics":
            await diagnosticsTool(request)
        case "oracle_trace_list":
            await traceListTool(request)
        case "oracle_trace_load":
            await traceLoadTool(request)
        
        // Experiments
        case "oracle_experiment_list":
            await experimentListTool(request)
        case "oracle_experiment_search":
            await experimentSearchTool(request)
        
        // Default: unknown tool
        default:
            ToolResult(
                success: false,
                error: "Unknown tool: \(toolName)",
                data: ["tool": toolName]
            )
        }
        
        return result
    }
    
    // MARK: - Tool Handlers (Stubs)
    // Each handler takes a request, reads typed arguments, and returns a ToolResult.
    // Implementation details are in the actual handler functions below.
    
    private static func focusTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_focus")
    }
    
    private static func clickTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_click")
    }
    
    private static func typeTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_type")
    }
    
    private static func pressTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_press")
    }
    
    private static func scrollTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_scroll")
    }
    
    private static func waitTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_wait")
    }
    
    private static func listTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_list")
    }
    
    private static func readTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_read")
    }
    
    private static func searchTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_search")
    }
    
    private static func editTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_edit")
    }
    
    private static func buildTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_build")
    }
    
    private static func testTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_test")
    }
    
    private static func runTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_run")
    }
    
    private static func recipeListTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_recipe_list")
    }
    
    private static func recipeLoadTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_recipe_load")
    }
    
    private static func recipeSaveTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_recipe_save")
    }
    
    private static func recipeRunTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_recipe_run")
    }
    
    private static func recipeResumeTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_recipe_resume")
    }
    
    private static func approvalListTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_approval_list")
    }
    
    private static func approvalApproveTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_approval_approve")
    }
    
    private static func approvalRejectTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_approval_reject")
    }
    
    private static func healthTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_health")
    }
    
    private static func diagnosticsTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_diagnostics")
    }
    
    private static func traceListTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_trace_list")
    }
    
    private static func traceLoadTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_trace_load")
    }
    
    private static func experimentListTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_experiment_list")
    }
    
    private static func experimentSearchTool(_ request: MCPToolRequest) async -> ToolResult {
        ToolResult.notImplemented("oracle_experiment_search")
    }
}

// MARK: - Helper

extension ToolResult {
    static func notImplemented(_ toolName: String) -> ToolResult {
        ToolResult(
            success: false,
            error: "Tool not yet implemented: \(toolName)",
            data: [:]
        )
    }
}
