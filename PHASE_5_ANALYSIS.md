# Phase 5 Analysis: Planner Surface Collapse

## Current Problem: Broken Contract

### Two Interfaces, One Implementation

**Public Interface (Planner protocol)**:
```swift
public protocol Planner: Sendable {
    func plan(intent: Intent, context: PlannerContext) async throws -> Command
}
```

**Real Implementation (MainPlanner)**:
```swift
public final class MainPlanner {
    // Rich interface with task graphs, reasoning, multiple strategies
    func nextStep(...) -> PlannerDecision?
    func nextAction(...) -> ActionContract?
    func setGoal(_ goal: Goal)
    func goalReached(state: PlanningState) -> Bool
    // ...
}
```

**Adapter (MainPlanner+Planner.swift)**:
```swift
extension MainPlanner: Planner {
    public func plan(intent: Intent, context: PlannerContext) async throws -> Command {
        // Simple domain-based routing ONLY
        // Doesn't use task graphs, reasoning, or any MainPlanner functionality
        switch intent.domain {
        case .ui: return try await planUIIntent(...)
        case .code: return try await planCodeIntent(...)
        }
    }
}
```

### The Disconnect

**RuntimeOrchestrator calls**:
```
planner.plan(intent, state) → Command
```

**But MainPlanner+Planner just does naive intent routing**:
- No task graph navigation
- No reasoning engine
- No memory influence
- No strategy selection
- Ignores all the complex functionality in MainPlanner!

---

## What Should Happen

The planner should expose an **honest contract** that reflects what it actually does:

```
Intent + Context + Memory + Graph → Command
```

Where:
- **Intent**: What the user wants
- **Context**: Current world state
- **Memory**: Past experience (memory influence)
- **Graph**: Task graph state and viable paths
- **Command**: What to execute next

---

## What Needs to Collapse

### Layer 1: Too Many Entry Points
- `plan(goal: String)` ← Returns Plan, unused
- `setGoal(_ goal: Goal)` ← Mutable state
- `interpretGoal(_ description: String)` ← Goal interpretation
- `nextStep()` ← Complex method, signature doesn't match protocol
- `nextAction()` ← Wrapper around nextStep
- `plan(intent, context)` ← Protocol method, just routes

**Should collapse to**: Single entry point `plan(intent, context) -> Command`

### Layer 2: Overloaded Constructor
```swift
public init(
    repositoryIndexer: RepositoryIndexer,
    impactAnalyzer: RepositoryChangeImpactAnalyzer,
    workflowIndex: WorkflowIndex? = nil,           // ← Optional
    osPlanner: OSPlanner? = nil,                   // ← Optional
    codePlanner: CodePlanner? = nil,               // ← Optional
    reasoningEngine: ReasoningEngine? = nil,       // ← Optional
    planEvaluator: PlanEvaluator? = nil,           // ← Optional
    promptEngine: PromptEngine = PromptEngine(),   // ← Default
    reasoningThreshold: Double = 0.6,              // ← Default
    taskGraphStore: TaskLedgerStore? = nil         // ← Optional
)
```

**Problem**: 7 optional parameters that create sub-instances if not provided. Constructor does its own dependency injection.

**Should be**: All dependencies required and injected by bootstrap.

### Layer 3: Mutable Goal State
```swift
private var currentGoal: Goal?

public func setGoal(_ goal: Goal) {
    currentGoal = goal
}
```

**Problem**: Goal is mutable, can be changed between cycles, violates immutability.

**Should be**: Pass goal with each request (part of Intent).

### Layer 4: Internal Family Dispatch
```swift
private func familyPlannerDecision(...) -> PlannerDecision? {
    switch taskContext.agentKind {
    case .os: return osPlanner.nextStep(...)
    case .code: return codePlanner.nextStep(...)
    }
}
```

**Problem**: Family planners have complex signatures that don't match Planner protocol.

**Should be**: Family planners implement Planner protocol directly.

---

## Honest Contract After Collapse

### Input
```swift
struct PlanInput: Sendable {
    let intent: Intent
    let context: PlannerContext
    // context contains:
    // - state: WorldStateModel
    // - memories: [MemoryCandidate]
    // - repositorySnapshot: RepositorySnapshot?
}
```

