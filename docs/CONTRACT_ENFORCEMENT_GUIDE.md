# Contract Enforcement Guide

## Purpose

This guide documents how Oracle-OS enforces its contracts at compile time, runtime, and through automated verification. It's the operational manual for maintaining contract compliance as the system evolves.

---

## Contract Layers

### Layer 1: Compile-Time (Swift Type System)

**Static Enforcement**:
- ✅ Sendable conformance (thread-safety)
- ✅ Actor isolation (@MainActor, actor declarations)
- ✅ Type safety (no [String: Any])
- ✅ Protocol conformance
- ✅ Visibility rules (public/internal/private)

**Example: Thread-Safety by Type**
```swift
// ✅ GOOD: Sendable guarantees thread-safety
public protocol Planner: Sendable {
    func plan(intent: Intent, context: PlannerContext) async throws -> Command
}

// ❌ BAD: Not Sendable, can't cross actor boundaries
public protocol BadPlanner {  // Implicitly not Sendable
    func plan(...) async throws -> Command
}
```

**Example: Actor Isolation**
```swift
// ✅ GOOD: MainActor isolation enforced at compile time
@MainActor
final class RuntimeOrchestrator {
    func run(_ intent: Intent) async throws { ... }
}

// ❌ BAD: Can be called from any actor (race conditions possible)
final class BadOrchestrator {
    func run(_ intent: Intent) async throws { ... }
}
```

**Verification**:
```bash
swift build  # Fails if contract violated
```

### Layer 2: Contract Tests (Runtime Enforcement)

**Test Coverage**:

| Contract | Tests | Location |
|----------|-------|----------|
| Planner | PlannerContractTests (18 tests) | Tests/OracleOSTests/Planning/ |
| Sidecar APIs | SidecarContractTests (26 tests) | Tests/OracleOSTests/API/ |
| Memory | MemoryContractTests (47+ tests) | Tests/OracleOSTests/Memory/ |
| MCP Transport | MCPContractTests (60+ tests) | Tests/OracleOSTests/MCP/ |
| Governance | GovernanceTests (39+ tests) | Tests/OracleOSTests/Governance/ |

**Example: Planner Determinism Test**
```swift
func testPlannerDeterminism() async throws {
    let intent = Intent(id: UUID(), domain: .ui, objective: "click", metadata: [:])
    let context = PlannerContext(state: .empty(), memories: [], snapshot: nil)
    
    // Same input should produce same command ID
    let cmd1 = try await planner.plan(intent: intent, context: context)
    let cmd2 = try await planner.plan(intent: intent, context: context)
    
    XCTAssertEqual(cmd1.id, cmd2.id, "Determinism violated!")
}
```

**Verification**:
```bash
swift test  # All tests must pass
```

### Layer 3: Architecture Guards (CI Automation)

**Guard Scripts**:

1. **execution_boundary_guard.py**
   - Verifies ProcessAdapter isolation
   - Ensures no direct Process calls elsewhere
   - Scans for prohibited imports

2. **architecture_guard.py**
   - Verifies layer boundaries
   - Checks visibility rules (public/internal)
   - Detects circular dependencies

3. **mcp_boundary_guard.py**
   - Verifies MCP transport sealing
   - Checks JSONValue type safety
   - Validates tool specifications

**Verification**:
```bash
python scripts/execution_boundary_guard.py
python scripts/architecture_guard.py
python scripts/mcp_boundary_guard.py
```

**Example Guard Logic** (execution_boundary_guard.py):
```python
def verify_execution_isolation():
    # Scan all Swift files
    for file in glob("Sources/**/*.swift"):
        content = read(file)
        
        # ✅ ProcessAdapter calls OK
        if "processAdapter.execute" in content:
            continue
        
        # ❌ Direct Process creation NOT OK
        if re.search(r'Process\(\)', content):
            raise AssertionError(f"Direct Process in {file}")
        
        # ❌ Direct shell execution NOT OK
        if re.search(r'shell\(', content):
            raise AssertionError(f"Direct shell in {file}")
```

### Layer 4: Documentation (Manual Verification)

**Contracts Documented**:
- PLANNER_CONTRACT.md (500+ lines)
- SIDECAR_CONTRACTS.md (800+ lines)
- GOVERNANCE.md (compliance criteria)
- This guide (operational manual)

**Change Protocol**:
1. Update documentation FIRST
2. Implement changes
3. Update contracts section in docs
4. Run tests to verify
5. Commit with contract rationale

---

## Adding a New Contract

