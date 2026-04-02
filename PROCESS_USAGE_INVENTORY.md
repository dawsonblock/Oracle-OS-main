# Phase 2.1 — Process() Usage Inventory

## Classification

### RUNTIME PATH (Execution-governed)
**File**: Sources/OracleOS/Execution/DefaultProcessAdapter.swift
- Line: Multiple locations
- **Status**: ✅ CORRECT — This is the ONLY place Process() should be created for runtime execution
- **Reason**: DefaultProcessAdapter is the execution router gate. All command execution funnels through here.
- **Authority**: VerifiedExecutor → CommandRouter → DomainRouter → DefaultProcessAdapter → Process()

**File**: Sources/OracleOS/Execution/DefaultProcessAdapter+Daemon.swift
- Line: Multiple locations
- **Status**: ✅ CORRECT — Daemon spawning for background tasks
- **Reason**: Still part of execution routing infrastructure
- **Authority**: Same as above

### TOOLING PATH (Setup/Diagnostics)
**File**: Sources/oracle/SetupWizard.swift
- Lines: 756, 776
- **Status**: ✅ CORRECT — These are setup/initialization flows, not runtime execution
- **Reason**: SetupWizard is explicit tooling, not the runtime kernel
- **Classification**: TOOLING_ONLY_DIRECT_PROCESS

**File**: Sources/oracle/Doctor.swift
- Line: 384
- **Status**: ✅ CORRECT — Diagnostics flow, not runtime execution
- **Reason**: Doctor is explicit diagnostic tooling
- **Classification**: TOOLING_ONLY_DIRECT_PROCESS

### TEST CODE (Mock Adapters)
**File**: Tests/OracleOSTests/Core/DigitalEngineerLayerTests.swift
- Line: Process()
- **Status**: ✅ CORRECT — Test mock infrastructure
- **Reason**: Used in test doubles only, not production code

### OTHER
**File**: Tests/OracleOSTests/Governance/ArchitectureFreezeTests.swift
- **Status**: ✅ CORRECT — Governance test checking for forbidden Process()
- **Note**: Test asserts that certain modules should NOT contain Process()

**File**: Tests/OracleOSTests/Governance/PlannerBoundaryTests.swift
- **Status**: ✅ CORRECT — Governance test verifying planner isolation
- **Note**: Test asserts planner should not spawn processes

**File**: Tests/OracleOSTests/Governance/RuntimeInvariantTests.swift
- **Status**: ✅ CORRECT — Governance test for forbidden patterns
- **Note**: Test checks for forbidden process creation patterns

**File**: Sources/OracleOS/ProcessShadow.swift
- **Status**: ✅ CORRECT — Stub/mock Process type
- **Note**: Not real Process, just a placeholder struct

## Summary

### Allowed Process() Usage
1. **DefaultProcessAdapter and extensions** (runtime execution routed through VerifiedExecutor)
2. **SetupWizard** (tooling, explicit TOOLING_ONLY_DIRECT_PROCESS)
3. **Doctor** (tooling, explicit TOOLING_ONLY_DIRECT_PROCESS)
4. **Test doubles** (mock infrastructure)

### Forbidden Process() Usage
- None found in runtime kernel
- None found in planning layer
- None found in state management
- None found in event coordination

## Current State Assessment

✅ **PASS**: No unauthorized direct Process() calls in the runtime execution path
✅ **PASS**: Tooling-only calls are minimal and explicit
✅ **PASS**: All governance tests already check for this

## Next Step: Cluster 2.2

Mark SetupWizard and Doctor calls with explicit TOOLING_ONLY_DIRECT_PROCESS annotation to make isolation visible.
