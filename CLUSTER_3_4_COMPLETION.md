# Cluster 3.4 Completion — MCP Boundary Guard in CI

## What Was Done

### 1. Created `scripts/mcp_boundary_guard.py`
- Enforces the sealed MCP transport contract defined in `MCPBoundary.swift`
- **Rule**: Inside `MCPDispatch.dispatch()`, all parameter reads must use JSONValue typed accessors:
  - `args[key]?.stringValue`
  - `args[key]?.intValue`
  - `args[key]?.doubleValue`
  - `args[key]?.boolValue`
  - `args[key]?.arrayValue`
  - `args[key]?.objectValue`
- **Never**: Cast to `[String: Any]` in the input path
- Guards `MCPServer.swift` (wire edge) and response formatting methods as exceptions
- Flagged 10 violations in initial scan (all in `dispatch()` function)

### 2. Fixed `Sources/OracleOS/MCP/MCPDispatch.swift`
Refactored 5 tool handlers to use type-safe serialization:
- `oracle_recipe_show` (line 406)
- `oracle_architecture_review` (line 595)
- `oracle_candidate_review` (line 633)
- `oracle_workflow_mine` (line 654)
- `oracle_workflow_list` (line 664)

**Pattern Changed**:
```swift
// OLD (banned in input path):
if let data = try? JSONEncoder().encode(recipe),
   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    return ToolResult(success: true, data: dict)
}

// NEW (output path only):
if let recipeData = toDictionary(recipe) {
    return ToolResult(success: true, data: ["recipe": recipeData])
}
```

Added `toDictionary<T: Encodable>()` helper:
- Centralized place to perform JSONSerialization + cast to `[String: Any]`
- Only used in response formatting (output path)
- Comments clearly state: "output path only. Never use in input path."

### 3. Updated CI Workflow
- Modified `.github/workflows/architecture.yml`
- Added step: `Run MCP Boundary Guard` (runs `python scripts/mcp_boundary_guard.py`)
- Now runs alongside existing `architecture_guard.py`

### 4. Verified
- Guard passes on current codebase ✅
- Python syntax correct ✅
- Swift syntax correct ✅
- Changes committed: `git commit [5b86cd9]` ✅

## Guard Output

```
MCP boundary guard passed.
```

## Key Principle

**Wire edge vs. input path**:
- **Wire edge** (MCPServer): Use `[String: Any]` — it's the JSON-RPC boundary
- **Input path** (MCPDispatch.dispatch()): Use JSONValue + typed accessors only
- **Output path** (MCPDispatch response formatting): Convert Codable → `[String: Any]` via `toDictionary()`, wrap in `toDict()`

## Next Steps (Cluster 3.5)

1. Build with Swift 6 strict concurrency checks to identify isolation errors
2. Fix remaining isolation issues in MCPDispatch/MCPToolRouter
3. Run full test suite with `-Xswiftc -strict-concurrency=complete`
4. Then proceed to Phase 4: Memory side effect decoupling

## Files Modified

- `scripts/mcp_boundary_guard.py` (NEW)
- `.github/workflows/architecture.yml` (UPDATED)
- `Sources/OracleOS/MCP/MCPDispatch.swift` (REFACTORED)

## Commit

```
Cluster 3.4: Add MCP boundary guard to CI pipeline
- Create scripts/mcp_boundary_guard.py to enforce sealed MCP transport contract
- Refactor MCPDispatch to extract toDictionary() helper for output path
- Fix oracle_recipe_show, oracle_architecture_review, oracle_workflow_*
- Add MCP boundary guard step to .github/workflows/architecture.yml
- Guard passes on current codebase

Hash: 5b86cd9
```

## Status

✅ **Cluster 3.4 Complete**
- MCP boundary enforcement active in CI
- All violations fixed
- Ready for Cluster 3.5: Swift 6 strict concurrency

**Total Progress**: 3.5 of 8 phases complete
- Phase 0: ✅
- Phase 1: ✅
- Phase 2: ✅
- Phase 3.1: ✅
- Phase 3.2: ✅
- Phase 3.3: ✅
- Phase 3.4: ✅
- Phase 3.5: NEXT (strict concurrency)
