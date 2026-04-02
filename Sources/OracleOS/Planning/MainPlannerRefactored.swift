import Foundation

// Phase 5.2: Refactored MainPlanner with strong dependency injection.
// All dependencies are required and injected by RuntimeBootstrap.
// No optional parameters, no mutable currentGoal state.
//
// The planner chooses execution structure only: workflow, graph path, graph edge,
// or bounded exploration. It must not resolve exact UI targets, mutate files,
// execute commands, or inline recovery mechanics.
//
// The planner navigates the live TaskLedger as its primary control substrate.
// Each planning cycle:
//   1. Updates the current task-graph node from world state
//   2. Expands candidate edges from the current node
//   3. Evaluates future paths via LedgerNavigator
//   4. Selects the best edge
// The task graph is the canonical representation of task position — not
// a post-hoc log.
public final class MainPlanner: @unchecked Sendable {
    // All dependencies required and injected by RuntimeBootstrap
    public let workflowIndex: WorkflowIndex
    private let workflowRetriever: WorkflowRetriever
    private let osPlanner: OSPlanner
    private let codePlanner: CodePlanner
    private let reasoningEngine: ReasoningEngine
    private let planEvaluator: PlanEvaluator
    private let promptEngine: PromptEngine
    private let reasoningThreshold: Double
    public let taskGraphStore: TaskLedgerStore
    private let graphNavigator: LedgerNavigator
    private let graphScorer: LedgerScorer
    private let planGenerator: PlanGenerator

    // Phase 5.2: Strong dependency injection constructor
    // All parameters are required. RuntimeBootstrap creates dependencies upfront.
    public init(
        workflowIndex: WorkflowIndex,
        workflowRetriever: WorkflowRetriever,
        osPlanner: OSPlanner,
        codePlanner: CodePlanner,
        reasoningEngine: ReasoningEngine,
        planEvaluator: PlanEvaluator,
        promptEngine: PromptEngine,
        reasoningThreshold: Double,
        taskGraphStore: TaskLedgerStore,
        graphNavigator: LedgerNavigator = LedgerNavigator(),
        graphScorer: LedgerScorer = LedgerScorer()
    ) {
        self.workflowIndex = workflowIndex
        self.workflowRetriever = workflowRetriever
        self.osPlanner = osPlanner
        self.codePlanner = codePlanner
        self.reasoningEngine = reasoningEngine
        self.planEvaluator = planEvaluator
        self.promptEngine = promptEngine
        self.reasoningThreshold = reasoningThreshold
        self.taskGraphStore = taskGraphStore
        self.graphNavigator = graphNavigator
        self.graphScorer = graphScorer
        
        self.planGenerator = PlanGenerator(
            reasoningEngine: reasoningEngine,
            planEvaluator: planEvaluator,
            osPlanner: osPlanner,
            codePlanner: codePlanner
        )
    }

    // Phase 5.4: Single public entry point matching Planner protocol
    // All functionality available through this interface
    public func plan(intent: Intent, context: PlannerContext) async throws -> Command {
        // Route based on intent domain, using full planner capabilities
        switch intent.domain {
        case .ui:
            return try await planUIIntent(intent, context: context)
        case .code:
            return try await planCodeIntent(intent, context: context)
        case .system, .mixed:
            return try await planSystemIntent(intent, context: context)
        }
    }

    // MARK: - Domain Planners

