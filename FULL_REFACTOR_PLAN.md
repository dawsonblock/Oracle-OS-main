# Full Refactor Execution Plan — Progress Summary

## Completed

### Phase 0: Truth Cleanup and Baseline Capture ✅
- **Cluster 0.1**: Archived 15 stale status documents to docs/archive/status-history/
- **Cluster 0.2**: Moved stale diagnostics to docs/archive/diagnostics/, created README
- **Cluster 0.3**: Root scripts already moved to tools/quarantine/ in Session 2
- **Cluster 0.4**: Added CI guard against root-level executable sprawl

**Result**: One truthful STATUS.md. No competing completion claims. Clear baseline established.

### Phase 1: Authority Collapse — IN PROGRESS
- **Cluster 1.1**: ✅ Shrunk RuntimeContext by removing policyEngine, workspaceRunner, repositoryIndexer
  - Added compile-time guards (@available unavailable) to prevent re-introduction
  - This will expose all remaining authority leaks during build

## Next Immediate Tasks (In Order)

### Phase 1 Remaining Clusters

**Cluster 1.2 — Stop storing runtimeContext in ControllerRuntimeBridge**
- File: `Sources/OracleControllerHost/ControllerRuntimeBridge.swift`
- Remove: `let runtimeContext: RuntimeContext` property
- Replace all uses with `bootstrappedRuntime.container.service`
- Expected breakage: Multiple call sites will fail, revealing context dependency patterns

**Cluster 1.3 — Sweep repo for remaining RuntimeContext authority leaks**
- Search: `runtimeContext.` across all sources and tests
- Fix: Replace execution-adjacent access with container access
- Update: Any test creating RuntimeContext with execution adapters

**Cluster 1.4 — Strengthen bootstrap documentation**
- File: `Sources/OracleOS/Runtime/RuntimeBootstrap.swift`
- Update comments to make BootstrappedRuntime the sanctioned assembly bundle
- Clarify that nothing downstream should repackage the service graph

### Phase 2: Execution-Boundary Hardening

After Phase 1 completes:
- **Cluster 2.1**: Inventory direct Process() usage
- **Cluster 2.2**: Mark tooling-only execution isolated
- **Cluster 2.3**: Tighten process guard script
- **Cluster 2.4**: Rewrite weak governance tests
- **Cluster 2.5**: Fix ExecutionBoundaryTests

### Phase 3: MCP Decomposition and Transport Sealing

After Phase 2 completes:
- **Cluster 3.1**: Use MCPBoundary.swift as only transport anchor
- **Cluster 3.2**: Split MCPDispatch into responsibility-separated files
  - MCPRuntimeProvider (bootstrap access)
  - MCPToolRouter (request routing)
  - MCPDispatch (thin orchestration)
- **Cluster 3.3**: Remove dictionary transport from MCP runtime
- **Cluster 3.4**: Add MCP boundary test guard
- **Cluster 3.5**: Build strict concurrency after decomposition

## Critical Success Metrics

After each phase, verify:
- **Phase 0**: One truth document, no competing claims
- **Phase 1**: No code can access policyEngine/workspaceRunner/repositoryIndexer through RuntimeContext
- **Phase 2**: Zero ungoverned Process() in runtime path, tooling-only isolated
- **Phase 3**: MCP has one transport contract, zero [String: Any] at runtime boundary

## Expected Build Status

Currently building after Phase 1.1 changes. Expected to fail on:
- `runtimeContext.policyEngine` references in ControllerRuntimeBridge
- `runtimeContext.workspaceRunner` references elsewhere
- `runtimeContext.repositoryIndexer` references elsewhere
- Tests creating RuntimeContext with these forbidden services

These failures are **expected and correct**. They expose the real authority leaks that Cluster 1.2 and 1.3 will fix.

## Dependency Order Enforced

- ✅ Phase 0 must complete before Phase 1 (truth before authority changes)
- ⏳ Phase 1 must complete before Phase 2 (single authority before boundary enforcement)
- ⏳ Phase 2 must complete before Phase 3 (clean execution before MCP sealing)
- ⏳ Phases 3-8 follow same strict dependency order

Do not proceed to next cluster until current cluster builds cleanly and expected failures are addressed.

## Next Execution Session

Begin with: **Cluster 1.2 — ControllerRuntimeBridge refactoring**

Follow with: **Cluster 1.3 — Repo-wide RuntimeContext sweep**

After full Phase 1 completion: Proceed to Phase 2

---

Status: Phase 0 complete. Phase 1 cluster 1.1 complete. Build in progress revealing authority leaks.
Ready for systematic fix via Clusters 1.2-1.3.

