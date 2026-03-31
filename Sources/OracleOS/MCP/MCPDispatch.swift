// MCPDispatch.swift - Route MCP tool calls to module functions
//
// Maps tool names to handler functions. Wraps each call in a timeout.
// Formats responses as MCP content arrays.

import Foundation

/// Routes MCP tool calls to the appropriate module function.
@MainActor
public enum MCPDispatch {

    /// Per-tool-call timeout. Most tools complete in <2s; deep AX tree walks
    /// can take 10-20s for Chrome. 60s is the absolute ceiling — if a tool takes
    /// longer than this, the MCP server was effectively stuck.
    private static let toolTimeoutSeconds: TimeInterval = 60

    // MARK: - Unified Runtime Bootstrap
    // Single source of truth: RuntimeBootstrap creates all shared services.
    // Previous split (separate runtimeContext + runtimeContainer) eliminated.
    
    private static var _bootstrappedRuntime: BootstrappedRuntime?
    
    /// Lazily bootstrap the unified runtime with recovery.
    /// Returns the BootstrappedRuntime containing container, orchestrator, and recovery report.
    private static func getBootstrappedRuntime() async throws -> BootstrappedRuntime {
        if let existing = _bootstrappedRuntime {
            return existing
        }
        
        let built = try await RuntimeBootstrap.makeBootstrappedRuntime(configuration: .live())
        _bootstrappedRuntime = built
        
        if built.recoveryReport.didRecover {
            Log.info("Runtime recovery: replayed \(built.recoveryReport.eventsReplayed) events from \(built.recoveryReport.walEntriesRecovered) WAL entries")
        }
        
        return built
    }
    
    /// Properties that are safe to access ONCE bootstrap has finished.
    private static var runtime: RuntimeOrchestrator { _bootstrappedRuntime!.orchestrator }
    private static var runtimeContainer: RuntimeContainer { _bootstrappedRuntime!.container }

    private struct ResultWrapper: Sendable {
        let payload: MCPToolResponse?
    }

    /// Handle a tools/call request. Returns MCP-formatted result.
    /// Wraps every tool call in a timeout so no single tool can block
    /// the MCP server indefinitely (the #1 user-reported issue).
    public static func handle(_ request: MCPToolRequest) async -> MCPToolResponse {
        do {
            let bootstrapped = try await getBootstrappedRuntime()
            bootstrapped.container.memoryStore.setWorkspaceRoot(FileManager.default.currentDirectoryPath)
        } catch {
            return errorContent("Failed to bootstrap runtime kernel: \(error)")
        }

        let toolName = request.name
        let startTime = DispatchTime.now()
        Log.info("Tool call: \(toolName)")

        let actualTimeout = toolName == "oracle_experiment_search" ? 600.0 : toolTimeoutSeconds

        struct RequestWrapper: Sendable {
            let request: MCPToolRequest
        }
        let argsWrapper = RequestWrapper(request: request)

        let responseWrapper: ResultWrapper
        do {
            responseWrapper = try await withThrowingTaskGroup(of: ResultWrapper.self) { group in
                let wReq = argsWrapper
                group.addTask { @MainActor @Sendable in
                    let result: MCPToolResponse
                    if toolName == "oracle_screenshot" {
                        result = handleScreenshot(wReq.request)
                    } else {
                        let toolResult = await dispatch(request: wReq.request)
                        result = formatResult(toolResult, toolName: toolName)
                    }
                    return ResultWrapper(payload: result)
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(actualTimeout * 1_000_000_000))
                    return ResultWrapper(payload: nil)
                }

                if let first = try await group.next() {
                    group.cancelAll()
                    return first
                }
                return ResultWrapper(payload: nil)
            }
        } catch {
            responseWrapper = ResultWrapper(payload: nil)
        }

        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000

        guard let payload = responseWrapper.payload else {
            Log.error("Tool \(toolName) TIMED OUT after \(Int(actualTimeout))s")
            return errorContent("Tool \(toolName) timed out after \(Int(actualTimeout))s")
        }

