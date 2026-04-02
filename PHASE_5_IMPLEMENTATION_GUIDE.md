# Phase 5.2-5.6 Execution Guide: Planner Surface Collapse

## Current Status

**Commit**: `0c15604` (Phase 5.2: Refactored MainPlanner Created)

**What's Done**:
- ✅ MainPlannerRefactored.swift created (all dependencies required)
- ✅ PlannerDependencies.swift factory created
- ✅ Single public entry: `plan(intent, context) -> Command`

**What's Next** (5.3-5.6):

---

## Immediate Next Steps

### 1. Create PlannerContractTests.swift (Phase 5.5 early)
Start with tests FIRST to define the contract:

```swift
import XCTest
@testable import OracleOS

class PlannerContractTests: XCTestCase {

    @MainActor
    func testPlanReturnsCommand() {
        let factory = PlannerTestFactory()
        let planner = factory.makePlanner()
        
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "click the button",
            metadata: [:]
        )
        let context = PlannerContext(
            state: WorldStateModel(),
            memories: [],
            repositorySnapshot: nil
        )
        
        let expectation = expectation(description: "plan returns command")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                XCTAssertNotNil(command)
                XCTAssertEqual(command.metadata.source, "planner.ui")
                expectation.fulfill()
            } catch {
                XCTFail("plan() should not throw: \(error)")
            }
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor
    func testUIIntentReturnsUICommand() {
        let factory = PlannerTestFactory()
        let planner = factory.makePlanner()
        
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "click the sign in button",
            metadata: ["targetID": "signin-btn"]
        )
        let context = PlannerContext(
            state: WorldStateModel(),
            memories: [],
            repositorySnapshot: nil
        )
        
        let expectation = expectation(description: "ui intent returns ui command")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                XCTAssertEqual(command.type, .ui)
                if case .ui(let action) = command.payload {
                    XCTAssertEqual(action.name, "click")
                } else {
                    XCTFail("UI intent should return UI command payload")
                }
                expectation.fulfill()
            } catch {
                XCTFail("plan() should not throw: \(error)")
            }
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    // Add 13+ more test cases following this pattern
}

// Helper factory for tests
class PlannerTestFactory {
    @MainActor
    func makePlanner() -> Planner {
        let deps = RuntimeBootstrap.makePlannerDependencies(
            repositoryIndexer: MockRepositoryIndexer(),
            impactAnalyzer: RepositoryChangeImpactAnalyzer()
        )
        return MainPlannerRefactored(
            workflowIndex: deps.workflowIndex,
            workflowRetriever: deps.workflowRetriever,
            osPlanner: deps.osPlanner,
            codePlanner: deps.codePlanner,
            reasoningEngine: deps.reasoningEngine,
            planEvaluator: deps.planEvaluator,
            promptEngine: deps.promptEngine,
            reasoningThreshold: deps.reasoningThreshold,
            taskGraphStore: deps.taskGraphStore
        )
    }
}

class MockRepositoryIndexer: RepositoryIndexer {
    // Implement mock methods
}
```

### 2. Update RuntimeBootstrap.makeContainer()

Replace the current planner creation with new factory:

```swift
// OLD (current)
let planner = MainPlanner(
    repositoryIndexer: repositoryIndexer,
    impactAnalyzer: impactAnalyzer
)

// NEW (Phase 5.2)
let plannerDeps = RuntimeBootstrap.makePlannerDependencies(
    repositoryIndexer: repositoryIndexer,
    impactAnalyzer: impactAnalyzer
)
let planner = MainPlannerRefactored(
    workflowIndex: plannerDeps.workflowIndex,
    workflowRetriever: plannerDeps.workflowRetriever,
    osPlanner: plannerDeps.osPlanner,
    codePlanner: plannerDeps.codePlanner,
    reasoningEngine: plannerDeps.reasoningEngine,
    planEvaluator: plannerDeps.planEvaluator,
    promptEngine: plannerDeps.promptEngine,
    reasoningThreshold: plannerDeps.reasoningThreshold,
    taskGraphStore: plannerDeps.taskGraphStore
)
```

### 3. Update MainPlanner+Planner.swift

Rename to use MainPlannerRefactored instead:

```swift
// Change from MainPlanner to MainPlannerRefactored
extension MainPlannerRefactored: Planner {
    public func plan(intent: Intent, context: PlannerContext) async throws -> Command {
        // Already implemented in MainPlannerRefactored
    }
}
```

---

## Phase 5.3: Remove Mutable State

Once tests pass, remove from original MainPlanner:

```swift
// DELETE these from MainPlanner.swift:
private var currentGoal: Goal?
public func setGoal(_ goal: Goal)
public func interpretGoal(_ description: String) -> Goal
public func goalReached(state: PlanningState) -> Bool
public func plan(goal: String) -> Plan
public func nextStep(...)  // Keep as private only
```

---

## Phase 5.4: Consolidate Interfaces

Keep only public interface:
```swift
public protocol Planner: Sendable {
    func plan(intent: Intent, context: PlannerContext) async throws -> Command
}
```

All other methods become private.

---

## Phase 5.5: Testing

Run PlannerContractTests with 15+ cases:

