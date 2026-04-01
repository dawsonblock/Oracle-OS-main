# Oracle OS — Support Persistence Tiers (Phase 6)

## Three-Tier Persistence Model

Oracle OS commits state through three distinct tiers. Each has different authority, durability, and recovery guarantees.

### Tier 1: Committed Runtime State (AUTHORITATIVE)

**Owner**: `CommitCoordinator` + `EventStore` + Reducers  
**Truth**: Domain events are the only source of truth  
**Mutation**: Only via `EventReducer.apply(events)`  
**Durability**: Append-only JSONL, durable, WAL-protected  
**Recovery**: Complete state derivable from event replay  
**Use for**:
- World state (observation, task, active command)
- Task graph (execution branches, recovery paths)
- Evaluation verdicts (critic outcomes)

**Example**:
```swift
// Tier 1: Committed
.commandExecuted(CommandExecutedEvent(...))
  → committed to EventStore
  → applied by RuntimeStateReducer
  → reflected in WorldStateModel.snapshot
```

### Tier 2: Derived Projections (REPLAYABLE, NON-AUTHORITATIVE)

**Owner**: Memory projections + indexing  
**Truth**: Rebuilt from committed events  
**Mutation**: Only via `MemoryProjection.apply(events)`  
**Durability**: May be rebuilt or discarded  
**Recovery**: Rebuilt from event history on startup  
**Use for**:
- StrategyMemory (control ranking, failure patterns)
- ExecutionMemory (recovery strategy success)
- PatternMemory (command success rates)
- Index views (repository index, search cache)

**Example**:
```swift
// Tier 2: Derived projection
.commandExecuted(CommandExecutedEvent(...))
  → committed to EventStore (Tier 1)
  → StrategyMemoryProjection.apply(events)
  → StrategyMemory updated (local cache, rebuilt on startup)
  → Memory influences planning but doesn't persist independently
```

### Tier 3: Support Persistence (AUXILIARY, OPTIONAL)

**Owner**: Individual support systems  
**Truth**: Local storage, not authoritative  
**Mutation**: Direct file writes outside event stream  
**Durability**: May be stale or incomplete  
**Recovery**: Not needed; rebuilt from source or recreated  
**Use for**:
- Approval audit logs
- Metrics and telemetry  
- Diagnostics and traces
- Build/test artifacts
- Workspace metadata

**Example**:
```swift
// Tier 3: Support persistence
MetricsRecorder.recordActionSuccess(action, duration: 0.5)
  → appends to metrics file directly
  → NOT part of committed state
  → may be lost or stale
  → not used for recovery or replay
```

## Where Each Tier is Used

### Tier 1 (Committed)
- `Sources/OracleOS/Events/` — Event storage and WAL
- `Sources/OracleOS/State/` — Reducers and world model
- `Sources/OracleOS/Runtime/CommitCoordinator`

### Tier 2 (Derived)
- `Sources/OracleOS/Memory/Projections/` — Memory projections
- `Sources/OracleOS/Learning/StrategyMemory` — App memory
- `Sources/OracleOS/Code/Intelligence/RepositoryIndexer` — Code index
- `Sources/OracleOS/WorldModel/Graph/` — Planning graph (rebuilt from events)

### Tier 3 (Support)
- `Sources/OracleOS/Intent/Policies/ApprovalStore.swift`
- `Sources/OracleOS/Common/Diagnostics/MetricsRecorder.swift`
- `Sources/OracleOS/Learning/Trace/FailureArtifactWriter.swift`
- `Sources/OracleOS/Common/Diagnostics/StrategyDiagnostics.swift`
- `Sources/OracleOS/Learning/Project/ProjectMemoryStore.swift` (except .oracle-os/ markdown)
- `Sources/OracleOS/Planning/Workflows/WorkflowIndex.swift`

## Misclassified Persistence (Pre-Phase 6)

The original docs claimed:
> VerifiedExecutor is the only layer allowed to produce side effects.

This was **overclaimed**. More precisely:

- ✅ **Runtime action side effects** route through VerifiedExecutor (Tier 1/Tier 2)
- ✅ **Support persistence** writes directly to disk outside VerifiedExecutor (Tier 3)
- ✅ This is correct and necessary

**The fix**: Docs now distinguish the three tiers clearly.

## Phase 6 Changes

### Documentation
- [ ] Created this file
- [ ] Updated ARCHITECTURE.md to use tier language
- [ ] Updated deprecation_map.md to place support systems in Tier 3

### Code (Optional)
- [ ] Could reorganize directories by tier (optional, aesthetic)
- [ ] Could add @tier1, @tier2, @tier3 documentation markers (optional)
- [ ] Currently: tier classification is clear in docs, directories can stay as-is

### Testing
- [ ] Tier 1 tests: verify committed state is reducers-only
- [ ] Tier 2 tests: verify projections are idempotent and replayable
- [ ] Tier 3 tests: verify support persistence is isolated from critical path

## Summary

By clarifying persistence tiers, the refactor eliminates ambiguity:

- ✅ Newcomers understand which persistence is authoritative
- ✅ Architects know where to store new state (which tier)
- ✅ Reviewers can verify persistence choices against the model
- ✅ Recovery logic is clearly separated (Tier 1 only)

The code doesn't change much. The **clarity** changes everything.
