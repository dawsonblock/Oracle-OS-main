# Sidecar Contracts

## Overview

This document specifies the version-controlled APIs for all external services and sidecars that Oracle-OS communicates with. These contracts establish clear boundaries and compatibility guarantees.

## Version: 1.0

**Last Updated**: [Current Date]
**Status**: Stable
**Breaking Changes Policy**: Major version on breaking change; minor version on addition; patch version on bug fixes

---

## 1. IntentAPI (Controller Boundary)

**Location**: `Sources/OracleOS/API/IntentAPI.swift`
**Version**: 1.0
**Stability**: Stable

### Contract
```swift
public protocol IntentAPI: Sendable {
    func submitIntent(_ intent: Intent) async throws -> IntentResponse
    func queryState() async throws -> RuntimeSnapshot
}
```

### What It Is
The sole entry point for UI/host layers into the runtime kernel.

### Guarantees
- ✅ Thread-safe (Sendable types)
- ✅ Async-capable (supports concurrent calls)
- ✅ Typed responses (IntentResponse + RuntimeSnapshot)
- ✅ Error propagation (throws on failure)

### What It Is NOT
- ❌ Direct planner access
- ❌ State mutation interface
- ❌ Executor interface

### Usage
```swift
let response = try await intentAPI.submitIntent(intent)
let snapshot = try await intentAPI.queryState()
```

### Backward Compatibility
- **v1.0**: submitIntent, queryState
- **v1.1+**: New methods added without breaking existing ones

### Breaking Changes (Never in v1.x)
- Removing methods
- Changing method signatures
- Changing return types

---

## 2. AutomationHost (System Automation Boundary)

**Location**: `Sources/OracleOS/HostAutomation/AutomationHost.swift`
**Version**: 1.0
**Stability**: Stable

### Contract
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

### Services
1. **ApplicationServicing**: Application management
2. **WindowServicing**: Window operations
3. **MenuServicing**: Menu interactions
4. **DialogServicing**: Dialog handling
5. **ProcessService**: Process management
6. **CaptureServicing**: Screen capture
7. **SnapshotService**: System snapshots
8. **PermissionService**: Permission checks

### Guarantees
- ✅ MainActor isolated
- ✅ Services individually serviceable (can be mocked)
- ✅ Stable live() factory
- ✅ No state mutation across calls

### Backward Compatibility
- **v1.0**: All 8 services
- **v1.1+**: New services added (new properties)
- **Never**: Removing existing services

---

## 3. BrowserController (Browser Automation Boundary)

**Location**: `Sources/OracleOS/Browser/Automation/BrowserController.swift`
**Version**: 1.0
**Stability**: Stable

### Contract
```swift
@MainActor
public final class BrowserController {
    public func snapshot(appName: String?, observation: Observation) -> PageSnapshot?
    public func isBrowserApp(_ appName: String?) -> Bool
}
```

### Methods
- **snapshot()**: Capture current browser page state
- **isBrowserApp()**: Identify if app is a browser

### Supported Browsers
- Chrome
- Safari
- Firefox
- Arc

### Guarantees
- ✅ MainActor isolated
- ✅ Optional outputs (snapshot may be nil)
- ✅ Case-insensitive app detection
- ✅ No internal browser manipulation

### Backward Compatibility
- **v1.0**: snapshot, isBrowserApp
- **v1.1+**: New methods for browser automation
- **Never**: Removing existing methods

---

## 4. ProcessAdapter (Command Execution Boundary)

**Location**: `Sources/OracleOS/Execution/ProcessAdapter.swift`
**Version**: 1.0
**Stability**: Stable

### Contract
```swift
public protocol ProcessAdapter: Sendable {
    func execute(_ spec: CommandPayload) throws -> CommandResult
}
```

### Implementations
- **DefaultProcessAdapter**: Actual process execution via system calls
- **MockProcessAdapter**: For testing

### Guarantees
- ✅ Sendable (thread-safe)
- ✅ Synchronous execution
- ✅ Typed payloads and results
- ✅ Error propagation (throws)

### What It Is NOT
- ❌ Async interface (for now)
- ❌ Streaming output
- ❌ Process management (kill, suspend)

### Backward Compatibility
- **v1.0**: execute()
- **v1.1+**: New command types supported
- **v2.0**: Async support if needed

---

## 5. Planner (Planning Boundary)

**Location**: `Sources/OracleOS/Planning/Planner.swift`
**Version**: 1.0
**Stability**: Stable

### Contract
```swift
public protocol Planner: Sendable {
    func plan(intent: Intent, context: PlannerContext) async throws -> Command
}
```

### Guarantees
- ✅ Single entry point
- ✅ Deterministic (same input → same output)
- ✅ Stateless (no mutable state)
- ✅ Type-safe return values
- ✅ Async-capable