### Output
```swift
public struct Command: Sendable {
    let id: UUID
    let type: CommandType
    let payload: CommandPayload
    let metadata: CommandMetadata
}
```

### Method Signature
```swift
public func plan(intent: Intent, context: PlannerContext) async throws -> Command {
    // Single entry point
    // No mutable state (currentGoal)
    // All dependencies available (task graph, memory, graph store)
    // Return typed Command with explicit metadata
}
```

### What the Planner Actually Does
1. Interprets intent domain (ui/code/system)
2. Queries task graph for viable paths
3. Scores paths with memory influence
4. Selects best path
5. Returns Command representing that path

---

## Files to Modify

### 1. **MainPlanner.swift**
- Remove `currentGoal` mutable state
- Remove `setGoal()`, `interpretGoal()`, `goalReached()`
- Remove `nextStep()`, `nextAction()` (internal only)
- Remove `plan(goal: String)` (unused)
- Reduce constructor parameters (inject all dependencies)
- Make internal family dispatch private

### 2. **MainPlanner+Planner.swift**
- Expand `plan(intent, context)` to call internal `nextStep()` instead of naive routing
- Use task graph, memory, graph store
- Return Command that matches selected PlannerDecision

### 3. **Planner.swift**
- Clarify contract documentation
- Add method documentation with input/output semantics

### 4. **RuntimeBootstrap.swift**
- Constructor: Create all MainPlanner dependencies before construction
- Pass as explicit arguments (not let MainPlanner create them)

---

## Testing Strategy

### PlannerContractTests
1. **Input Validation**
   - plan() with valid intent/context
   - plan() with missing context fields
   - plan() with null world state

2. **Output Validation**
   - Returns Command (not Plan, not PlannerDecision)
   - Command has proper metadata (source="planner")
   - Command payload matches intent domain

3. **Domain Routing**
   - UI intent → UI command
   - Code intent → Code command
   - System intent → UI command

4. **Determinism**
   - Same intent/context → same command
   - No dependency on mutable state

5. **Error Handling**
   - Invalid intent → throws
   - Missing context → throws
   - No task graph → graceful fallback

6. **Memory Integration**
   - Planner receives memory candidates
   - Uses memory bias in path scoring
   - Memory influences decision (testable)

### E2E RuntimeOrchestrator Tests
1. submitIntent() calls planner.plan()
2. Plan succeeds and command is executed
3. Multiple intents don't interfere (no state leak)

---

## Collapse Phases

### Phase 5.1: Analysis & Documentation (current)
- [x] Identify two-interface problem
- [x] Document honest contract
- [x] List collapse requirements

### Phase 5.2: Dependency Injection
- [ ] Create factory method in RuntimeBootstrap
- [ ] Inject all MainPlanner dependencies
- [ ] Remove optional parameters from constructor

### Phase 5.3: Remove Mutable State
- [ ] Delete currentGoal field
- [ ] Delete setGoal() method
- [ ] Pass goal through each call

### Phase 5.4: Consolidate Interfaces
- [ ] Remove unused public methods
- [ ] Expand plan(intent, context) to use task graph
- [ ] Make internal methods private

### Phase 5.5: Testing
- [ ] Add PlannerContractTests (15+ tests)
- [ ] Add E2E RuntimeOrchestrator integration tests
- [ ] Verify determinism and no state pollution

### Phase 5.6: Documentation
- [ ] Update Planner.swift comments
- [ ] Document MainPlanner contract
- [ ] Remove old references in comments

---

## Risk Assessment

### Low Risk
- Removing unused public methods (no callers)
- Moving goal to parameter (runtime only)
- Dependency injection (bootstrap-level change)

### Medium Risk
- Changing plan() signature from routing to task-graph aware
- Ensure all logic paths still work

### High Risk
- None identified; planner is well-isolated

---

## Success Criteria

✅ Single entry point: `plan(intent, context) -> Command`
✅ No mutable state (currentGoal)
✅ All dependencies injected by bootstrap
✅ 15+ PlannerContractTests pass
✅ E2E tests verify no state pollution
✅ Documentation reflects honest contract
