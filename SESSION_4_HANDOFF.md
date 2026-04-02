# Session 4 Handoff: Phase 4.5, 4.6 & Phase 5 Preview

## Current State

**Commit**: `58ec8a9` (Session 3 Summary)
**Progress**: 4.4/8 phases complete (55%)
**Build Status**: ✅ Compiles, guard passes, tests created

## Immediate Next: Phase 4.5 (Integration)

### Task: Integrate MemoryEventIngestorRefactored into RuntimeContainer

**Files to Modify**:
1. `Sources/OracleOS/Runtime/RuntimeContainer.swift`
   - Inject projection instances into RuntimeContainer
   - Store refactored ingestor alongside original

2. `Sources/OracleOS/Runtime/RuntimeBootstrap.swift`
   - Create projections during bootstrap
   - Initialize refactored ingestor with projections

3. `Sources/OracleOS/Runtime/RuntimeOrchestrator.swift` (likely)
   - Check if any event handling needs updates
   - Ensure events are routed to new ingestor

**Approach**:
```swift
// In RuntimeContainer
private let memoryIngestor: MemoryEventIngestor
private let memoryProjections: [String: MemoryProjection]

// In RuntimeBootstrap.makeBootstrappedRuntime()
let memoryIngestor = MemoryEventIngestor(
    repositoryIndexer: repositoryIndexer,
    memoryStore: memoryStore
)
```

**Verification**:
- All tests still pass
- Guard scripts still pass
- No new warnings

**Commit Message**:
```
Phase 4.5: Integrate Memory Projections into RuntimeContainer

- Inject MemoryEventIngestorRefactored into RuntimeContainer
- Create projection instances during RuntimeBootstrap
- Route domain events through new projection pattern
- Verify all 100+ memory + MCP tests pass
- Update event handling path to use projections
```

---

## Phase 4.6: Memory Replay Tests

### Task: Verify Projections are Replay-Safe

**New Test File**: `Tests/OracleOSTests/Memory/MemoryProjectionReplayTests.swift`

**Tests to Add**:
1. **Single Event Replay**
   - Emit event → verify projection creates record
   - Replay same event → verify idempotent

2. **Event Sequence Replay**
   - Emit 10 events in order → verify final state
   - Replay 10 events → verify same final state

3. **Batch Projection**
   - Project 100 events
   - Verify effects sorted by priority

4. **Projection State Reconstruction**
   - Start with empty memory
   - Replay event log from persistent store
   - Verify memory state matches original

5. **Concurrent Replay Safety**
   - Multiple replay tasks in parallel
   - Verify no data corruption
   - (Tests @MainActor/Sendable guarantees)

**Example Test**:
```swift
func testEventReplayIdempotence() {
    let projection = StrategyMemoryProjection(store: store)
    
    let (record1, effects1) = projection.projectControl(...)
    let (record2, effects2) = projection.projectControl(...)
    
    XCTAssertEqual(record1.key, record2.key)
    XCTAssertEqual(effects1.count, effects2.count)
}
```

**Commit Message**:
```
Phase 4.6: Memory Projection Replay Tests

- Add MemoryProjectionReplayTests.swift (10+ tests)
- Verify projection idempotence
- Test event sequence replay
- Test concurrent replay safety
- Verify effects are deterministic
- Ready for event sourcing implementation
```

---

## Phase 5 Preview: Planner Surface Collapse

### Objective
Remove intermediate abstractions between RuntimeOrchestrator and MainPlanner.
Establish honest contract: what planner takes, what it returns.

### Current State
- RuntimeOrchestrator calls planner.plan(intent, context)
- Planner may have intermediate wrapper layers
- Contract not fully visible

### Deliverables
1. **Planner Contract Document**
   - Input types (Intent + PlannerContext)
   - Output types (Command)
   - Error conditions
   - Execution timeline

2. **Remove Wrapper Layers**
   - Identify intermediate abstractions
   - Move logic to MainPlanner or RuntimeOrchestrator
   - Flatten call hierarchy

3. **Tighten Type Safety**
   - Replace [String: Any] in planner context if present
   - Ensure all outputs are Sendable
   - Add compile-time guards

4. **Tests**
   - PlannerContractTests (input/output validation)
   - MainPlannerDirectIntegrationTests
   - E2E RuntimeOrchestrator → MainPlanner tests

### Files Likely to Review
- `Sources/OracleOS/Planning/MainPlanner.swift`
- `Sources/OracleOS/Planning/Memory/PlannerContext.swift` (check for [String: Any])
- `Sources/OracleOS/Runtime/RuntimeOrchestrator.swift` (planner call site)
- `Sources/OracleOS/Runtime/RuntimeBootstrap.swift` (planner creation)

### Key Questions
1. What does MainPlanner actually need from PlannerContext?
2. Are there unused context fields?
3. Can any context fields be optional/derived?
4. Is the Command output complete or does it get post-processed?

---

## Accumulated Technical Debt

### Not in Scope (Post-Phase 8)
- Remove old MemoryEventIngestor if not used elsewhere
- Migrate all event handlers to projection pattern
- Full event sourcing implementation
- Memory tier consolidation (strategy/execution/pattern → single tier)

### In Scope (Current)
- Phase 4.5: Integration (straightforward)
- Phase 4.6: Replay tests (straightforward)
- Phase 5: Planner surface (requires analysis)

---

## Git Reference

### All Phase 4 Commits
```bash
# Phase 4.1-4.4
git show be07014  # Memory Projections

# Phase 4.5 (to do)
# Phase 4.6 (to do)
```

### All Session 3 Work
```bash
git log --oneline | head -5
```

---

## Quick Start for Session 4

```bash
# Verify current state
cd /Users/dawsonblock/Downloads/Oracle-OS-main-X1
git status  # Should be clean
git log --oneline | head -3

# Run guards to verify baseline
python scripts/architecture_guard.py
python scripts/execution_boundary_guard.py
python scripts/mcp_boundary_guard.py

# Try a quick compile (may timeout, use Ctrl+C)
# swift build 2>&1 | head -50

# Review Phase 4 code
cat PHASE_4_PLAN.md
cat Sources/OracleOS/Memory/MemoryProjection.swift | head -50
cat Sources/OracleOS/Memory/MemoryEventIngestorRefactored.swift | head -50
```

---

## Success Criteria for Phase 4.5

- [ ] MemoryEventIngestorRefactored integrated into RuntimeContainer
- [ ] All 100+ tests pass (MCP + Memory)
- [ ] All 3 guard scripts pass
- [ ] No new compiler warnings
- [ ] Commit message explains integration pattern

## Success Criteria for Phase 4.6

- [ ] 10+ replay tests added
- [ ] Idempotence verified
- [ ] Concurrent replay safe
- [ ] Event sequence tests pass
- [ ] Commit message explains replay guarantees

## Success Criteria for Phase 5 (start)

- [ ] Planner contract document written
- [ ] All intermediate layers identified
- [ ] Type safety audit completed
- [ ] 15+ planner contract tests created

---

## Status

✅ **Session 3 Complete**
- Cluster 3.4: MCP Guard ✅
- Cluster 3.5: Concurrency Tests ✅
- Phase 4.1-4.4: Projections ✅

⏳ **Session 4 Ready**
- Phase 4.5: Integration (straightforward)
- Phase 4.6: Replay Tests (straightforward)
- Phase 5: Planner Surface (analysis required)

📊 **Overall**: 4.4/8 phases = 55% complete
