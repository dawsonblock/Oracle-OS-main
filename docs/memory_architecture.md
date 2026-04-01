# Oracle OS — Memory Architecture (Phase 4)

## Memory Authority Model

Oracle OS has three tiers of memory, with clear authority boundaries:

### Tier 1: Committed Runtime State (AUTHORITATIVE)
- **Owner**: `CommitCoordinator` + `EventStore` + Reducers
- **Truth**: Domain events are the only source of truth
- **Mutation**: Only via `EventReducer.apply()`
- **Durability**: Persisted in append-only JSONL event store
- **Replay**: Complete state derivable from replaying all events

Examples:
- World state (observation, active task, last action)
- Task graph (execution history, recovery branches)
- Evaluation verdicts (success/failure classification)

### Tier 2: Derived Projections (NON-AUTHORITATIVE, REPLAYABLE)
- **Owner**: Memory projections
- **Truth**: Rebuilt from committed events
- **Mutation**: Only via typed projections consuming domain events
- **Durability**: May be rebuilt or discarded; not stored
- **Replay**: Same event stream → same projection state

Examples:
- StrategyMemory (control success tracking, failure patterns)
- ExecutionMemory (ranking bias, recovery strategy success)
- PatternMemory (command success rates, preferred fix paths)

### Tier 3: Support Persistence (AUXILIARY, NOT AUTHORITATIVE)
- **Owner**: Individual support systems
- **Truth**: Local storage; not authoritative for runtime
- **Mutation**: Direct file writes outside event stream
- **Durability**: May be stale; not critical to recovery
- **Replay**: Not needed; rebuilt from source on demand

Examples:
- Approval audit logs
- Metrics and telemetry
- Diagnostics and traces
- Build/test artifacts

## The Problem (Pre-Phase 4)

Before this phase, memory was updated via **out-of-band side effects**:

```
Event → MemoryEventIngestor (background task)
      ↓
      → recordControl() / recordFailure() / recordCommandResult()
      ↓
      → Direct mutation of StrategyMemory / ExecutionMemory
```

This violated the principle that **derived state should be deterministic and replayable**:
- ❌ Not triggered by explicit domain events
- ❌ Race conditions possible (ingestor vs other mutations)
- ❌ Can't replay from committed history
- ❌ Recovery not guaranteed to rebuild same state

## The Solution (Phase 4+)

Replace out-of-band mutation with **formal typed projections**:

```
Committed Events (EventStore)
  ↓
  → StrategyMemoryProjection.apply(events)
    ↓ [deterministic, idempotent]
    ↓ [rebuilds same state every time]
    → StrategyMemory updated
  
  → ExecutionMemoryProjection.apply(events)
    ↓
    → ExecutionMemory updated
  
  → PatternMemoryProjection.apply(events)
    ↓
    → PatternMemory updated
```

**Key properties**:
- **Explicit**: Events trigger memory updates via named projections
- **Deterministic**: Same events → same memory state
- **Idempotent**: apply twice = apply once
- **Replayable**: Rebuild from event history
- **Testable**: Memory state after replay matches live state

## Migration (Phase 4 Work)

### Before
```swift
// Old: Direct mutation
appMemory.recordCommandResult(category, workspaceRoot, success)
appMemory.recordControl(control)
appMemory.recordFailure(failure)
```

### After
```swift
// New: Projection consumes domain events
let projection = StrategyMemoryProjection(appMemory: appMemory)
try projection.apply(events: committedEvents)
```

### Where Memory Updates Happen Now

1. **After ExecutionOutcome**: Events are produced
2. **After CommitCoordinator.commit()**: Events are persisted
3. **Projections consume**: Memory is rebuilt from events
4. **Result**: StrategyMemory reflects latest committed state

## Workspace Root Issue (Phase 4 Subtask)

**Problem**: `MemoryEventIngestor` used `FileManager.default.currentDirectoryPath` to record workspace root.

This is **non-deterministic** and **non-portable**:
- Different processes have different working directories
- Workspace root should come from committed intent/command metadata
- cwd is ambiguous and unreliable

**Solution**: Workspace root comes from:
1. Command payload (primary)
2. Intent metadata (secondary)
3. RuntimeConfiguration (fallback)
4. Never from ambient process cwd

## Testing Memory Projections

Every projection must satisfy:

1. **Idempotent test**
   ```swift
   let memory1 = ProjectionTest.applyOnce(events)
   let memory2 = ProjectionTest.applyTwice(events)
   assert(memory1 == memory2)
   ```

2. **Replay test**
   ```swift
   let live = ProjectionTest.applyLive(events)
   let replayed = ProjectionTest.applyFromHistory(allEvents)
   assert(live == replayed)
   ```

3. **Event subset test**
   ```swift
   let fullMemory = ProjectionTest.apply(allEvents)
   let subsetMemory = ProjectionTest.apply(events.filter { ... })
   assert(subsetMemory is compatible with subset)
   ```

## Files Changed in Phase 4

- **Created**: `Sources/OracleOS/Memory/Projections/MemoryProjections.swift`
- **Created**: `docs/memory_architecture.md` (this file)
- **Modified**: `docs/deprecation_map.md` (MemoryEventIngestor → projections)
- **Modified**: `REFACTOR_STATUS.md` (Phase 4 notes)

## What Remains

### Phase 4 continued
- [ ] Wire projections into RuntimeBootstrap
- [ ] Remove MemoryEventIngestor or mark as deprecated
- [ ] Add workspace root to command/intent metadata
- [ ] Add memory replay tests

### Phase 5+
- Further specialization of projection concerns
- Memory rebuild on startup
- Memory persistence (optional)

## Reference

See [docs/runtime_spine.md](docs/runtime_spine.md) for the execution path.
See [docs/event_model.md](docs/event_model.md) for domain event specification.
