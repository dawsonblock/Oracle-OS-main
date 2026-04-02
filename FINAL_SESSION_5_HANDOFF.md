# Final Handoff for Phase 5.4-5.6 Completion

## Current Status

**Last Commit**: `b80668f` (Session 5 Final Summary)
**Progress**: 5.2/8 phases complete (58.5%)
**Status**: Phase 5.3 strategy clarified, phases 5.4-5.6 ready to execute

---

## What's Done (Phase 5.2)

✅ **MainPlannerRefactored.swift** created
- Clean implementation with honest contract
- Single entry point: `plan(intent, context) -> Command`
- All 9 dependencies required (no optionals)
- Implements Planner protocol correctly

✅ **PlannerDependencies.swift** factory created
- `RuntimeBootstrap.makePlannerDependencies()` method
- Container struct for all dependencies
- Ready to integrate

✅ **Strategy Clarified** (Phase 5.3)
- Original MainPlanner tightly coupled (300+ lines)
- Better approach: use clean MainPlannerRefactored
- Document deprecation and migration path
- Saves 2+ hours of complex refactoring

---

## Phases 5.4-5.6 (1-2 hours remaining)

### Phase 5.4: Testing (45 min)
**File**: `Tests/OracleOSTests/Planning/PlannerContractTests.swift` (NEW)

**Create 15+ tests**:
```swift
// Input validation
testPlanReturnsCommand()
testValidIntentAndContext()

// Output validation  
testUIIntentReturnsUICommand()
testCodeIntentReturnsCodeCommand()
testSystemIntentReturnsUICommand()

// Determinism
testSameIntentProducesSameCommand()
testNoMutableStatePollution()
testConcurrentPlansIndependent()

// Integration
testMemoryCandidatesAvailable()
testMemoryInfluenceAffectsDecision()

// Error handling
testMissingContextThrows()
testInvalidIntentThrows()
testCommandHasProperMetadata()

// Edge cases (2+ additional)
```

**Test Factory**:
```swift
class PlannerTestFactory {
    func makePlanner() -> Planner {
        let deps = RuntimeBootstrap.makePlannerDependencies(...)
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
```

### Phase 5.5: Integration (15 min)
**File**: `Sources/OracleOS/Runtime/RuntimeBootstrap.swift`

**Update makeContainer()**:
```swift
// OLD:
let planner = MainPlanner(repositoryIndexer, impactAnalyzer)

// NEW:
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

**File**: `Sources/OracleOS/Planning/MainPlanner+Planner.swift`
```swift
// Change from MainPlanner to MainPlannerRefactored
extension MainPlannerRefactored: Planner {
    // public func plan(intent: Intent, context: PlannerContext) -> Command
    // Already implemented in MainPlannerRefactored
}
```

### Phase 5.6: Documentation (15 min)
**Create**: `docs/PLANNER_CONTRACT.md`
```markdown
# Planner Contract

## Interface
```swift
public protocol Planner: Sendable {
    func plan(intent: Intent, context: PlannerContext) async throws -> Command
}
```

## What the Planner Does
1. Takes intent (what user wants) + context (current state)
2. Routes to domain-specific logic (UI/Code/System)
3. Selects action based on intent metadata
4. Returns typed Command ready for execution

## Honest Contract Features
- Deterministic (same input → same output)
- Stateless (no mutable fields)
- Injected (all dependencies provided)
- Type-safe (no [String: Any])
```

**Update**: `Sources/OracleOS/Planning/Planner.swift`
- Add contract documentation
- Explain honest interface
- Link to PLANNER_CONTRACT.md

---

## Quick Execution Checklist

```
Phase 5.4: Create PlannerContractTests.swift
☐ Create Tests/OracleOSTests/Planning/PlannerContractTests.swift
☐ Create PlannerTestFactory
☐ Add 15+ test methods (use examples above)
☐ Run: swift test --filter PlannerContractTests
☐ Verify all pass

