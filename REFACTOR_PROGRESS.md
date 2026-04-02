# Full Refactor — Phases 0-2 Complete

## Summary

Three critical phases complete. Authority is singular. Execution boundary is hard.

## Phases Completed

### Phase 0: Truth Cleanup ✅
- Archived stale status documents (15 files)
- Created truthful STATUS.md
- Added CI root-level script guard
- Quarantined stale diagnostics

**Result**: One truth. No competing claims.

### Phase 1: Authority Collapse ✅
- RuntimeContext shrunk (removed policyEngine, workspaceRunner, repositoryIndexer)
- ControllerRuntimeBridge stopped storing RuntimeContext pseudo-authority
- All remaining RuntimeContext references cleaned
- RuntimeBootstrap documentation strengthened

**Result**: Single authoritative service graph (RuntimeContainer).

### Phase 2: Execution-Boundary Hardening ✅
- All Process() usage inventoried and classified
- Tooling-only execution marked with TOOLING_ONLY_DIRECT_PROCESS annotation
- CI execution boundary guard created and integrated
- Governance tests rewritten from narrative to real enforcement

**Result**: Execution boundary is hard. No hidden process escapes.

## Architecture State

```
    Canonical Runtime Path (Enforced)
    ┌─────────────────────────────────────────────┐
    │  Surface                                    │
    │  (MCP/Controller/CLI)                       │
    └──────────────────┬──────────────────────────┘
                       │
    ┌──────────────────▼──────────────────────────┐
    │  RuntimeBootstrap.makeBootstrappedRuntime() │  ← ONLY entry point
    └──────────────────┬──────────────────────────┘
                       │
    ┌──────────────────▼──────────────────────────┐
    │  RuntimeContainer                           │  ← SINGLE authority
    │  (all shared services)                      │
    └──────────────────┬──────────────────────────┘
                       │
    ┌──────────────────▼──────────────────────────┐
    │  RuntimeOrchestrator.submitIntent()         │  ← Intent routing
    └──────────────────┬──────────────────────────┘
                       │
    ┌──────────────────▼──────────────────────────┐
    │  Policy → Planner → VerifiedExecutor        │  ← Verified path
    └──────────────────┬──────────────────────────┘
                       │
    ┌──────────────────▼──────────────────────────┐
    │  CommandRouter → DomainRouter               │  ← Typed routing
    └──────────────────┬──────────────────────────┘
                       │
    ┌──────────────────▼──────────────────────────┐
    │  DefaultProcessAdapter                      │  ← ONLY Process() gate
    │  (or other execution adapters)              │
    └──────────────────┬──────────────────────────┘
                       │
    ┌──────────────────▼──────────────────────────┐
    │  CommitCoordinator.commit(events)           │  ← State mutation
    └──────────────────┬──────────────────────────┘
                       │
    ┌──────────────────▼──────────────────────────┐
    │  EventStore (append-only JSONL)             │  ← Truth source
    └─────────────────────────────────────────────┘
```

## Enforcement Mechanisms

### 1. Compile-Time Guards
- `@available(*, unavailable)` on forbidden RuntimeContext properties
- Forces compilation errors if architecture is violated

### 2. Source Code Scans (CI)
- `scripts/execution_boundary_guard.py` checks for forbidden Process()
- `scripts/architecture_guard.py` checks for forbidden references
- Run on every push/PR

### 3. Test Enforcement
- ExecutionBoundaryEnforcementTests scan source for violations
- Tests verify RuntimeBootstrap usage in all surfaces
- Tests fail on authority leaks
- Tests fail on incomplete enum handling

### 4. Runtime Contracts
- Documentation in RuntimeBootstrap explicitly forbids repackaging
- All service access must go through bootstrappedRuntime.container
- No convenience service bags allowed

## Metrics

| Metric | Status |
|--------|--------|
| Authority (singleton) | Singular — RuntimeContainer |
| Execution routing | Unified — VerifiedExecutor → CommandRouter |
| Process spawning | Isolated — DefaultProcessAdapter only |
| State mutation | Centralized — CommitCoordinator → EventStore |
| CI enforcement | Active — 2 guard scripts + governance tests |
| Documentation alignment | Current — STATUS.md reflects reality |
| Compilation guards | In place — prevents re-introduction of leaks |

## Commits

```
Phase 0: dd3ba61 Truth cleanup
Phase 1: 2a5fac5 RuntimeContext shrunk
         aa07aae ControllerRuntimeBridge fixed
         d8fbfb2 RuntimeContext leaks swept
         a90cb77 Bootstrap documented
Phase 2: 3a26fca Process() inventory + tooling isolation
         89317a7 Execution boundary CI guard
         9200f95 Governance tests rewritten
         f698d15 Phase 2 complete summary
```

## Ready for Phase 3

### Phase 3: MCP Decomposition and Transport Sealing

Will systematically:
1. Use MCPBoundary.swift as only transport anchor
2. Split MCPDispatch into separate responsibility files
3. Replace dictionary transport with JSONValue/typed structures
4. Build under strict Swift 6 concurrency checks

**Readiness**: High. Authority is clean. Execution boundary is hard. Foundation is solid.

---

**Overall Status**: Phases 0-2 complete. Authority is singular. Execution is bounded. Ready for transport hardening in Phase 3.

