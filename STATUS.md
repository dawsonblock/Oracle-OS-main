# Oracle OS — Current Status

## Authoritative Today

**Runtime Spine**: Core bootstrap path, RuntimeOrchestrator, VerifiedExecutor, CommitCoordinator, and EventStore exist and are operational.

**Event Model**: Seven domain event types formally defined (intentReceived, planGenerated, commandExecuted, commandFailed, evaluationCompleted, uiObserved, memoryRecorded).

**Command Types**: Typed CommandPayload with six cases (build, test, git, file, ui, code) and proper routing through CommandRouter.

**Core Governance Tests**: ExecutionBoundaryTests, ExecutionBoundaryEnforcementTests, EventHistoryInvariantTests exist and validate key invariants.

**Documentation**: ARCHITECTURE.md, runtime_spine.md, event_model.md, product_boundary.md, deprecation_map.md are current.

## Not Yet Authoritative

**RuntimeContext Authority**: RuntimeContext.swift still exposes policyEngine, workspaceRunner, repositoryIndexer alongside read-side services. These create an alternate authority surface. (Fix: Phase 1)

**Controller Bridge Storage**: ControllerRuntimeBridge still stores runtimeContext as a first-class runtime object. (Fix: Phase 1)

**MCP Transport**: MCPDispatch.swift remains monolithic, contains [String: Any] dictionaries at the runtime boundary, and has tangled concurrency logic. (Fix: Phase 3)

**Process Boundary Enforcement**: Direct Process() calls exist in CLI tooling, but enforcement is grep-based and governance tests are narrative-style rather than structural. (Fix: Phase 2)

**Sidecar Contracts**: vision-sidecar/ and web/ are still directories in the main tree without versioned contracts. (Fix: Phase 6)

## Known Contracts Still Loose

**MCP Request/Response**: MCPDispatch still handles tools with loose dictionary arguments and responses.

**RuntimeContext Service Semantics**: No clear distinction between read-side and execution-capable access patterns.

**Vision Sidecar**: Schema exists but is not a frozen contract with round-trip tests.

## Known Governance Test Weakness

**Narrative vs Structural**: Governance tests include documentation-style assertions and comment-based "this is enforced by" statements rather than failing on real drift.

**RuntimeContext Leakage**: Tests still construct RuntimeContext with execution adapters, validating the wrong model.

**Process Guard**: Enforcement is external (scripts/guard_process.sh) rather than compile-time or test-integrated.

## Known Repo Hygiene Problem

**Root-Level Debris**: 51 patch/fix scripts were moved to tools/quarantine/legacy-repair/, but 15 stale "completion" and "handoff" documents remained at root until Phase 0.

## Next Action

See FULL_PLAN.md for the ordered eight-phase refactor that will address each of these gaps in dependency order.

Stale historical documents archived to docs/archive/status-history/.
