import Foundation

/// Phase 5.2: RuntimeBootstrap factory for MainPlanner dependencies
/// Creates all planner dependencies upfront with strong injection.
extension RuntimeBootstrap {
    
    /// Create all MainPlanner dependencies at bootstrap time.
    /// This ensures strong dependency injection and no optional parameters.
    static func makePlannerDependencies(
        repositoryIndexer: RepositoryIndexer,
        impactAnalyzer: RepositoryChangeImpactAnalyzer,
        promptEngine: PromptEngine = PromptEngine()
    ) -> PlannerDependencies {
        // Core shared dependencies
        let workflowIndex = WorkflowIndex()
        let workflowRetriever = WorkflowRetriever()
        let taskGraphStore = TaskLedgerStore()
        let reasoningThreshold = 0.6
        
        // Plan evaluation
        let planEvaluator = PlanEvaluator(workflowRetriever: workflowRetriever)
        
        // Domain planners (OS and Code)
        let osPlanner = OSPlanner(
            workflowIndex: workflowIndex,
            workflowRetriever: workflowRetriever,
            promptEngine: promptEngine
        )
        let codePlanner = CodePlanner(
            repositoryIndexer: repositoryIndexer,
            impactAnalyzer: impactAnalyzer,
            workflowIndex: workflowIndex,
            workflowRetriever: workflowRetriever,
            promptEngine: promptEngine
        )
        
        // Reasoning engine
        let reasoningEngine = ReasoningEngine()
        
        return PlannerDependencies(
            workflowIndex: workflowIndex,
            workflowRetriever: workflowRetriever,
            osPlanner: osPlanner,
            codePlanner: codePlanner,
            reasoningEngine: reasoningEngine,
            planEvaluator: planEvaluator,
            promptEngine: promptEngine,
            reasoningThreshold: reasoningThreshold,
            taskGraphStore: taskGraphStore
        )
    }
}

/// Container for all MainPlanner dependencies.
/// Keeps dependencies organized and makes injection explicit.
struct PlannerDependencies {
    let workflowIndex: WorkflowIndex
    let workflowRetriever: WorkflowRetriever
    let osPlanner: OSPlanner
    let codePlanner: CodePlanner
    let reasoningEngine: ReasoningEngine
    let planEvaluator: PlanEvaluator
    let promptEngine: PromptEngine
    let reasoningThreshold: Double
    let taskGraphStore: TaskLedgerStore
}