### Backward Compatibility
- **v1.0**: plan(intent, context)
- **v1.1+**: New intent domains supported
- **v2.0**: Additional parameters if needed

---

## 6. EventStore (Persistence Boundary)

**Location**: `Sources/OracleOS/Events/EventStore.swift`
**Version**: 1.0
**Stability**: Stable

### Contract
```swift
public protocol EventStore: Sendable {
    func append(_ event: DomainEvent) async throws
    func stream() -> AsyncStream<EventEnvelope>
    func query(predicate: EventPredicate) async throws -> [EventEnvelope]
}
```

### Guarantees
- ✅ Sendable types
- ✅ Async stream interface
- ✅ Query support
- ✅ Durability (persisted to disk)

### Backward Compatibility
- **v1.0**: append, stream, query
- **v1.1+**: New event types supported
- **v2.0**: Query language extensions

---

## 7. MemoryStore (Learning Boundary)

**Location**: `Sources/OracleOS/Planning/Memory/UnifiedMemoryStore.swift`
**Version**: 1.0
**Stability**: Stable

### Contract
```swift
public protocol MemoryStore: Sendable {
    func recordControl(_ control: KnownControl)
    func recordFailure(_ failure: FailurePattern)
    func recordCommandResult(category: String, success: Bool)
    func influence(for context: MemoryQueryContext) -> MemoryInfluence
}
```

### Guarantees
- ✅ Sendable
- ✅ Fire-and-forget recording
- ✅ Query support
- ✅ Multi-tier memory (strategy/execution/pattern)

### Backward Compatibility
- **v1.0**: Core methods
- **v1.1+**: New record types
- **v2.0**: Learning algorithm changes

---

## Contract Testing

Each sidecar contract is verified by tests:

```
Tests/OracleOSTests/API/IntentAPIContractTests.swift
Tests/OracleOSTests/Automation/AutomationHostContractTests.swift
Tests/OracleOSTests/Browser/BrowserControllerContractTests.swift
Tests/OracleOSTests/Execution/ProcessAdapterContractTests.swift
Tests/OracleOSTests/Planning/PlannerContractTests.swift
Tests/OracleOSTests/Events/EventStoreContractTests.swift
Tests/OracleOSTests/Memory/MemoryStoreContractTests.swift
```

Each test suite verifies:
- ✅ Method signatures
- ✅ Return types
- ✅ Error handling
- ✅ Sendable conformance
- ✅ Backward compatibility

---

## Versioning Strategy

### Breaking Change (Major)
- Method removed
- Method signature changed
- Return type changed
- Parameter type changed
- Error type changed

**Action**: Increment major version → v2.0

### Feature Addition (Minor)
- New method added
- New optional parameter
- New return value field
- New command type

**Action**: Increment minor version → v1.1

### Bug Fix (Patch)
- Documentation fix
- Implementation improvement
- Performance optimization
- Non-breaking correction

**Action**: Increment patch version → v1.0.1

---

## Deprecation Policy

### Phase 1: Announcement (Minor version)
Mark deprecated with `@available(*, deprecated, message:)`

### Phase 2: Replacement (Minor version)
Provide new method/protocol with migration guide

### Phase 3: Support (2-3 minor versions)
Continue supporting deprecated interface

### Phase 4: Removal (Major version)
Remove deprecated interface

**Example**:
- v1.0: oldMethod()
- v1.1: oldMethod() marked deprecated, newMethod() added
- v1.2-1.4: Both supported
- v2.0: oldMethod() removed

---

## Contract Violations

These would be breaking changes:

```swift
// ❌ Removing method
- func snapshot(appName: String?, observation: Observation) -> PageSnapshot?

// ❌ Changing return type
- func plan(...) -> Command
+ func plan(...) -> Plan

// ❌ Adding required parameter
- func submitIntent(_ intent: Intent) async throws
+ func submitIntent(_ intent: Intent, config: Config) async throws

// ❌ Removing Sendable conformance
- public struct Result: Sendable
+ public struct Result

// ❌ Changing error behavior
- func execute() throws
+ func execute() // no longer throws
```

---

## Monitoring

Contract compliance is verified by:

1. **Compile-time**: Type system enforces signatures
2. **CI Automation**: Contract tests run on every commit
3. **Tests**: Sidecar contract tests verify stability
4. **Documentation**: This document tracks versions

---

## Future Contracts (Phase 7+)

- **GUIBridge**: UI framework communication
- **PersistenceAdapter**: Database abstraction
- **NetworkService**: External API calls
- **LLMInterface**: Language model integration

---

## Related

- **Phase 6**: Seal sidecar contracts (this phase)
- **Phase 7**: Internal restructuring
- **Phase 8**: CI proof hardening
- **Planner.swift**: `Sources/OracleOS/Planning/Planner.swift`
- **IntentAPI.swift**: `Sources/OracleOS/API/IntentAPI.swift`