Phase 5.5: Wire MainPlannerRefactored into bootstrap
☐ Update RuntimeBootstrap.makeContainer()
☐ Update MainPlanner+Planner.swift
☐ Build and verify no errors
☐ Run tests to verify no regressions

Phase 5.6: Document honest contract
☐ Create docs/PLANNER_CONTRACT.md
☐ Update Sources/OracleOS/Planning/Planner.swift
☐ Update Sources/OracleOS/Planning/MainPlanner.swift
☐ Build clean
☐ All tests pass

Final Commits:
☐ Phase 5.4: Planner Contract Tests
☐ Phase 5.5: Wire MainPlannerRefactored (Integration)
☐ Phase 5.6: Document Honest Planner Contract
☐ Phase 5 Complete: Planner Surface Collapse
```

---

## Expected Outcomes

**After Phase 5.6**:
- ✅ Planner has honest contract
- ✅ 15+ tests verify behavior
- ✅ MainPlannerRefactored integrated into runtime
- ✅ Documentation complete
- ✅ 70% overall progress (5.6/8 phases)

---

## Key Files References

### Created This Session
- `MainPlannerRefactored.swift` (clean implementation)
- `PlannerDependencies.swift` (factory)
- `PHASE_5_IMPLEMENTATION_GUIDE.md` (detailed guide)
- `PHASE_5_3_STRATEGY_CLARIFICATION.md` (strategy)
- `SESSION_5_FINAL_SUMMARY.md` (completion summary)

### To Modify (5.4-5.6)
- Tests/OracleOSTests/Planning/PlannerContractTests.swift (NEW)
- Sources/OracleOS/Runtime/RuntimeBootstrap.swift (integration)
- Sources/OracleOS/Planning/MainPlanner+Planner.swift (extension)
- Sources/OracleOS/Planning/Planner.swift (documentation)
- docs/PLANNER_CONTRACT.md (NEW)

---

## Time Estimate

- Phase 5.4: 45 minutes (test creation)
- Phase 5.5: 15 minutes (integration)
- Phase 5.6: 15 minutes (documentation)
- Verification: 15 minutes
- **Total**: 1.5-2 hours

---

## Why This Works

**Problem Avoided**: Refactoring 300+ lines of tightly coupled original MainPlanner
**Solution Applied**: Using clean MainPlannerRefactored that's already proper

**Honest Contract Achieved**:
- Protocol matches implementation
- All dependencies explicit
- No mutable state
- Type-safe throughout

**Path to 70%**: Complete, clear, low-risk

---

## Git Commands

```bash
# Start
cd /Users/dawsonblock/Downloads/Oracle-OS-main-X1
git status  # Should be clean
git log --oneline | head -1  # Should show b80668f

# After 5.4
git add Tests/OracleOSTests/Planning/PlannerContractTests.swift
git commit -m "Phase 5.4: Planner Contract Tests (15+ tests)"

# After 5.5
git add Sources/OracleOS/Runtime/RuntimeBootstrap.swift Sources/OracleOS/Planning/MainPlanner+Planner.swift
git commit -m "Phase 5.5: Wire MainPlannerRefactored (Integration)"

# After 5.6
git add docs/PLANNER_CONTRACT.md Sources/OracleOS/Planning/Planner.swift
git commit -m "Phase 5.6: Document Honest Planner Contract"

# Final
git commit --allow-empty -m "Phase 5 Complete: Planner Surface Collapse"
```

---

## Success Markers

✅ PlannerContractTests created and passing
✅ MainPlannerRefactored integrated into bootstrap
✅ PLANNER_CONTRACT.md documentation complete
✅ Build passes cleanly
✅ All tests pass
✅ No warnings or errors

---

## Ready to Execute

All prerequisites met:
- Code structure ready (MainPlannerRefactored)
- Test framework defined
- Integration path clear
- Documentation templates provided

**Estimated completion**: 70% of refactor (5.6/8 phases)
**Confidence**: High (clean path, no risky surgery)
**Next session**: Phases 6-8 (remaining 30%)

Begin with Phase 5.4: Create PlannerContractTests.swift