### Step 1: Define the Contract (Docs)

Create a section in SIDECAR_CONTRACTS.md:

```markdown
## 8. NewService (Service Boundary)

**Location**: `Sources/OracleOS/Services/NewService.swift`
**Version**: 1.0
**Stability**: Stable

### Contract
```swift
public protocol NewService: Sendable {
    func doWork(_ input: Input) async throws -> Output
}
```

### Guarantees
- ✅ Sendable (thread-safe)
- ✅ Async-capable
- ✅ Typed I/O
- ✅ Error propagation
```

### Step 2: Implement with Type Safety

```swift
// ✅ Sendable types for all inputs/outputs
public struct Input: Sendable { ... }
public struct Output: Sendable { ... }

// ✅ Protocol with Sendable conformance
public protocol NewService: Sendable {
    func doWork(_ input: Input) async throws -> Output
}

// ✅ Sealed implementation (internal)
final class DefaultNewService: NewService {
    func doWork(_ input: Input) async throws -> Output { ... }
}

// ✅ Factory in RuntimeBootstrap
func makeNewService() -> NewService {
    DefaultNewService()
}
```

### Step 3: Write Contract Tests

```swift
final class NewServiceContractTests: XCTestCase {
    
    // Test 1: Protocol conformance
    func testConformance() {
        let service: NewService = DefaultNewService()
        XCTAssertNotNil(service)
    }
    
    // Test 2: Type safety
    func testTypeSafety() async throws {
        let input = Input(...)
        let output = try await service.doWork(input)
        XCTAssertTrue(output is Output)
    }
    
    // Test 3: Error propagation
    func testErrorPropagation() async throws {
        let invalidInput = Input.invalid()
        XCTAssertThrowsError(
            try await service.doWork(invalidInput)
        )
    }
    
    // Test 4: Thread safety (Sendable)
    func testSendable() async {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { [service] in
                    _ = try? await service.doWork(...)
                }
            }
        }
        // If this compiles and passes, Sendable works
    }
}
```

### Step 4: Register in CI Pipeline

Add to `.github/workflows/architecture.yml`:

```yaml
- name: Verify New Service Contract
  run: |
    python scripts/verify_new_service.py
    swift test --filter NewServiceContractTests
```

### Step 5: Update Governance

Add to GOVERNANCE.md:

```markdown
### NewService Contract
- **Files**: Sources/OracleOS/Services/
- **Tests**: Tests/OracleOSTests/Services/NewServiceContractTests.swift
- **CI Guard**: scripts/verify_new_service.py
- **Version**: 1.0
```

---

## Enforcing Existing Contracts

### Planner Contract

**What It Guarantees**:
- Single entry point: `plan(intent, context) -> Command`
- Deterministic: Same input always same output
- Stateless: No mutable state
- Type-safe: All outputs properly typed
- Sendable: Can cross actor boundaries

**How to Verify**:
```bash
swift test --filter PlannerContractTests
# Must pass all 18 tests
```

**Common Violations** (What NOT to Do):

```swift
// ❌ Adding mutable state
private var currentGoal: Goal?

// ❌ Multiple entry points
public func nextStep() { ... }
public func setGoal(_ goal: Goal) { ... }

// ❌ Optional parameters (breaks explicit injection)
public init(..., osPlanner: OSPlanner? = nil)

// ❌ Side effects during planning
func plan(...) {
    memoryStore.recordControl(...)  // Non-deterministic!
    currentGoal = newGoal  // Mutable state!
}

// ❌ Type-unsafe returns
return ["action": "click"] as [String: Any]
```

### Sidecar Contracts

**Version Control**:
- **Breaking Change** (Major bump): Remove method, change signature, change return type
- **Feature Addition** (Minor bump): Add new method, add optional parameter
- **Bug Fix** (Patch bump): Documentation, performance, non-breaking fix

**Example: Adding Optional Parameter (Minor Bump)**

```swift
// v1.0
public protocol IntentAPI: Sendable {
    func submitIntent(_ intent: Intent) async throws -> IntentResponse
}

// v1.1 - Feature addition, no breaking change
public protocol IntentAPI: Sendable {
    func submitIntent(_ intent: Intent, timeout: TimeInterval? = nil) async throws -> IntentResponse
}
```

**Example: Breaking Change (Major Bump)**

```swift
// v1.0
public func execute(_ spec: CommandPayload) throws -> CommandResult

// v2.0 - Breaking change (changed return type)
public func execute(_ spec: CommandPayload) throws -> NewCommandResult

// Must:
// 1. Create new major version
// 2. Add deprecation warning to v1.0
// 3. Support both for transition period
// 4. Document in CHANGELOG
```

