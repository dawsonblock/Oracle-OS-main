# Oracle OS — Planner Surface (Phase 5)

## The Canonical Planner

The runtime-facing `Planner` protocol is the **only supported entry point** for goal decomposition:

```swift
public protocol Planner: Sendable {
    func plan(intent: Intent, context: PlannerContext) async throws -> Command
}
```

**Contract**:
- Takes typed `Intent` (goal + metadata)
- Returns typed `Command` (executable action)
- No state mutation, no side effects, no execution
- No imports of Execution/ or Action/ modules

**Implementation**:
- `MainPlanner` implements `Planner`
- Dispatches to domain routers: UI (.ui) or Code (.code)
- Routers use heuristics + metadata to emit commands
- Result is deterministic single command, not a plan

## What Looks Like a Planner But Isn't

The codebase contains **extensive planning infrastructure** that supports:
- Workflow synthesis and retrieval
- Task graph navigation and scoring
- Graph search and path expansion
- LLM-based reasoning and operator selection
- Strategy evaluation and selection
- Plan simulation and candidate ranking

This infrastructure is:
- ✅ **Internal to MainPlanner** (not part of runtime contract)
- ✅ **Used by the command emission logic** (heuristic dispatch)
- ✅ **Not exposed to RuntimeOrchestrator**
- ✅ **Can be refactored, improved, or replaced without breaking the spine**

Examples of internal planning subsystems:
- `Planning/Reasoning/` — LLM-driven reasoning (internal)
- `Planning/Strategies/` — Multi-strategy selection (internal)
- `Planning/Workflows/` — Workflow synthesis (internal)
- `Planning/GraphSearch/` — Task graph navigation (internal)

## The Actual Planner Behavior

The planner as used by RuntimeOrchestrator is a **stateless function**:

```
Intent {"objective": "click the save button"}
  ↓
MainPlanner.plan(intent, context)
  ↓
Domain router (UI / Code)
  ↓
Heuristic matching on objective + metadata
  ↓
Command {"type": "ui", "payload": UIAction(name="click", ...)}
```

**Key properties**:
- Synchronous once intent reaches planner
- Deterministic given same input
- No state carried between calls
- No memory updates during planning
- Single command per intent (not a multi-step plan)

## Documentation Honesty

The README and docs overclaim what the planner does because they conflate:
- What `MainPlanner` **can do** (through internal subsystems)
- What the planner **must do** (through the Planner protocol)

**Fix**: Docs will state clearly that:
- The **public planner surface** is a heuristic command emitter
- The **internal planning subsystems** are available for future expansion
- The **current supported path** uses string matching on objective + metadata
- Advanced reasoning/synthesis are **experimental and optional**, not required

## Phase 5 Work

### Changes Made
1. ✅ Marked internal planning subsystems as non-canonical
2. ✅ Clarified planner contract (heuristic dispatch only)
3. ✅ Updated docs to separate internal from supported

### What Remains  
1. [ ] Move Reasoning, Strategies, GraphSearch to experimental/ or mark @experimental
2. [ ] Add feature flags for advanced planning
3. [ ] Document supported planning capabilities (what actually works now)
4. [ ] Add tests for the canonical planner path only
5. [ ] Remove or deprecate stale planning paths

## Example: Current vs Future

### Current (Phase 5)
```swift
// User intent
Intent(objective: "click the button that saves")

// Planner receives it
MainPlanner.plan(intent)
  // Looks at objective string
  // Finds "click" and "save"
  // Emits command

// Result
Command(type: .ui, payload: UIAction(name: "click", ...))
```

### Future (when reasoning stabilizes)
```swift
// Same intent, richer planning
Intent(objective: "click the button that saves", metadata: [
    "targetLabel": "Save",
    "withinApp": "TextEdit",
    "ifModalPresent": "dismiss_first"
])

// Planner could route through reasoning instead of heuristics
// But the Planner protocol doesn't change
// Implementation detail only
```

## Summary

The planner surface is **stable and narrow**. The internal planning implementation is **complex but private**. This separation means:

- ✅ The runtime can rely on a predictable command-emitting planner
- ✅ Planning algorithms can be improved internally without breaking anything
- ✅ Future reasoning/synthesis can be swapped in later
- ✅ Tests verify the contract, not the implementation

**The audit claim that the planner is "narrower than docs suggest" is correct.** This document makes that distinction explicit.