```
TestCase 1: testPlanReturnsCommand ✓
TestCase 2: testUIIntentReturnsUICommand ✓
TestCase 3: testCodeIntentReturnsCodeCommand ✓
TestCase 4: testSystemIntentReturnsUICommand ✓
TestCase 5: testSameIntentProducesSameCommand ✓
TestCase 6: testNoMutableStatePollution ✓
TestCase 7: testConcurrentPlansIndependent ✓
TestCase 8: testMemoryCandidatesAvailable ✓
TestCase 9: testMemoryInfluenceAffectsDecision ✓
TestCase 10: testMissingContextThrows ✓
TestCase 11: testInvalidIntentThrows ✓
TestCase 12: testCommandHasProperMetadata ✓
TestCase 13: testTaskGraphNavigationWorks ✓
TestCase 14: testFamilyPlannerFallback ✓
TestCase 15: testReasoningEngineUsed ✓
```

---

## Phase 5.6: Documentation

Create PLANNER_CONTRACT.md:

```markdown
# Planner Contract

## Public Interface
```swift
public protocol Planner: Sendable {
    func plan(intent: Intent, context: PlannerContext) async throws -> Command
}
```

## Semantics

**Input**:
- `intent`: What the user wants (domain, objective, metadata)
- `context`: Current state (world state, memory candidates, repository snapshot)

**Output**:
- `Command`: Typed action to execute (ui/code/build/test/git)

**Behavior**:
- Deterministic: Same input → same command
- Stateless: No mutable currentGoal
- Injected: All dependencies provided by bootstrap
- Honest: Uses task graph, memory, reasoning

## Implementation (MainPlannerRefactored)

- Routes intents to domain-specific planners
- Extracts action intents from metadata
- Returns typed Command with proper metadata
- No state pollution or mutable fields
```

---

## Files to Modify (Summary)

| Phase | File | Change |
|-------|------|--------|
| 5.2 | MainPlannerRefactored.swift | ✅ Created |
| 5.2 | PlannerDependencies.swift | ✅ Created |
| 5.2 | RuntimeBootstrap.swift | Use factory |
| 5.2 | MainPlanner+Planner.swift | Extend MainPlannerRefactored |
| 5.3 | MainPlanner.swift | Remove currentGoal, setGoal, etc. |
| 5.4 | MainPlanner.swift | Remove unused public methods |
| 5.5 | PlannerContractTests.swift | ✅ NEW FILE (15+ tests) |
| 5.6 | PLANNER_CONTRACT.md | ✅ NEW FILE |

---

## Quick Checklist for Implementation

```
Phase 5.2 (Dependency Injection)
☐ Create PlannerTestFactory
☐ Create PlannerContractTests.swift with 3 basic tests
☐ Update RuntimeBootstrap.makeContainer() to use factory
☐ Update MainPlanner+Planner to extend MainPlannerRefactored
☐ Build and verify compiles
☐ Run basic tests to verify contract

Phase 5.3 (Remove Mutable State)
☐ Delete currentGoal field from MainPlanner
☐ Delete setGoal() method
☐ Delete interpretGoal() method
☐ Delete goalReached() method
☐ Delete plan(goal:) method
☐ Update all usages (grep -r "setGoal\|currentGoal")
☐ Build and verify no compilation errors

Phase 5.4 (Consolidate)
☐ Make nextStep() private only
☐ Make nextAction() private only
☐ Verify no external callers remain
☐ Build and verify

Phase 5.5 (Testing)
☐ Add 5 more tests (routing, determinism)
☐ Add 5 more tests (memory, integration)
☐ Add 5 more tests (error, edge cases)
☐ Verify all 15+ tests pass
☐ Add E2E RuntimeOrchestrator tests

Phase 5.6 (Documentation)
☐ Create PLANNER_CONTRACT.md
☐ Update Planner.swift comments
☐ Update MainPlanner comments
☐ Review and commit
```

---

## Testing Strategy Refined

**Unit Tests** (PlannerContractTests):
- Input validation
- Output type validation
- Routing (UI/Code/System)
- Determinism
- Error handling

**Integration Tests**:
- RuntimeOrchestrator.submitIntent() calls planner.plan()
- Plan succeeds and command is executed
- Multiple intents don't interfere (no state leak)

**E2E Tests**:
- Full cycle: Intent → Plan → Execute
- Verify no state pollution
- Concurrent plans work independently

---

## Expected Outcome

After Phase 5.6:

✅ Single honest entry point: `plan(intent, context) -> Command`
✅ No mutable state (currentGoal deleted)
✅ All dependencies injected by bootstrap
✅ Unused methods removed
✅ 15+ PlannerContractTests pass
✅ Documentation reflects reality

**Progress**: 5.6/8 phases complete (70%)

---

## Git Commits Expected

```
Phase 5.3: Remove Planner Mutable State (currentGoal)
Phase 5.4: Consolidate Planner Interfaces (remove unused methods)
Phase 5.5: Add Planner Contract Tests (15+ cases)
Phase 5.6: Document Honest Planner Contract
Phase 5 Complete: Planner Surface Collapse
```

---

## Next Session Prep

If pausing:
- All groundwork done (MainPlannerRefactored created, factory ready)
- Tests define the contract (start with 3, add 12 more)
- Clear migration path documented
- Ready to execute 5.3-5.6 in ~2 hours

---

## Notes

1. **MainPlannerRefactored** is the new implementation alongside old
2. **Tests come first** to define honest contract
3. **Gradual replacement** (don't delete old yet, just deprecate)
4. **Bootstrap wires everything** (strong injection point)
5. **Planner contract is honest** after this phase

Ready to continue with Phase 5.3 next!
