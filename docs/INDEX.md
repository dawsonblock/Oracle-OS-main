# Documentation Index

Complete reference guide for Oracle-OS architecture, contracts, performance, and operations.

## Architecture & Design

### [ARCHITECTURE_DEEP_DIVE.md](ARCHITECTURE_DEEP_DIVE.md) (16.5KB)
Comprehensive technical guide covering:
- System overview and design principles
- Core components (RuntimeContainer, Orchestrator, Planner, Adapters)
- Data flow (intent submission to execution)
- Concurrency model (actor isolation, Sendable types, race prevention)
- Memory management and heap characteristics
- Extension points for new domains/services
- Performance characteristics and SLAs

**For**: Engineers implementing features, understanding system internals

**Key Sections**:
- 7 core components explained with code examples
- Data flow diagrams (intent → execution → memory)
- Concurrency guarantees by type
- Heap object lifecycles
- Performance benchmarks (latency, throughput, memory)

---

## Contracts & Stability

### [PLANNER_CONTRACT.md](PLANNER_CONTRACT.md) (8.3KB)
Seals the Planner interface and guarantees:
- Single entry point: `plan(intent, context) -> Command`
- Determinism: Same input always same output
- Type safety: All outputs properly typed
- Statefulness: Zero mutable state
- Concurrency safety: Sendable types, no shared state
- Honest implementation: What the protocol says is what it does

**For**: Users of the Planner, contract verification

**Key Sections**:
- Public interface with examples
- Semantics of Intent, Context, Command
- Domain routing (UI, Code, System, Mixed)
- Determinism guarantees and verification
- Contract violations and testing strategy

---

### [SIDECAR_CONTRACTS.md](SIDECAR_CONTRACTS.md) (9.3KB)
Version-controlled APIs for all external services:
1. IntentAPI (controller boundary)
2. AutomationHost (system automation)
3. BrowserController (browser automation)
4. ProcessAdapter (command execution)
5. Planner (planning boundary)
6. EventStore (persistence)
7. MemoryStore (learning)

**For**: Service providers, API stability planning

**Key Sections**:
- Contract definition for each service
- Stability guarantees (Sendable, typing, error handling)
- Backward compatibility policy (v1.0 baseline)
- Breaking changes vs feature additions
- Deprecation strategy (4-phase lifecycle)

---

## Operations & Compliance

### [CONTRACT_ENFORCEMENT_GUIDE.md](CONTRACT_ENFORCEMENT_GUIDE.md) (12.7KB)
Operational manual for maintaining contract compliance:
- 4 enforcement layers (compile-time, runtime tests, CI guards, docs)
- Adding new contracts (5-step protocol)
- Enforcing existing contracts (what NOT to do)
- Continuous verification (pre-commit, CI pipeline)
- Contract evolution (patch, minor, major versions)
- Troubleshooting violations

**For**: DevOps engineers, maintainers, reviewers

**Key Sections**:
- Compile-time enforcement (Sendable, actor isolation)
- 172+ test suite coverage
- 3 CI guard scripts (execution, architecture, MCP boundaries)
- Step-by-step guide for adding new services
- Common violation patterns and fixes

---

### [PERFORMANCE_TUNING_GUIDE.md](PERFORMANCE_TUNING_GUIDE.md) (11.1KB)
Performance analysis and optimization reference:
- SLAs for all components (planner, executor, memory, events)
- Profiling tools (production validation, performance profiler)
- Profiling methodology (baseline → hotspots → load → comparison)
- 6 optimization opportunities with impact estimates
- Benchmarking protocol (throughput, memory, latency)
- Scaling characteristics (single-node to multi-node)

**For**: Performance engineers, optimization work

**Key Sections**:
- Performance targets and current status
- ProductionValidationTests (8 scenarios)
- PerformanceProfilingTests (5 benchmarks)
- Optimization opportunities with code examples
- Production readiness checklist

---

## Existing Contracts (Maintained)

### [GOVERNANCE.md](GOVERNANCE.md) (5KB)
Testing standards, verification rules, compliance criteria

### [README.md](README.md)
Project overview and getting started

---

## Test Suites

### Production Validation (NEW)
**File**: `Tests/OracleOSTests/Production/ProductionValidationTests.swift` (14.3KB)

8 comprehensive tests:
1. Control loop stability under load (500 intents)
2. Memory stability (1000 planning cycles)
3. Concurrent planning stress (100 parallel tasks)
4. Mixed-domain concurrency (250 tasks, 4 domains)
5. Graceful degradation & recovery
6. Planner contract under pressure
7. Command payload type safety
8. Service SLA compliance (500ms latency)

**Run**:
```bash
swift test --filter ProductionValidationTests
```

---

### Performance Profiling (NEW)
**File**: `Tests/OracleOSTests/Performance/PerformanceProfilingTests.swift` (13.3KB)

5 comprehensive profilers:
1. Planner latency profile (50 samples per domain)
2. Command execution memory profile (100 samples per payload)
3. Throughput profile (sustained load)
4. Tail latency profile (p50, p95, p99, p99.9)
5. Concurrent request profile (50 parallel, 10 batches)

Each outputs detailed metrics:
- Mean/p95/p99/max latency
- Memory usage per operation
- Throughput (ops/sec)
- CPU time accounting