        if payload.isError,
           let firstContent = payload.content.first,
           case .text(let textStr) = firstContent,
           textStr.contains("timed out") {
            // Already logged error inside closure
        } else {
            if elapsed > 5000 {
                Log.warn("Tool \(toolName) took \(Int(elapsed))ms (slow)")
            } else {
                Log.info("Tool \(toolName) completed in \(Int(elapsed))ms")
            }
        }

        return payload
    }

    /// Screenshot handler returns MCP image content type for inline display.
    private static func handleScreenshot(_ request: MCPToolRequest) -> MCPToolResponse {
        let args = request.arguments
        let result = AXScanner.screenshot(
            appName: str(args, "app"),
            fullResolution: bool(args, "full_resolution") ?? false
        )

        guard result.success,
              let data = result.data,
              let base64 = data["image"] as? String
        else {
            return formatResult(result, toolName: "oracle_screenshot")
        }

        let mimeType = data["mime_type"] as? String ?? "image/png"
        let width = data["width"] as? Int ?? 0
        let height = data["height"] as? Int ?? 0
        let windowTitle = data["window_title"] as? String ?? ""
        var caption = "Screenshot: \(width)x\(height)"
        if !windowTitle.isEmpty { caption += " - \(windowTitle)" }

        return MCPToolResponse.imageAndCaption(base64: base64, mimeType: mimeType, caption: caption)
    }

    // MARK: - Dispatch

    private static func dispatch(request: MCPToolRequest) async -> ToolResult {
        let tool = request.name
        let args = request.arguments
        switch tool {

        // Perception
        case "oracle_context":
            return AXScanner.getContext(appName: str(args, "app"))

        case "oracle_state":
            return AXScanner.getState(appName: str(args, "app"))

        case "oracle_find":
            return AXScanner.findElements(
                query: str(args, "query"),
                role: str(args, "role"),
                domId: str(args, "dom_id"),
                domClass: str(args, "dom_class"),
                identifier: str(args, "identifier"),
                appName: str(args, "app"),
                depth: int(args, "depth")
            )

        case "oracle_read":
            return AXScanner.readContent(
                appName: str(args, "app"),
                query: str(args, "query"),
                depth: int(args, "depth")
            )

        case "oracle_inspect":
            guard let query = str(args, "query") else {
                return ToolResult(success: false, error: "Missing required parameter: query")
            }
            return AXScanner.inspect(
                query: query,
                role: str(args, "role"),
                domId: str(args, "dom_id"),
                appName: str(args, "app")
            )

        case "oracle_element_at":
            guard let x = double(args, "x"), let y = double(args, "y") else {
                return ToolResult(success: false, error: "Missing required parameters: x, y")
            }
            return AXScanner.elementAt(x: x, y: y)

        case "oracle_screenshot":
            return AXScanner.screenshot(
                appName: str(args, "app"),
                fullResolution: bool(args, "full_resolution") ?? false
            )

        // Actions
        case "oracle_click":
            return FocusManager.withFocusRestore {
                Actions.click(
                    query: str(args, "query"),
                    role: str(args, "role"),
                    domId: str(args, "dom_id"),
                    appName: str(args, "app"),
                    x: double(args, "x"),
                    y: double(args, "y"),
                    button: str(args, "button"),
                    count: int(args, "count"),
                    runtime: runtime,
                    surface: .mcp,
                    approvalRequestID: str(args, "approval_request_id"),
                    toolName: tool
                )
            }

        case "oracle_type":
            guard let text = str(args, "text") else {
                return ToolResult(success: false, error: "Missing required parameter: text")
            }
            return FocusManager.withFocusRestore {
                Actions.typeText(
                    text: text,
                    into: str(args, "into"),
                    domId: str(args, "dom_id"),
                    appName: str(args, "app"),
                    clear: bool(args, "clear") ?? false,
                    runtime: runtime,
                    surface: .mcp,
                    approvalRequestID: str(args, "approval_request_id"),
                    toolName: tool
                )
            }

        // Press, hotkey, scroll are synthetic input tools that send events to the
        // FRONTMOST app. They need the target app to STAY focused after the tool
        // returns - the agent will call oracle_focus to restore when ready.
        // Do NOT wrap these in withFocusRestore, which would steal focus back
        // before the app processes the event (e.g. Cmd+L needs Chrome to stay
        // focused while it selects the address bar text).
        case "oracle_press":
            guard let key = str(args, "key") else {
                return ToolResult(success: false, error: "Missing required parameter: key")
            }
            let modifiers = args["modifiers"]?.arrayValue?.compactMap { $0.stringValue }
            return Actions.pressKey(
                key: key,
                modifiers: modifiers,
                appName: str(args, "app"),
                runtime: runtime,
                surface: .mcp,
                approvalRequestID: str(args, "approval_request_id"),
                toolName: tool
            )

        case "oracle_hotkey":
            guard let keys = args["keys"]?.arrayValue?.compactMap({ $0.stringValue }),
                  !keys.isEmpty else {
                return ToolResult(success: false, error: "Missing required parameter: keys (array of strings)")
            }
            return Actions.hotkey(
                keys: keys,
                appName: str(args, "app"),
                runtime: runtime,
                surface: .mcp,
                approvalRequestID: str(args, "approval_request_id"),
                toolName: tool
            )

        case "oracle_scroll":
            guard let direction = str(args, "direction") else {
                return ToolResult(success: false, error: "Missing required parameter: direction")
            }
            return Actions.scroll(
                direction: direction,
                amount: int(args, "amount"),
                appName: str(args, "app"),
                x: double(args, "x"),
                y: double(args, "y"),
                runtime: runtime,
                surface: .mcp,
                approvalRequestID: str(args, "approval_request_id"),
                toolName: tool
            )

        case "oracle_focus":
            guard let app = str(args, "app") else {
                return ToolResult(success: false, error: "Missing required parameter: app")
            }
            return Actions.focusApp(
                appName: app,
                windowTitle: str(args, "window"),
                runtime: runtime,
                surface: .mcp,
                approvalRequestID: str(args, "approval_request_id"),
                toolName: tool
            )

        case "oracle_window":
            guard let action = str(args, "action"),
                  let app = str(args, "app")
            else {
                return ToolResult(success: false, error: "Missing required parameters: action, app")
            }
            return Actions.manageWindow(
                action: action,
                appName: app,
                windowTitle: str(args, "window"),
                x: double(args, "x"),
                y: double(args, "y"),
                width: double(args, "width"),
                height: double(args, "height"),
                runtime: runtime,
                surface: .mcp,
                approvalRequestID: str(args, "approval_request_id"),
                toolName: tool
            )

        // Wait
        case "oracle_wait":
            guard let condition = str(args, "condition") else {
                return ToolResult(success: false, error: "Missing required parameter: condition")
            }
            return WaitManager.waitFor(
                condition: condition,
                value: str(args, "value"),
                appName: str(args, "app"),
                timeout: double(args, "timeout") ?? 10,
                interval: double(args, "interval") ?? 0.5
            )

        // Recipes
        case "oracle_recipes":
            let recipes = RecipeStore.listRecipes()
            let summaries: [[String: Any]] = recipes.map { recipe in
                var summary: [String: Any] = [
                    "name": recipe.name,
                    "description": recipe.description,
                ]
                if let app = recipe.app { summary["app"] = app }
                if let params = recipe.params {
                    summary["params"] = params.map { key, param in
                        ["name": key, "type": param.type, "description": param.description,
                         "required": param.required ?? false] as [String: Any]
                    }
                }
                return summary
            }
            return ToolResult(success: true, data: ["recipes": summaries, "count": summaries.count])

        case "oracle_run":
            if let resumeToken = str(args, "resume_token") {
                return RecipeEngine.resume(
                    resumeToken: resumeToken,
                    approvalRequestID: str(args, "approval_request_id"),
                    runtime: runtime,
                    taskID: runtimeContainer.traceRecorder.sessionID
                )
            }

            guard let recipeName = str(args, "recipe") else {
                return ToolResult(success: false, error: "Missing required parameter: recipe or resume_token")
            }
            guard let recipe = RecipeStore.loadRecipe(named: recipeName) else {
                return ToolResult(
                    success: false,
                    error: "Recipe '\(recipeName)' not found",
                    suggestion: "Use oracle_recipes to list available recipes"
                )
            }
            // Parse params from the MCP arguments
            let recipeParams: [String: String] = args["params"]?.objectValue?.compactMapValues { v in
                switch v {
                case .string(let s): return s
                case .int(let i): return String(i)
                case .double(let d): return String(d)
                case .bool(let b): return String(b)
                default: return nil
                }
            } ?? [:]

            return RecipeEngine.run(
                recipe: recipe,
                params: recipeParams,
                runtime: runtime,
                taskID: runtimeContainer.traceRecorder.sessionID
            )

        case "oracle_recipe_show":
            guard let name = str(args, "name") else {
                return ToolResult(success: false, error: "Missing required parameter: name")
            }
            guard let recipe = RecipeStore.loadRecipe(named: name) else {
                return ToolResult(
                    success: false,
                    error: "Recipe '\(name)' not found",
                    suggestion: "Use oracle_recipes to list available recipes"
                )
            }
            if let data = try? JSONEncoder().encode(recipe),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                return ToolResult(success: true, data: dict)
            }
            return ToolResult(success: false, error: "Failed to serialize recipe")

        case "oracle_recipe_save":
            guard let jsonStr = str(args, "recipe_json") else {
                return ToolResult(success: false, error: "Missing required parameter: recipe_json")
            }
            do {
                let name = try RecipeStore.saveRecipeJSON(jsonStr)
                return ToolResult(success: true, data: ["saved": name])
            } catch {
                return ToolResult(success: false, error: "Failed to save recipe: \(error)")
            }

        case "oracle_recipe_delete":
            guard let name = str(args, "name") else {
                return ToolResult(success: false, error: "Missing required parameter: name")
            }
            let deleted = RecipeStore.deleteRecipe(named: name)
            return ToolResult(
                success: deleted,
                data: deleted ? ["deleted": name] : nil,
                error: deleted ? nil : "Recipe '\(name)' not found"
            )

        // Vision
        case "oracle_parse_screen":
            return VisionScanner.parseScreen(
                appName: str(args, "app"),
                fullResolution: bool(args, "full_resolution") ?? false
            )

        case "oracle_ground":
            guard let description = str(args, "description") else {
                return ToolResult(success: false, error: "Missing required parameter: description")
            }
            let cropBox = args["crop_box"]?.arrayValue?.compactMap { $0.doubleValue }
            return VisionScanner.groundElement(
                description: description,
                appName: str(args, "app"),
                cropBox: cropBox
            )

        // Project Memory
        case "oracle_memory_query":
            let queryText = str(args, "query") ?? ""
            let modules = args["modules"]?.arrayValue?.compactMap { $0.stringValue } ?? []
            let kindsRaw = args["kinds"]?.arrayValue?.compactMap { $0.stringValue } ?? []
            let kinds = kindsRaw.compactMap { ProjectMemoryKind(rawValue: $0) }
            let limit = int(args, "limit") ?? 10
            
            guard let projectStore = runtimeContainer.memoryStore.projectStore else {
                return ToolResult(success: false, error: "Project Memory store is not available. Ensure Oracle OS is running in a valid project workspace.")
            }
            
            let results = projectStore.query(text: queryText, modules: modules, kinds: kinds, limit: limit)
            let serialized = results.map { [
                "id": $0.id,
                "title": $0.title,
                "summary": $0.summary,
                "kind": $0.kind.rawValue,
                "path": $0.path,
                "affected_modules": $0.affectedModules,
            ] as [String: Any] }
            
            return ToolResult(success: true, data: ["records": serialized, "count": serialized.count])
            
        case "oracle_memory_draft":
            guard let title = str(args, "title"),
                  let summary = str(args, "summary"),
                  let kindRaw = str(args, "kind"),
                  let body = str(args, "body") else {
                return ToolResult(success: false, error: "Missing required parameters: title, summary, kind, body")
            }
            guard let kind = ProjectMemoryKind(rawValue: kindRaw) else {
                return ToolResult(success: false, error: "Invalid kind: \(kindRaw)")
            }
            
            guard let projectStore = runtimeContainer.memoryStore.projectStore else {
                return ToolResult(success: false, error: "Project Memory store is not available.")
            }
            
            let modules = args["affected_modules"]?.arrayValue?.compactMap { $0.stringValue } ?? []
            let evidence = args["evidence_refs"]?.arrayValue?.compactMap { $0.stringValue } ?? []
            let knowledgeClass = KnowledgeClass.reusable
            
            do {
                let ref = try projectStore.writeDraft(ProjectMemoryDraft(
                    kind: kind,
                    knowledgeClass: knowledgeClass,
                    title: title,
                    summary: summary,
                    affectedModules: modules,
                    evidenceRefs: evidence,
                    sourceTraceIDs: [],
                    body: body
                ))
                return ToolResult(success: true, data: ["draft_id": ref.id, "path": ref.path])
            } catch {
                return ToolResult(success: false, error: "Failed to write draft: \(error)")
            }

        // Experiments
        case "oracle_experiment_search":
            guard let goal = str(args, "goal_description"),
                  let candidatesArr = args["candidates"]?.arrayValue else {
                return ToolResult(success: false, error: "Missing required parameters: goal_description, candidates")
            }
            
            var candidates = [CandidatePatch]()
            for (i, c) in candidatesArr.enumerated() {
                guard let content = c["content"]?.stringValue,
                      let rp = c["workspace_relative_path"]?.stringValue,
                      let title = c["title"]?.stringValue,
                      let summary = c["summary"]?.stringValue else {
                    return ToolResult(success: false, error: "Candidate \(i) is missing required fields (content, workspace_relative_path, title, summary)")
                }
                candidates.append(CandidatePatch(
                    title: title,
                    summary: summary,
                    workspaceRelativePath: rp,
                    content: content,
                    hypothesis: c["hypothesis"]?.stringValue,
                    strategyKind: c["strategy_kind"]?.stringValue
                ))
            }
            
            let workspaceRoot = FileManager.default.currentDirectoryPath
            let rootURL = URL(fileURLWithPath: workspaceRoot, isDirectory: true)
            let buildTool = BuildToolDetector.detect(at: rootURL)
            
            var buildCommand: BuildSpec? = BuildToolDetector.defaultBuildCommand(for: buildTool, workspaceRoot: rootURL)
            if let customBuild = args["build_command"]?.arrayValue?.compactMap({ $0.stringValue }), !customBuild.isEmpty {
                buildCommand = CommandSpec(
                    category: .build,
                    executable: "/usr/bin/env",
                    arguments: customBuild,
                    workspaceRoot: workspaceRoot,
                    summary: customBuild.joined(separator: " ")
                )
            }
            
            var testCommand: TestSpec? = BuildToolDetector.defaultTestCommand(for: buildTool, workspaceRoot: rootURL)
            if let customTest = args["test_command"]?.arrayValue?.compactMap({ $0.stringValue }), !customTest.isEmpty {
                testCommand = CommandSpec(
                    category: .test,
                    executable: "/usr/bin/env",
                    arguments: customTest,
                    workspaceRoot: workspaceRoot,
                    summary: customTest.joined(separator: " ")
                )
            }
            
            let spec = ExperimentSpec(
                goalDescription: goal,
                workspaceRoot: workspaceRoot,
                candidates: candidates,
                buildCommand: buildCommand,
                testCommand: testCommand
            )
            
            do {
                let results = try await runtimeContainer.experimentManager.run(spec: spec)
                let serialized = results.map { [
                    "id": $0.id,
                    "candidate_title": $0.candidate.title,
                    "selected": $0.selected,
                    "succeeded": $0.succeeded,
                    "elapsed_ms": $0.elapsedMs,
                    "diff_summary": $0.diffSummary,
                    "architecture_risk_score": $0.architectureRiskScore,
                    "command_results": $0.commandResults.map { [
                        "category": $0.category.rawValue,
                        "summary": $0.summary,
                        "succeeded": $0.succeeded,
                        "exit_code": $0.exitCode,
                        "stdout": $0.stdout.count > 1000 ? String($0.stdout.prefix(1000)) + "...(truncated)" : $0.stdout,
                        "stderr": $0.stderr.count > 1000 ? String($0.stderr.prefix(1000)) + "...(truncated)" : $0.stderr
                    ] as [String: Any] }
                ] as [String: Any] }
                return ToolResult(success: true, data: ["results": serialized])
            } catch {
                return ToolResult(success: false, error: "Experiment search failed: \(error)")
            }

        // Architecture
        case "oracle_architecture_review":
            guard let goal = str(args, "goal_description"),
                  let paths = args["candidate_paths"]?.arrayValue?.compactMap({ $0.stringValue }),
                  !paths.isEmpty else {
                return ToolResult(success: false, error: "Missing required parameters: goal_description, candidate_paths")
            }
            let workspaceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            let snapshot = runtimeContainer.repositoryIndexer.indexIfNeeded(workspaceRoot: workspaceRoot)
            let engine = ArchitectureEngine()
            let review = engine.review(goalDescription: goal, snapshot: snapshot, candidatePaths: paths)
            
            if let data = try? JSONEncoder().encode(review),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return ToolResult(success: true, data: ["review": dict])
            }
            return ToolResult(success: false, error: "Failed to serialize architecture review")

        case "oracle_candidate_review":
            guard let goal = str(args, "goal_description"),
                  let candidateRaw = args["candidate"]?.objectValue,
                  let diffSummary = str(args, "diff_summary") else {
                return ToolResult(success: false, error: "Missing required parameters: goal_description, candidate, diff_summary")
            }
            
            guard let content = candidateRaw["content"]?.stringValue,
                  let rp = candidateRaw["workspace_relative_path"]?.stringValue,
                  let title = candidateRaw["title"]?.stringValue,
                  let summary = candidateRaw["summary"]?.stringValue else {
                return ToolResult(success: false, error: "Candidate is missing required fields (content, workspace_relative_path, title, summary)")
            }
            let candidate = CandidatePatch(
                title: title,
                summary: summary,
                workspaceRelativePath: rp,
                content: content,
                hypothesis: candidateRaw["hypothesis"]?.stringValue,
                strategyKind: candidateRaw["strategy_kind"]?.stringValue
            )
            
            let workspaceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            let snapshot = runtimeContainer.repositoryIndexer.indexIfNeeded(workspaceRoot: workspaceRoot)
            let engine = ArchitectureEngine()
            let review = engine.reviewCandidatePatch(
                goalDescription: goal,
                snapshot: snapshot,
                candidate: candidate,
                diffSummary: diffSummary
            )
            
            if let data = try? JSONEncoder().encode(review),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return ToolResult(success: true, data: ["review": dict])
            }
            return ToolResult(success: false, error: "Failed to serialize candidate architecture review")

        // Workflows
        case "oracle_workflow_mine":
            guard let goalPattern = str(args, "goal_pattern") else {
                return ToolResult(success: false, error: "Missing required parameter: goal_pattern")
            }
            let limit = int(args, "limit") ?? 1000
            
            let events = runtimeContainer.traceStore.loadRecentEvents(limit: limit)
            let synthesizer = WorkflowSynthesizer()
            let plans = synthesizer.synthesize(goalPattern: goalPattern, events: events)
            
            let index = WorkflowIndex()
            for plan in plans {
                index.add(plan)
            }
            
            let serialized = plans.compactMap { plan -> [String: Any]? in
                guard let data = try? JSONEncoder().encode(plan),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
                return dict
            }
            return ToolResult(success: true, data: ["mined_count": plans.count, "plans": serialized])

        case "oracle_workflow_list":
            let index = WorkflowIndex()
            let plans = index.allPlans()
            let serialized = plans.compactMap { plan -> [String: Any]? in
                guard let data = try? JSONEncoder().encode(plan),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
                return dict
            }
            return ToolResult(success: true, data: ["count": plans.count, "plans": serialized])

        case "oracle_workflow_execute":
            guard let workflowID = str(args, "workflow_id") else {
                return ToolResult(success: false, error: "Missing required parameter: workflow_id")
            }
            let index = WorkflowIndex()
            guard let plan = index.plan(id: workflowID) else {
                return ToolResult(success: false, error: "Workflow '\(workflowID)' not found.")
            }
            
            // For execution, we can return the exact step progression required
            // or we could bridge it directly to RecipeStore's run logic. For now,
            // we will return the workflow plan details dynamically formatted.
            
            let substitutions: [String: String] = args["parameters"]?.objectValue?.compactMapValues { v in
                switch v {
                case .string(let s): return s
                case .int(let i): return String(i)
                case .double(let d): return String(d)
                case .bool(let b): return String(b)
                default: return nil
                }
            } ?? [:]
            
            // Format for execution instructions
            var executionSteps: [[String: Any]] = []
            for (i, step) in plan.steps.enumerated() {
                let contract = step.actionContract
                // Replace parameters manually if we need to show substituted steps
                executionSteps.append([
                    "step_index": i,
                    "agent_kind": step.agentKind.rawValue,
                    "action_name": contract.skillName,
                    "target": ParameterExtractor.applySlots(to: contract.targetLabel, parameters: substitutions.map { ExtractedParameter(name: $0.key, kind: "string", values: [$0.value]) }, stepIndex: i) ?? "",
                    "path": ParameterExtractor.applySlots(to: contract.workspaceRelativePath, parameters: substitutions.map { ExtractedParameter(name: $0.key, kind: "string", values: [$0.value]) }, stepIndex: i) ?? "",
                    "notes": step.notes
                ])
            }
            
            return ToolResult(success: true, data: [
                "workflow_id": plan.id,
                "goal_pattern": plan.goalPattern,
                "success_rate": plan.successRate,
                "execution_steps": executionSteps
            ])
            
        default:
            return ToolResult(success: false, error: "Unknown tool: \(tool)")
        }
    }

    // MARK: - Response Formatting

    /// Format a ToolResult as MCP content array.
    private static func formatResult(_ result: ToolResult, toolName: String) -> MCPToolResponse {
        let dict = result.toDict()

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
           let jsonStr = String(data: data, encoding: .utf8)
        {
            return MCPToolResponse(content: [.text(jsonStr)], isError: !result.success)
        }

        return errorContent("Failed to serialize response for \(toolName)")
    }

    static func errorContent(_ message: String) -> MCPToolResponse {
        let payload: [String: Any] = [
            "success": false,
            "error": message
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
           let jsonStr = String(data: data, encoding: .utf8) {
            return MCPToolResponse.error(jsonStr)
        }

        // Fallback: do not include the original message to avoid invalid JSON.
        return MCPToolResponse.error("{\"success\":false,\"error\":\"Serialization error\"}")
    }

    // MARK: - Parameter Helpers

    private static func str(_ args: JSONValue, _ key: String) -> String? {
        args[key]?.stringValue
    }

    private static func int(_ args: JSONValue, _ key: String) -> Int? {
        args[key]?.intValue
    }

    private static func double(_ args: JSONValue, _ key: String) -> Double? {
        args[key]?.doubleValue
    }

    private static func bool(_ args: JSONValue, _ key: String) -> Bool? {
        args[key]?.boolValue
    }
}
