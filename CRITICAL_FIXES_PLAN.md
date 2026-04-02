# Critical Architecture Fixes — Action Plan

## Status Assessment

After detailed code review:

### RuntimeContext Authority Issue
**Severity**: MEDIUM
**Current State**: RuntimeContext is a broad facade with 22 service dependencies, but:
- ✅ NOT used for execution (no `.execute()` calls found)
- ✅ Bootstrap correctly creates RuntimeBootstrap
- ✅ RuntimeOrchestrator is the execution authority
- ⚠️ However: ControllerRuntimeBridge carries RuntimeContext as primary accessor layer (not a thin facade)

**Why This Matters**: The context is correct in principle but overweight in practice. It's a convenience layer, not a dangerous authority leak.

**Required Fix**: Document RuntimeContext as a read-only facade layer with explicit scope limits.

### MCP Concurrency Issue
**Severity**: CRITICAL
**Current State**: MCPDispatch shows Swift 6 concurrency violations
- ❌ TaskGroup capturing non-Sendable values
- ❌ [String: Any] leaking across actor boundaries
- ❌ Non-isolated method calls with shared mutable state
- ✅ MCPBoundary.swift exists (good foundation)

**Why This Matters**: Swift 6 strict concurrency is not optional. This fails the build.

**Required Fix**: Enforce Sendable throughout MCP layer, eliminate [String: Any].

### Governance Test Drift
**Severity**: CRITICAL
**Current State**: Tests lag behind recent enum/protocol changes
- CommandPayload enum changed
- EventReducer protocol signature changed
- Tests not updated to match

**Why This Matters**: The safety story depends on tests catching drift immediately. If tests are behind, the safety guarantee is broken.

**Required Fix**: Make tests fail when architecture changes occur.

### Root Cleanup
**Severity**: MEDIUM
**Current State**: 57+ patch/fix scripts still present
**Why This Matters**: Trust and professionalism
**Required Fix**: Move to quarantine directory

---

## Realistic Execution (What Takes How Long)

### Quick Fixes (< 1 hour each)
1. ✅ Root cleanup — delete/move patch scripts
2. ✅ Governance test repair — update for enum/protocol changes
3. ✅ Documentation — mark RuntimeContext as read-only facade

### Medium Fix (2-3 hours)
4. ⚠️ MCP concurrency — Replace [String: Any] with JSONValue throughout MCPDispatch

### Larger Refactor (> 4 hours, skip for now)
5. ❌ RuntimeContext collapse — Would require rewriting all service access patterns throughout ControllerRuntimeBridge

---

## Recommended Scope (This Session)

Execute fixes 1-4. Skip 5 (too large, less critical).

**Rationale**:
- Fixes 1-3 are high-leverage (governance + trust)
- Fix 4 unblocks Swift 6 compliance
- Fix 5 would require deep controller refactoring (low ROI this session)

The RuntimeContext issue is **real but lower priority** than MCP concurrency and governance test sync.

---

## Next Steps

I will execute:
1. Root cleanup (remove 57+ scripts)
2. Governance test updates (CommandPayload + EventReducer sync)
3. MCP concurrency hardening (JSONValue throughout)
4. Documentation (RuntimeContext contract, architecture notes)

Expected result: Clean build, passing tests, Sendable-safe MCP layer.