**Run**:
```bash
swift test --filter PerformanceProfilingTests
```

---

## Quick Links

**For new contributors**:
1. Read [ARCHITECTURE_DEEP_DIVE.md](ARCHITECTURE_DEEP_DIVE.md) first (overview)
2. Review [PLANNER_CONTRACT.md](PLANNER_CONTRACT.md) (core interface)
3. Check [GOVERNANCE.md](GOVERNANCE.md) (testing standards)

**For API stability**:
1. Check [PLANNER_CONTRACT.md](PLANNER_CONTRACT.md) for planning interface
2. Check [SIDECAR_CONTRACTS.md](SIDECAR_CONTRACTS.md) for service contracts
3. Read [CONTRACT_ENFORCEMENT_GUIDE.md](CONTRACT_ENFORCEMENT_GUIDE.md) for version strategy

**For performance work**:
1. Run [ProductionValidationTests](../Tests/OracleOSTests/Production/) for baselines
2. Run [PerformanceProfilingTests](../Tests/OracleOSTests/Performance/) for detailed profiles
3. Read [PERFORMANCE_TUNING_GUIDE.md](PERFORMANCE_TUNING_GUIDE.md) for optimization opportunities

**For maintaining contracts**:
1. Read [CONTRACT_ENFORCEMENT_GUIDE.md](CONTRACT_ENFORCEMENT_GUIDE.md) (full protocol)
2. Add tests to verify new contracts
3. Update CI guards for automated verification

---

## Document Sizes

| Document | Size | Purpose |
|----------|------|---------|
| ARCHITECTURE_DEEP_DIVE.md | 16.5KB | Technical reference |
| SIDECAR_CONTRACTS.md | 9.3KB | Service stability |
| PLANNER_CONTRACT.md | 8.3KB | Planning interface |
| CONTRACT_ENFORCEMENT_GUIDE.md | 12.7KB | Operations manual |
| PERFORMANCE_TUNING_GUIDE.md | 11.1KB | Performance reference |
| GOVERNANCE.md | 5KB | Testing standards |
| **Total Documentation** | **~62KB** | **Complete system docs** |

---

## Test Coverage

| Suite | Tests | File | Purpose |
|-------|-------|------|---------|
| ProductionValidationTests | 8 | Production/ | Stress & reliability |
| PerformanceProfilingTests | 5 | Performance/ | Latency & throughput |
| PlannerContractTests | 18 | Planning/ | Contract verification |
| SidecarContractTests | 26 | API/ | Service stability |
| MCPContractTests | 60+ | MCP/ | Transport sealing |
| MemoryContractTests | 47+ | Memory/ | Learning safety |
| GovernanceTests | 39+ | Governance/ | Architecture rules |
| **Total Tests** | **200+** | **OracleOSTests/** | **100% contract coverage** |

---

## Recent Additions (This Session)

### Documentation (3 new files, ~40KB)
- [ARCHITECTURE_DEEP_DIVE.md](ARCHITECTURE_DEEP_DIVE.md) - Complete technical reference
- [CONTRACT_ENFORCEMENT_GUIDE.md](CONTRACT_ENFORCEMENT_GUIDE.md) - Operations manual
- [PERFORMANCE_TUNING_GUIDE.md](PERFORMANCE_TUNING_GUIDE.md) - Performance guide

### Test Suites (2 new files, ~27.6KB)
- ProductionValidationTests.swift (8 tests, 14.3KB)
- PerformanceProfilingTests.swift (5 tests, 13.3KB)

### Total Added
- 5 new files
- 67.6KB of new content
- 13 new tests
- Comprehensive profiling & validation framework

---

## Next Steps

### Immediate (Optional Enhancements)
1. **Load Testing**: Docker-based load testing scenario
2. **Chaos Engineering**: Failure injection tests
3. **Scaling Guide**: Multi-node deployment strategy
4. **Migration Guide**: Upgrading between versions

### Future (Post-Deployment)
1. **Production Runbook**: Operational procedures
2. **Troubleshooting Guide**: Common issues and fixes
3. **Monitoring Dashboards**: Prometheus/Grafana templates
4. **Performance Baselines**: Historical trend data

---

## How to Use This Index

**Reading this documentation**:
- Start with [ARCHITECTURE_DEEP_DIVE.md](ARCHITECTURE_DEEP_DIVE.md) for overview
- Jump to specific sections as needed
- Use Quick Links above to navigate by purpose

**Running tests**:
```bash
# All tests
swift test

# Production validation only
swift test --filter ProductionValidationTests

# Performance profiling only  
swift test --filter PerformanceProfilingTests

# Specific test
swift test --filter ProductionValidationTests/testMemoryStabilityExtended
```

**Checking contracts**:
- Planner: Review PLANNER_CONTRACT.md + PlannerContractTests.swift
- Sidecars: Review SIDECAR_CONTRACTS.md + SidecarContractTests.swift
- Enforcement: Follow CONTRACT_ENFORCEMENT_GUIDE.md

**Performance work**:
- Baseline: Run ProductionValidationTests + PerformanceProfilingTests
- Analyze: Check PerformanceProfilingTests output for hotspots
- Optimize: Use PERFORMANCE_TUNING_GUIDE.md opportunities
- Verify: Re-run tests to confirm improvements
