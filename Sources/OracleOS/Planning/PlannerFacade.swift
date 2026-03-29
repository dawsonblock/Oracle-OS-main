public protocol PlannerFacade {
    func plan(intent: Intent, state: WorldState) async throws -> Command
}