---

## Continuous Verification

### Pre-Commit Checks

```bash
#!/bin/bash
set -e

# 1. Build must succeed
swift build

# 2. All tests must pass
swift test

# 3. All guards must pass
python scripts/execution_boundary_guard.py
python scripts/architecture_guard.py
python scripts/mcp_boundary_guard.py

# 4. No breaking changes to contracts
python scripts/contract_version_check.py
```

### CI Pipeline (.github/workflows/architecture.yml)

**Runs on every commit**:
1. Swift build
2. Test suite (172+ tests)
3. All three guard scripts
4. Contract version verification
5. Performance regression detection

### Local Verification Checklist

Before committing changes:

- [ ] `swift build` succeeds
- [ ] `swift test` succeeds (all 172+ tests)
- [ ] Guard scripts pass:
  ```bash
  python scripts/execution_boundary_guard.py
  python scripts/architecture_guard.py
  python scripts/mcp_boundary_guard.py
  ```
- [ ] No new `@available` deprecations added (unless intentional)
- [ ] Contract docs updated if signatures changed
- [ ] Tests updated to match contract changes

---

## Contract Evolution

### Scenario 1: Bug Fix (Patch)

**Example**: Fix memory leak in Planner

```swift
// Implementation improves, interface stays same
// Increment: v1.0 → v1.0.1
// Tests: No changes (already covered)
// Docs: Add note about fix
```

### Scenario 2: Feature Addition (Minor)

**Example**: Add memory hints to planning

```swift
// OLD (v1.0)
public func plan(intent: Intent, context: PlannerContext) async throws -> Command

// NEW (v1.1)
public func plan(
    intent: Intent,
    context: PlannerContext,
    memoryHints: [MemoryHint]? = nil  // Optional, backward compatible
) async throws -> Command

// Steps:
// 1. Add parameter as optional
// 2. Add tests for new parameter
// 3. Update PLANNER_CONTRACT.md
// 4. Increment version 1.0 → 1.1
// 5. All old code continues working
```

### Scenario 3: Breaking Change (Major)

**Example**: Change Command structure

```swift
// OLD (v1.0)
public struct Command: Sendable {
    let id: UUID
    let payload: CommandPayload
}

// NEW (v2.0)
public struct Command: Sendable {
    let id: UUID
    let version: String  // New required field
    let payload: CommandPayload
}

// Steps:
// 1. Create new version 2.0
// 2. Implement both v1.0 and v2.0
// 3. Deprecate v1.0: @available(*, deprecated, message: "Use v2.0")
// 4. Update tests for v2.0
// 5. Support both for 3 minor versions (1.1, 1.2, 1.3)
// 6. Remove v1.0 in v3.0
// 7. Document migration guide
```

---

## Troubleshooting Contract Violations

### Problem: Test Fails with Type Error

```
error: cannot convert value of type 'A' to expected argument type 'B'
```

**Diagnosis**: Type safety contract violated

**Fix**: Ensure contract types match:
```swift
// Wrong
let intent: [String: Any] = [...]  // Type-unsafe!

// Right
let intent = Intent(id: UUID(), domain: .ui, objective: "...", metadata: [:])
```

### Problem: Planner Returns Different Results

```
XCTAssertEqual failed: got cmd2, expected cmd1
```

**Diagnosis**: Determinism contract violated

**Fix**: Check for:
- Mutable state (currentGoal, etc.)
- Side effects (recordControl, memoryStore updates)
- Random operations
- System time (Date(), UUID())

**Example Fix**:
```swift
// Wrong
let cmd = Command(id: UUID(), ...)  // Different each time!

// Right
let cmd = Command(id: intent.id, ...)  // Use intent ID
```

### Problem: Concurrency Crash

```
Fatal error: datarace detected
```

**Diagnosis**: Sendable contract violated

**Fix**: Ensure all types conform to Sendable:
```swift
// Wrong
public struct State {  // Not Sendable
    var counter: Int = 0
}

// Right
public struct State: Sendable {
    let counter: Int
}
```

---

## References

- [PLANNER_CONTRACT.md](PLANNER_CONTRACT.md)
- [SIDECAR_CONTRACTS.md](SIDECAR_CONTRACTS.md)
- [GOVERNANCE.md](GOVERNANCE.md)
- [ARCHITECTURE_DEEP_DIVE.md](ARCHITECTURE_DEEP_DIVE.md)
