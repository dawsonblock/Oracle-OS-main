# Session 5 Handoff: Phase 5 - Planner Surface Collapse

## Current Status

**Commit**: `40a4369` (Final Progress Report)
**Progress**: 4.6/8 phases (57.5%)
**Phase 5 Status**: Analysis complete, ready for implementation

---

## What Phase 5 Does

**Objective**: Collapse planner surface abstractions to establish an honest contract

**Problem**: The planner has two interfaces:
1. **Planner protocol**: `plan(intent, context) -> Command`
2. **MainPlanner implementation**: Complex internal (task graph, reasoning, etc.)
3. **Adapter**: Just naive routing, doesn't use MainPlanner functionality

**Solution**: Single honest entry point that uses full planner capabilities

---

## Phase 5 Roadmap (5.2-5.6)

### Phase 5.2: Dependency Injection
**Files**: RuntimeBootstrap.swift
**Work**:
1. Create all MainPlanner dependencies in RuntimeBootstrap
2. Pass explicitly to MainPlanner constructor
3. Remove 7 optional parameters
4. Remove constructor's internal dependency creation

**Example**:
```swift
// Before: let mainPlanner = MainPlanner(indexer, analyzer) with 7 optional params
// After: all deps created in bootstrap, passed explicitly
```

### Phase 5.3: Remove Mutable State
**Files**: MainPlanner.swift
**Work**:
1. Delete `private var currentGoal: Goal?` field
2. Delete `setGoal(_ goal: Goal)` method
3. Pass goal through Intent or new parameter
4. Update all methods that used currentGoal

**Tests**: Verify no state pollution (determinism)

### Phase 5.4: Consolidate Interfaces
**Files**: MainPlanner.swift, MainPlanner+Planner.swift
**Work**:
1. Remove unused public methods:
   - `plan(goal: String)` - unused
   - `interpretGoal(_ description: String)` - unused
   - `goalReached(state: PlanningState)` - unused
2. Keep only: `plan(intent: Intent, context: PlannerContext) -> Command`
3. Expand `plan()` to call internal `nextStep()` (use task graph)
4. Make internal methods fully private

**Result**: Single public entry point with full capabilities

### Phase 5.5: Testing
**Files**: Tests/OracleOSTests/Planning/PlannerContractTests.swift (new)
**Tests** (15+ cases):

```swift
// Input Validation
testValidIntentAndContext()
testMissingContextFields()
testNullWorldState()

// Output Validation
testReturnsCommand()
testCommandHasProperMetadata()
testCommandPayloadMatchesIntentDomain()

// Domain Routing
testUIIntentReturnsUICommand()
testCodeIntentReturnsCodeCommand()
testSystemIntentReturnsUICommand()

// Determinism
testSameIntentProducesSameCommand()
testNoMutableStatePollution()
testConcurrentPlansIndependent()

// Memory Integration
testPlannertReceivesMemoryCandidates()
testMemoryInfluenceAffectsDecision()
testMemoryBiasInPathScoring()

// Task Graph Integration
testPlannert UsesTaskGraphNavigation()
testPlannert ConsidersViableEdges()
testPlannert ScoresPathsWithMemory()

// Error Handling
testInvalidIntentThrows()
testMissingContextThrows()
testNoTaskGraphGracefulFallback()
```

### Phase 5.6: Documentation
**Files**: Planner.swift, MainPlanner.swift, PLANNER_CONTRACT.md (new)
**Work**:
1. Update Planner protocol documentation
2. Document MainPlanner contract
3. Remove misleading comments about mutable state
4. Add usage examples

---

## Files to Modify

### Primary
1. **RuntimeBootstrap.swift** (Phase 5.2)
   - Create all MainPlanner dependencies
   - Pass to MainPlanner constructor

2. **MainPlanner.swift** (Phases 5.3, 5.4)
   - Remove currentGoal field
   - Remove setGoal(), interpretGoal(), goalReached(), plan(goal:)
   - Expand plan(intent, context) implementation
   - Make private methods fully private

3. **MainPlanner+Planner.swift** (Phase 5.4)
   - Expand plan(intent, context) to use nextStep()
   - Call task graph navigation
   - Return Command from PlannerDecision

4. **Planner.swift** (Phase 5.6)
   - Update documentation
   - Clarify contract semantics

### Secondary
5. **PlannerContractTests.swift** (Phase 5.5, NEW FILE)
6. **PLANNER_CONTRACT.md** (Phase 5.6, NEW FILE)

---

## Key Changes Summary

### Before (Broken)
```
MainPlanner
├─ public func plan(intent, context) -> Command  ← Naive routing only
├─ public func setGoal(goal)                      ← Mutable state
├─ public func nextStep(...) -> PlannerDecision?  ← Rich functionality (unreachable!)
├─ public func nextAction(...) -> ActionContract? ← Wrapper
├─ init(..., 7 optional params)                   ← Weak injection
└─ private var currentGoal: Goal?                 ← Violates immutability
```

### After (Honest)
```
MainPlanner
├─ public func plan(intent, context) -> Command  ← Full capabilities
│  └─ Uses: task graph, memory, graph store, reasoning
├─ init(all dependencies: explicit)              ← Strong injection
└─ private only for internal methods
   ├─ nextStep() (internal)
   ├─ familyPlannerDecision() (internal)
   └─ taskGraphNavigatedDecision() (internal)
```