    private func planUIIntent(_ intent: Intent, context: PlannerContext) async throws -> Command {
        if let actionIntent = decodeActionIntent(from: intent) {
            return commandFrom(actionIntent: actionIntent, fallbackIntent: intent)
        }

        // Route UI intents to click/type/focus/read based on objective
        let objective = intent.objective.lowercased()
        let metadata = CommandMetadata(intentID: intent.id, source: "planner.ui")

        if objective.contains("click") || objective.contains("tap") || objective.contains("press") {
            let targetID = intent.metadata["targetID"] ?? intent.metadata["query"] ?? intent.objective
            let app = intent.metadata["app"] ?? context.state.snapshot.activeApplication ?? "unknown"
            return Command(
                type: .ui,
                payload: .ui(UIAction(name: "click", app: app, query: targetID)),
                metadata: metadata
            )
        }

        if objective.contains("type") || objective.contains("enter") || objective.contains("input") {
            let text = intent.metadata["text"] ?? intent.objective
            let targetID = intent.metadata["targetID"] ?? intent.metadata["query"] ?? "focused"
            let app = intent.metadata["app"] ?? context.state.snapshot.activeApplication
            return Command(
                type: .ui,
                payload: .ui(UIAction(name: "type", app: app, query: targetID, text: text)),
                metadata: metadata
            )
        }

        if objective.contains("focus") || objective.contains("switch") || objective.contains("activate") {
            let app = intent.metadata["app"] ?? context.state.snapshot.activeApplication ?? "unknown"
            return Command(
                type: .ui,
                payload: .ui(UIAction(name: "focus", app: app)),
                metadata: metadata
            )
        }

        if objective.contains("read") || objective.contains("get") || objective.contains("observe") {
            let targetID = intent.metadata["targetID"] ?? intent.metadata["query"] ?? intent.objective
            let app = intent.metadata["app"] ?? context.state.snapshot.activeApplication
            return Command(
                type: .ui,
                payload: .ui(UIAction(name: "read", app: app, query: targetID)),
                metadata: metadata
            )
        }

        // Default: try to focus the active app
        let app = context.state.snapshot.activeApplication ?? "unknown"
        return Command(type: .ui, payload: .ui(UIAction(name: "focus", app: app)), metadata: metadata)
    }

    private func planCodeIntent(_ intent: Intent, context: PlannerContext) async throws -> Command {
        if let actionIntent = decodeActionIntent(from: intent) {
            return commandFrom(actionIntent: actionIntent, fallbackIntent: intent)
        }

        let objective = intent.objective.lowercased()
        let metadata = CommandMetadata(intentID: intent.id, source: "planner.code")

        if objective.contains("search") || objective.contains("find") || objective.contains("query") {
            return Command(
                type: CommandType.code,
                payload: .code(CodeAction(name: "searchRepository", query: intent.objective)),
                metadata: metadata
            )
        }

        if objective.contains("read") || objective.contains("open") || objective.contains("view") {
            let path = intent.metadata["filePath"] ?? intent.objective
            return Command(
                type: CommandType.code,
                payload: .code(CodeAction(name: "readFile", filePath: path)),
                metadata: metadata
            )
        }

        if objective.contains("edit") || objective.contains("modify") || objective.contains("patch") {
            let path = intent.metadata["filePath"] ?? ""
            let patch = intent.metadata["patch"] ?? intent.objective
            return Command(
                type: CommandType.code,
                payload: .file(FileMutationSpec(path: path, operation: .write, content: patch)),
                metadata: metadata
            )
        }

        if objective.contains("build") || objective.contains("compile") {
            let workspacePath = intent.metadata["workspacePath"]
                ?? context.repositorySnapshot?.workspaceRoot
                ?? FileManager.default.currentDirectoryPath
            let spec = BuildSpec(
                workspaceRoot: workspacePath,
                target: intent.metadata["target"],
                configuration: BuildConfiguration(rawValue: (intent.metadata["configuration"] ?? "debug").lowercased()) ?? .debug
            )
            return Command(type: CommandType.code, payload: .build(spec), metadata: metadata)
        }

        if objective.contains("test") || objective.contains("run test") {
            let workspacePath = intent.metadata["workspacePath"]
                ?? context.repositorySnapshot?.workspaceRoot
                ?? FileManager.default.currentDirectoryPath
            let spec = TestSpec(
                workspaceRoot: workspacePath,
                target: intent.metadata["target"]
            )
            return Command(type: CommandType.code, payload: .test(spec), metadata: metadata)
        }

        return Command(
            type: CommandType.code,
            payload: .code(CodeAction(name: "searchRepository", query: intent.objective)),
            metadata: metadata
        )
    }

