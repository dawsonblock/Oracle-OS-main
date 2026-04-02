# Planner Contract

## Overview

The Planner is the single decision-making interface for the runtime. It takes an Intent (what the user wants) and a PlannerContext (current state) and returns a typed Command (what to execute).

## Public Interface

```swift
public protocol Planner: Sendable {
    func plan(intent: Intent, context: PlannerContext) async throws -> Command
}
```

## Semantics

### Input: Intent
```swift
struct Intent: Sendable {
    let id: UUID
    let domain: IntentDomain  // .ui, .code, .system, .mixed
    let objective: String     // What the user wants to do
    let metadata: [String: String]  // Additional context
}
```

**Domain** determines the planner routing:
- `.ui`: User interface actions (click, type, focus, read)
- `.code`: Code manipulation (search, read, edit, build, test)
- `.system`: System operations (launch app, open URL)
- `.mixed`: Could be either (planner routes based on metadata)

**Objective** is parsed for action detection:
- "click *" → UIAction(name: "click")
- "type *" → UIAction(name: "type")
- "search *" → CodeAction(name: "searchRepository")
- "build" → BuildSpec (typed command)
- "test" → TestSpec (typed command)

**Metadata** provides additional hints:
- `targetID`: Element to interact with
- `text`: Text to type/input
- `filePath`: File to read/edit
- `workspacePath`: Workspace root for build/test

### Input: PlannerContext
```swift
struct PlannerContext: Sendable {
    let state: WorldStateModel          // Current application state
    let memories: [MemoryCandidate]     // Past experience (unused in MVP)
    let repositorySnapshot: RepositorySnapshot?  // Code structure
}
```

### Output: Command
```swift
struct Command: Sendable {
    let id: UUID
    let type: CommandType  // .ui, .code, .build, .test, .file, .git
    let payload: CommandPayload  // Typed payload matching type
    let metadata: CommandMetadata
}

enum CommandPayload {
    case ui(UIAction)
    case code(CodeAction)
    case build(BuildSpec)
    case test(TestSpec)
    case file(FileMutationSpec)
    case git(GitSpec)
}
```

## Behavior

### Determinism
Same intent + context always produces the same command.
- No mutable state (currentGoal)
- No side effects during planning
- Pure function semantics

### Statefulness
Zero mutable state across calls:
- No goal persistence
- No internal session state
- Each call is independent

### Concurrency
Multiple plans can be made concurrently without interference:
- No shared mutable state
- Thread-safe (Sendable types)
- No race conditions

### Type Safety
All outputs are strongly typed:
- CommandPayload is a discriminated union
- No [String: Any] or casting
- Type errors caught at compile time

## Implementation: MainPlannerRefactored

The honest implementation of the Planner protocol.

### Dependency Injection
All 9 dependencies are required:
```swift
public init(
    workflowIndex: WorkflowIndex,
    workflowRetriever: WorkflowRetriever,
    osPlanner: OSPlanner,
    codePlanner: CodePlanner,
    reasoningEngine: ReasoningEngine,
    planEvaluator: PlanEvaluator,
    promptEngine: PromptEngine,
    reasoningThreshold: Double,
    taskGraphStore: TaskLedgerStore
)
```

No optional parameters. All created by RuntimeBootstrap.makePlannerDependencies().

### Routing Logic
```swift
public func plan(intent: Intent, context: PlannerContext) async throws -> Command {
    switch intent.domain {
    case .ui:
        return try await planUIIntent(intent, context: context)
    case .code:
        return try await planCodeIntent(intent, context: context)
    case .system, .mixed:
        return try await planSystemIntent(intent, context: context)
    }
}
```

### Domain-Specific Logic

**UI Intent Planning** (planUIIntent):
- Objective parsing: "click" → UIAction(name: "click")
- Extracts: targetID, app, query from metadata
- Returns: Command with .ui payload and UIAction

**Code Intent Planning** (planCodeIntent):
- Objective parsing: "search" → CodeAction(name: "searchRepository")
- Objective parsing: "build" → BuildSpec (typed)
- Objective parsing: "test" → TestSpec (typed)
- Returns: Command with appropriate typed payload

