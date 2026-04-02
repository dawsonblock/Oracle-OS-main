# Architecture Deep Dive

## Table of Contents
1. [System Overview](#system-overview)
2. [Core Components](#core-components)
3. [Data Flow](#data-flow)
4. [Concurrency Model](#concurrency-model)
5. [Memory Management](#memory-management)
6. [Extension Points](#extension-points)

---

## System Overview

### Design Principles

**Oracle-OS** is built on five core principles:

1. **Single Authority**: One RuntimeContainer controls all state
2. **Hard Boundaries**: Process execution isolated to adapters
3. **Sealed Contracts**: All external APIs versioned and stable
4. **Deterministic Planning**: Same input always produces same output
5. **Decoupled Learning**: Memory is a side effect, never blocks execution

### Architecture Layers

```
┌─────────────────────────────────────┐
│     Controller / Host UI             │
│  (OracleController, OracleControllerHost)
├─────────────────────────────────────┤
│        Intent API (Boundary)         │
│   submitIntent() → IntentResponse    │
├─────────────────────────────────────┤
│    RuntimeOrchestrator (@MainActor) │
│   • Coordinates execution            │
│   • Manages actor isolation          │
├─────────────────────────────────────┤
│    RuntimeContainer (Sealed)         │
│   • Singleton state authority        │
│   • Immutable snapshots              │
├─────────────────────────────────────┤
│    Planning Layer                    │
│   • MainPlannerRefactored (honest)   │
│   • Domain routers (UI/Code/System)  │
├─────────────────────────────────────┤
│    Execution Layer                   │
│   • CommandAssembler                 │
│   • ProcessAdapter (sealed)          │
├─────────────────────────────────────┤
│    Memory Layer                      │
│   • EventStore (persisted)           │
│   • MemoryProjections (async)        │
├─────────────────────────────────────┤
│    Host Automation                   │
│   • AutomationHost (sealed)          │
│   • Browser/Process/Window services  │
└─────────────────────────────────────┘
```

---

## Core Components

### 1. RuntimeContainer (Sealed Authority)

**Location**: `Sources/OracleOS/Runtime/RuntimeContainer.swift`

**Responsibility**: Single source of truth for all runtime state

```swift
actor RuntimeContainer {
    // Immutable snapshot at any point in time
    nonisolated var snapshot: RuntimeSnapshot { ... }
    
    // Update state through sealed transitions
    func transitionState(_ fn: (inout RuntimeState) -> Void) async { ... }
}
```

**Key Properties**:
- ✅ **Serialized Access**: Actor isolation ensures no concurrent mutations
- ✅ **Transactional Updates**: All-or-nothing state transitions
- ✅ **Snapshot Consistency**: Readers get frozen views
- ✅ **Unbounded Durability**: EventStore persists all changes

**Scaling Characteristic**: O(1) snapshot time, O(n) event persistence

### 2. RuntimeOrchestrator (Coordination)

**Location**: `Sources/OracleOS/Runtime/RuntimeOrchestrator.swift`

**Responsibility**: Coordinates planning, execution, and memory across boundaries

```swift
@MainActor
final class RuntimeOrchestrator {
    func run(_ intent: Intent) async throws -> ExecutionResult { ... }
    
    private func planIntent(_ intent: Intent) async throws -> Command { ... }
    private func executeCommand(_ command: Command) async throws -> Result { ... }
    private func recordResult(_ result: Result) async { ... }
}
```

**Key Guarantees**:
- ✅ **MainActor Isolated**: Safe for UI updates
- ✅ **Sequential Execution**: One intent at a time
- ✅ **Memory Async**: Learning doesn't block execution
- ✅ **Error Propagation**: All errors bubble to handler

**Failure Modes**:
- Planning timeout → execution skipped
- Execution failure → error recorded, state unchanged
- Memory failure → logged, execution not blocked

### 3. MainPlannerRefactored (Honest Contract)

**Location**: `Sources/OracleOS/Planning/MainPlannerRefactored.swift`

**Responsibility**: Deterministically route intents to typed commands

```swift
public func plan(intent: Intent, context: PlannerContext) async throws -> Command {
    switch intent.domain {
    case .ui: return try await planUIIntent(intent, context: context)
    case .code: return try await planCodeIntent(intent, context: context)
    case .system, .mixed: return try await planSystemIntent(intent, context: context)
    }
}
```

**Determinism Guarantees**:
- ✅ **Pure Logic**: No mutable state (currentGoal removed)
- ✅ **Explicit Dependencies**: All 9 dependencies injected
- ✅ **Deterministic Routing**: Same input domain → same routing
- ✅ **Type Safety**: All outputs properly typed

**Domain Routing**:

| Domain | Intent Pattern | Output Type | Router |
|--------|---|---|---|
| `.ui` | "click X" | `.ui(UIAction)` | planUIIntent() |
| `.code` | "search X" | `.code(CodeAction)` | planCodeIntent() |
| `.code` | "build" | `.build(BuildSpec)` | planCodeIntent() |
| `.code` | "test" | `.test(TestSpec)` | planCodeIntent() |
| `.system` | "launch X" | `.ui(UIAction)` | planSystemIntent() |
| `.mixed` | context-dependent | varies | planSystemIntent() |

### 4. ProcessAdapter (Sealed Boundary)

**Location**: `Sources/OracleOS/Execution/ProcessAdapter.swift`

**Responsibility**: Encapsulate all system process execution

```swift
public protocol ProcessAdapter: Sendable {
    func execute(_ spec: CommandPayload) throws -> CommandResult
}
```

**Implementations**:
- **DefaultProcessAdapter**: Real process execution via Foundation
- **MockProcessAdapter**: Testing implementation

**Key Properties**:
- ✅ **Sendable**: Thread-safe, can be shared across actors
- ✅ **Typed**: CommandPayload enum prevents invalid inputs
- ✅ **Synchronous**: No async overheads in hot path
- ✅ **Error Propagation**: All failures bubble as throws

**Supported Commands**:
- UI actions (click, type, focus)
- Code operations (search, build, test)
- File mutations (read, write, delete)
- Git operations (commit, push, pull)

### 5. AutomationHost (MainActor Sealed)

**Location**: `Sources/OracleOS/HostAutomation/AutomationHost.swift`

**Responsibility**: Provide all system automation APIs via isolated services

```swift
@MainActor
public struct AutomationHost {
    public let applications: any ApplicationServicing
    public let windows: any WindowServicing
    public let menus: any MenuServicing
    public let dialogs: any DialogServicing
    public let processes: ProcessService
    public let screenCapture: any CaptureServicing
    public let snapshots: SnapshotService
    public let permissions: PermissionService
}
```

**Service Architecture**:

| Service | Purpose | Protocol |
|---------|---------|----------|
| ApplicationServicing | App lifecycle | list, launch, quit, getFocused |
| WindowServicing | Window operations | list, focus, move, resize |
| MenuServicing | Menu navigation | click, query, list |
| DialogServicing | Dialog handling | detect, read, interact |
| ProcessService | Process info | list, getInfo, create |
| CaptureServicing | Screenshots | capture, analyze |
| SnapshotService | System state | snapshot, diff |
| PermissionService | System permissions | check, request |

**Key Properties**:
- ✅ **MainActor Isolation**: Safe for UI framework calls
- ✅ **Service Injection**: Each service independently mockable
- ✅ **Factory Pattern**: live() factory for production instances
- ✅ **Sealed API**: All methods public, all implementations internal

### 6. EventStore (Persistence)

**Location**: `Sources/OracleOS/Events/EventStore.swift`

**Responsibility**: Durably persist all runtime events

```swift
public protocol EventStore: Sendable {
    func append(_ event: DomainEvent) async throws
    func stream() -> AsyncStream<EventEnvelope>
    func query(predicate: EventPredicate) async throws -> [EventEnvelope]
}
```

**Event Types**:
- IntentSubmitted
- CommandGenerated
- CommandExecuted
- ExecutionFailed
- MemoryInfluenceApplied
- StateTransitioned

**Durability Guarantees**:
- ✅ **ACID Transactions**: append() is all-or-nothing
- ✅ **Ordered Stream**: Events strictly ordered by timestamp
- ✅ **Query Support**: Filter by type, time, intent ID
- ✅ **Replay Capable**: Full history available for replay

**Scaling Characteristic**: O(1) append, O(n) query/stream

### 7. Memory Layer (Async Learning)

**Location**: `Sources/OracleOS/Memory/`

**Architecture**:

```
MemoryEventIngestor (async)
    ↓
MemoryProjection (idempotent)
    ↓
PatternMemoryStore / StrategyMemoryStore (indexing)
    ↓
UnifiedMemoryStore (query interface)
```

**Key Properties**:
- ✅ **Fire-and-Forget**: Recording doesn't block execution
- ✅ **Idempotent**: Same event can be processed multiple times
- ✅ **Deterministic**: Same events always produce same patterns
- ✅ **Queryable**: Influence() for planning decisions

**Memory Types**:

| Type | Purpose | Usage |
|------|---------|-------|
| Strategy Memory | High-level patterns | Planner influence |
| Execution Memory | Success/failure | Command selection |
| Pattern Memory | Temporal patterns | Timing decisions |

---

## Data Flow

### Intent Submission → Execution

```
1. Controller submits Intent to IntentAPI
   ├─ domain: .ui / .code / .system
   ├─ objective: "user's goal"
   └─ metadata: additional hints

2. RuntimeOrchestrator.run(intent)
   ├─ Creates PlannerContext
   ├─ Calls planner.plan(intent, context)
   └─ Receives typed Command

3. MainPlannerRefactored.plan()
   ├─ Routes by intent.domain
   ├─ Parses objective for action
   └─ Returns Command with typed payload

4. CommandAssembler enriches Command
   ├─ Adds timing metadata
   ├─ Enriches with execution context
   └─ Validates against policy

5. ProcessAdapter.execute(payload)
   ├─ Translates to system call
   ├─ Captures result
   └─ Returns CommandResult

6. RuntimeContainer updates state
   ├─ Records CommandExecuted event
   ├─ Updates WorldStateModel
   └─ Notifies listeners

7. MemoryEventIngestor (async)
   ├─ Processes CommandExecuted event
   ├─ Updates pattern recognition
   └─ Doesn't block execution
```

### Memory Influence Flow

```
MemoryEventIngestor
    ↓
Event Pattern Recognition
    ↓
MemoryProjections
    ├─ StrategyProjection: high-level patterns
    ├─ ExecutionProjection: success/failure
    └─ TemporalProjection: timing patterns
    ↓
UnifiedMemoryStore (queryable index)
    ↓
RuntimeOrchestrator.recordResult()
    ↓
Next PlannerContext includes memory influence
    ↓
Planner uses influence for decisions
```

---

## Concurrency Model

### Actor Isolation

**MainActor** (UI-safe):
- RuntimeOrchestrator
- AutomationHost
- BrowserController

**Sendable** (Data types):
- Intent, Command, CommandPayload
- RuntimeSnapshot, WorldStateModel
- All DTOs and requests

**Async Boundaries**:
- Planner: async (may have LLM calls)
- ProcessAdapter: sync (fast path)
- EventStore: async (disk I/O)
- MemoryStore: async (background processing)

### Race Condition Prevention

**Strategy 1: Actor Isolation**
```swift
actor RuntimeContainer {
    nonisolated var snapshot: RuntimeSnapshot  // Read-only
    func transitionState(_ fn: (inout RuntimeState) -> Void) async  // Serialized
}
```

**Strategy 2: Immutable Snapshots**
```swift
struct RuntimeSnapshot: Sendable {
    let state: WorldStateModel  // Immutable value type
    let timestamp: Date
    let eventCount: Int
}
```

**Strategy 3: Sendable Types**
```swift
struct Intent: Sendable { ... }  // Can cross actor boundaries safely
```

**Strategy 4: No Shared Mutable State**
```swift
public func plan(intent: Intent, context: PlannerContext) async throws -> Command {
    // No currentGoal property (removed in MainPlannerRefactored)
    // No mutable state at all
    // Pure function from input → output
}
```

---

## Memory Management

### Heap Objects

**Long-lived** (per RuntimeContainer):
- RuntimeContainer itself
- RuntimeState
- EventStore (unbounded)

**Medium-lived** (per execution):
- Intent, Command
- RuntimeSnapshot
- PlannerContext

**Short-lived** (local to methods):
- Temporary arrays
- String parsing
- Computation intermediates

### Optimization Opportunities

1. **Event Pruning**: Old events > 30 days can be archived
2. **MemoryProjection Caching**: Precompute common queries
3. **Snapshot Pooling**: Reuse snapshot objects in hot path
4. **String Interning**: Cache common objective patterns

### Monitoring

Check memory growth:
```bash
swift test --filter ProductionValidationTests/testMemoryStabilityExtended
```

Expected: < 30% growth over 1000 planning cycles

---

## Extension Points

### Adding a New Intent Domain

1. Add to `IntentDomain` enum
2. Add router in `MainPlannerRefactored`
3. Add command type to `CommandPayload`
4. Update contract tests
5. Update documentation

**Example: Adding `.network` domain**

```swift
// 1. Enum
public enum IntentDomain {
    case ui, code, system, mixed, network  // NEW
}

// 2. Router
private func planNetworkIntent(_ intent: Intent, context: PlannerContext) async throws -> Command {
    // Custom logic for network intents
}

// 3. CommandPayload
public enum CommandPayload {
    case network(NetworkSpec)  // NEW
}

// 4. Contract test
func testNetworkDomainRouting() { ... }

// 5. Docs: update PLANNER_CONTRACT.md
```

### Adding a New External Service

1. Define protocol with version
2. Create contract tests
3. Add to sidecar contracts doc
4. Create sealed implementation
5. Register in RuntimeBootstrap

**Example: Adding persistence adapter**

```swift
// 1. Protocol
public protocol PersistenceAdapter: Sendable {
    func read(key: String) async throws -> Data
    func write(key: String, data: Data) async throws
}

// 2. Tests: PersistenceAdapterContractTests.swift
// 3. Docs: Update SIDECAR_CONTRACTS.md section 8
// 4. Implementation: DefaultPersistenceAdapter
// 5. Bootstrap: Add factory method
```

### Adding Memory Projection Type

1. Create new projection struct
2. Implement MemoryProjection protocol
3. Register in MemoryEventIngestor
4. Update UnifiedMemoryStore to query it
5. Use in planner via influence()

**Example: Adding gesture pattern memory**

```swift
struct GesturePatternProjection: MemoryProjection {
    // Tracks common mouse/keyboard patterns
    func project(_ event: DomainEvent) { ... }
}
```

---

## Performance Characteristics

| Operation | Time | Space | Notes |
|-----------|------|-------|-------|
| plan() | 10-50ms | 100KB | Varies by domain |
| execute() | <10ms | <50KB | ProcessAdapter overhead |
| snapshot | <1ms | 1-10MB | Entire runtime state |
| append event | <100μs | var | SSD dependent |
| query events | 10-100ms | var | Index scan |
| influence() | 1-5ms | 1MB | Memory query |

---

## Reliability & Failures

### Failure Modes & Recovery

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Plan timeout | RuntimeTimeout | Skip execution, log |
| Execute failure | CommandResult error | Record failure, continue |
| EventStore failure | append() throws | Retry with backoff |
| Memory failure | MemoryStore error | Continue (async, non-blocking) |
| Actor deadlock | Timeout | Rollback transaction |

### SLAs

- **Planner**: <500ms p95, <1s p99
- **Executor**: <10ms p95 (process-dependent)
- **EventStore**: <100ms append, <1s query
- **Memory**: No SLA (async, fire-and-forget)

---

## Related Documentation

- [PLANNER_CONTRACT.md](PLANNER_CONTRACT.md) - Planner contract and guarantees
- [SIDECAR_CONTRACTS.md](SIDECAR_CONTRACTS.md) - All external service contracts
- [GOVERNANCE.md](GOVERNANCE.md) - Testing & verification standards
- [runtime_invariants.md](runtime_invariants.md) - Actor invariants