    private func planSystemIntent(_ intent: Intent, context: PlannerContext) async throws -> Command {
        if let actionIntent = decodeActionIntent(from: intent) {
            return commandFrom(actionIntent: actionIntent, fallbackIntent: intent)
        }

        let objective = intent.objective.lowercased()
        let metadata = CommandMetadata(intentID: intent.id, source: "planner.system")

        if objective.contains("launch") || objective.contains("open app") || objective.contains("start") {
            let bundleID = intent.metadata["bundleID"] ?? intent.objective
            return Command(
                type: .ui,
                payload: .ui(UIAction(name: "launchApp", app: bundleID)),
                metadata: metadata
            )
        }

        if objective.contains("url") || objective.contains("http") || objective.contains("website") {
            let urlString = intent.metadata["url"] ?? intent.objective
            return Command(
                type: .ui,
                payload: .ui(UIAction(name: "openURL", query: urlString)),
                metadata: metadata
            )
        }

        // Default: try to launch app
        let bundleID = intent.metadata["bundleID"] ?? intent.objective
        _ = context
        return Command(
            type: .ui,
            payload: .ui(UIAction(name: "launchApp", app: bundleID)),
            metadata: metadata
        )
    }

    private func decodeActionIntent(from intent: Intent) -> ActionIntent? {
        guard let encoded = intent.metadata["action_intent_base64"],
              let data = Data(base64Encoded: encoded)
        else {
            return nil
        }
        return try? JSONDecoder().decode(ActionIntent.self, from: data)
    }

    private func commandFrom(actionIntent: ActionIntent, fallbackIntent: Intent) -> Command {
        let source = fallbackIntent.metadata["source"] ?? "planner.action-intent"
        let metadata = CommandMetadata(
            intentID: fallbackIntent.id,
            source: source,
            traceTags: [actionIntent.agentKind.rawValue, actionIntent.action]
        )
        let normalizedApp: String? = {
            let trimmed = actionIntent.app.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "unknown" {
                return nil
            }
            return trimmed
        }()

        if let payload = actionIntent.commandPayload {
            var finalPayload = payload
            if case .file(let s) = payload, s.operation == .write {
                let text = actionIntent.text
                finalPayload = .file(FileMutationSpec(path: s.path, operation: .write, content: text, workspaceRoot: s.workspaceRoot))
            }
            return Command(type: .code, payload: finalPayload, metadata: metadata)
        }

        let modifiers: [String]? = {
            if let explicit = actionIntent.modifiers {
                return explicit
            }
            guard (actionIntent.action == "press" || actionIntent.action == "hotkey"),
                  let encoded = actionIntent.role
            else {
                return nil
            }
            return encoded.split(separator: "+").map(String.init)
        }()

        let inferredAmount: Int? = {
            if let amount = actionIntent.amount {
                return amount
            }
            return actionIntent.action == "scroll" ? actionIntent.count : nil
        }()

        let uiAction = UIAction(
            name: actionIntent.action,
            app: normalizedApp,
            query: actionIntent.query,
            text: actionIntent.text,
            role: actionIntent.role,
            domID: actionIntent.domID,
            x: actionIntent.x,
            y: actionIntent.y,
            button: actionIntent.button,
            count: actionIntent.count,
            windowTitle: actionIntent.windowTitle,
            clear: actionIntent.clear,
            modifiers: modifiers,
            amount: inferredAmount,
            width: actionIntent.width,
            height: actionIntent.height
        )
        let isCode = actionIntent.agentKind == .code
        if isCode {
            return Command(type: CommandType.code, payload: .code(CodeAction(name: actionIntent.action, query: actionIntent.query)), metadata: metadata)
        }
        return Command(type: .ui, payload: .ui(uiAction), metadata: metadata)
    }
}