---

## Risk Assessment

### Low Risk ✅
- Removing unused public methods (no callers)
- Moving goal to parameter (runtime only)
- Dependency injection (bootstrap-level change)

### Medium Risk (Mitigated by Tests)
- Changing plan() implementation
- Ensure task graph logic still works
- Verify memory influence applied correctly

### High Risk ❌
- None identified

**Mitigation**: 15+ PlannerContractTests verify all behavior

---

## Testing Strategy

### Test Categories

**1. Contract Validation** (3 tests)
- Input acceptance
- Output type correctness
- Error conditions

**2. Routing** (3 tests)
- UI intent → UI command
- Code intent → Code command
- System intent → proper command

**3. Determinism** (3 tests)
- Same input → same output
- No state pollution
- Concurrent independence

**4. Integration** (3 tests)
- Memory candidates available
- Memory bias affects scoring
- Graph navigation used

**5. Fallback** (3 tests)
- Missing task graph → graceful
- No viable paths → fallback
- Error handling

---

## Success Criteria

✅ Single public entry point: `plan(intent, context) -> Command`
✅ No mutable state (currentGoal deleted)
✅ All dependencies injected by bootstrap
✅ Unused methods removed
✅ 15+ PlannerContractTests pass
✅ E2E tests show no state pollution
✅ Documentation reflects honest contract

---

## Estimated Effort

- **5.2 Dependency Injection**: 45 minutes
- **5.3 Remove Mutable State**: 30 minutes
- **5.4 Consolidate Interfaces**: 30 minutes
- **5.5 Testing**: 45 minutes
- **5.6 Documentation**: 15 minutes

**Total**: 2.5-3 hours

---

## Quick Start for Session 5

```bash
# Verify current state
cd /Users/dawsonblock/Downloads/Oracle-OS-main-X1
git status  # Should be clean
git log --oneline | head -3

# Review analysis
cat PHASE_5_ANALYSIS.md

# Start with Phase 5.2
# 1. Open RuntimeBootstrap.swift
# 2. Create factory method for MainPlanner dependencies
# 3. Update MainPlanner constructor signature
# 4. Update initialization in makeContainer()
```

---

## Phase 5 Branch Points

If you need to pause mid-phase:

- After 5.2: Dependency injection done, can build and test
- After 5.3: Mutable state removed, can build and test
- After 5.4: Interface consolidated, ready for tests
- After 5.5: Tests pass, ready for documentation
- After 5.6: Documentation complete, phase done

Each step is independent and testable.

---

## Git Commits Expected (Session 5)

```
Phase 5.2: RuntimeBootstrap Dependency Injection
Phase 5.3: Remove Planner Mutable State
Phase 5.4: Consolidate Planner Interfaces
Phase 5.5: Add Planner Contract Tests (15+)
Phase 5.6: Document Honest Planner Contract
Phase 5 Complete: Planner Surface Collapse
```

---

## Files Baseline (Reference)

### Key Files for Phase 5
- `Sources/OracleOS/Planning/MainPlanner.swift` (400+ lines)
- `Sources/OracleOS/Planning/MainPlanner+Planner.swift` (180+ lines)
- `Sources/OracleOS/Planning/Planner.swift` (30 lines)
- `Sources/OracleOS/Runtime/RuntimeBootstrap.swift` (200+ lines)

### Test Baseline
- New file: `Tests/OracleOSTests/Planning/PlannerContractTests.swift`
- New file: `docs/PLANNER_CONTRACT.md`

---

## Notes for Implementation

1. **Task Graph Integration**: expand `plan()` to call `nextStep()` which uses task graph
2. **Memory Influence**: ensure MemoryRouter is called for bias calculation
3. **Graph Scorer**: verify paths are scored with memory influence
4. **Fallback Logic**: keep fallback to family planners if no task graph path
5. **Command Conversion**: convert PlannerDecision → Command properly

---

## Success Definition for Phase 5

After completion:
- ✅ Single honest interface: `plan(intent, context) -> Command`
- ✅ No mutable state or weak injection
- ✅ All functionality reachable and tested
- ✅ RuntimeOrchestrator gets full planner capabilities
- ✅ Zero state pollution across calls
- ✅ Documentation reflects reality

**Result**: Planner surface honest and maintainable.

---

## What's Next After Phase 5?

**Phase 6**: Seal sidecar contracts (version interfaces)
**Phase 7**: Internal restructuring (dependency cleanup)
**Phase 8**: CI proof hardening (control-loop tests)

But Phase 5 must complete first.

---

## Contact Points

If you get stuck:
1. Check PHASE_5_ANALYSIS.md for detailed breakdown
2. Review commits ba88fb0 (Phase 5 analysis) for context
3. Look at similar refactors in earlier phases for patterns
4. Tests are the specification (run them to understand requirements)

---

## Session 5 Ready ✅

All prerequisites met:
- Analysis complete
- Roadmap documented
- Test plan outlined
- Low risk identified
- Success criteria clear

Begin with Phase 5.2: RuntimeBootstrap dependency injection.