**System Intent Planning** (planSystemIntent):
- Objective parsing: "launch" → UIAction(name: "launchApp")
- Objective parsing: "url" → UIAction(name: "openURL")
- Returns: Command with .ui payload

## Contract Guarantees

### ✓ Single Entry Point
One method: `plan(intent, context) -> Command`
No side effects, no state mutation, no hidden APIs.

### ✓ Type Safety
All inputs and outputs are strongly typed.
No `[String: Any]`, no unsafe casting, no dynamic dispatch.

### ✓ Determinism
`plan(X, Y)` always returns the same result.
No mutable state, no randomness, no side effects.

### ✓ Statefulness
Zero mutable state across calls.
Each call independent, no session persistence.

### ✓ Concurrency Safe
Multiple concurrent plans don't interfere.
Sendable types, no shared mutable state.

### ✓ Explicit Dependencies
All dependencies required and injected.
No optional parameters, no internal creation.

### ✓ Honest Contract
What the protocol says is what it does.
No hidden functionality, no unreachable features.

## Contract Violations

These would violate the contract:

```swift
// ❌ Mutable state (violates statefulness)
private var currentGoal: Goal?

// ❌ Optional parameters (violates explicit injection)
public init(..., osPlanner: OSPlanner? = nil)

// ❌ Multiple entry points (violates single interface)
public func nextStep(...)
public func setGoal(...)

// ❌ Type-unsafe returns (violates type safety)
return ["action": "click"] as [String: Any]

// ❌ Side effects (violates determinism)
currentGoal = newGoal
memoryStore.recordControl(...)
```

## Contract Verification

The contract is verified by comprehensive tests in `PlannerContractTests.swift`:

- 18 tests covering all aspects
- Determinism: same intent → same command
- Type safety: all payloads properly typed
- Domain routing: correct command for each domain
- Concurrency: multiple plans work independently
- Statefulness: no pollution between calls
- Objective parsing: intents correctly routed to actions

## Migration Path

### Old Implementation (MainPlanner)
- Mutable currentGoal state
- Optional constructor parameters
- Multiple entry points (nextStep, setGoal, etc.)
- Eventually deprecated

### New Implementation (MainPlannerRefactored)
- Honest contract implementation
- Required constructor parameters
- Single entry point
- Integrated into RuntimeBootstrap

### Transition
1. New code uses MainPlannerRefactored directly
2. Old tests gradually updated to use new planner
3. Old MainPlanner deprecated and eventually removed
4. Full transition to honest contract

## Usage Example

```swift
// Create a planner (via RuntimeBootstrap)
let planner = /* injected by bootstrap */

// Create an intent (what user wants)
let intent = Intent(
    id: UUID(),
    domain: .ui,
    objective: "click the login button",
    metadata: ["targetID": "signin-btn", "app": "Chrome"]
)

// Create context (current state)
let context = PlannerContext(
    state: currentWorldState,
    memories: [],
    repositorySnapshot: nil
)

// Get command to execute
let command = try await planner.plan(intent: intent, context: context)

// command is strongly typed, ready for execution
if case .ui(let action) = command.payload {
    executor.execute(command)
}
```

## Future Enhancement Opportunities

### Not in Current Contract
- Memory-based planning (memories param unused in MVP)
- Repository-aware code planning (snapshot for IDE features)
- Multi-step planning (compound intents)

### Potential Extensions
- Constraint-based planning (must not modify X)
- Preference-based planning (prefer Y action)
- Async validation (async command verification)

### Backwards Compatibility
The contract is stable and extensible:
- New intent domains can be added
- New command types can be added
- New metadata fields can be added
- Existing code continues working

## Documentation

- **This file**: Planner contract definition and guarantees
- **MainPlannerRefactored.swift**: Implementation with comments
- **PlannerContractTests.swift**: Contract verification tests
- **RuntimeBootstrap.swift**: Dependency injection and creation

## Related

- **RuntimeOrchestrator**: Calls `planner.plan()` to get commands
- **VerifiedExecutor**: Executes the returned Command
- **Planner protocol**: Sources/OracleOS/Planning/Planner.swift
