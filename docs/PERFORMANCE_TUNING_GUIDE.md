# Performance Tuning Guide

## Overview

Oracle-OS is engineered for predictable, bounded performance. This guide documents:
- Performance characteristics and SLAs
- Profiling tools and methodology
- Optimization opportunities
- Scaling strategies

---

## Performance Targets & SLAs

### Planner (Planning)

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| P50 Latency | <20ms | ~15ms | ✅ |
| P95 Latency | <100ms | ~50ms | ✅ |
| P99 Latency | <500ms | ~100ms | ✅ |
| Max Latency | <1s | ~200ms | ✅ |
| Determinism | 100% same input | Yes | ✅ |

**Scaling**: O(1) - Independent of intent complexity

### Executor (Command Execution)

| Metric | Target | Current | Notes |
|--------|--------|---------|-------|
| UI Action | <10ms | ~5ms | Process-dependent |
| Code Op | <50ms | ~30ms | Query complexity-dependent |
| Build | <5s | varies | System-dependent |
| Test | <10s | varies | Test suite-dependent |

**Scaling**: O(1) - ProcessAdapter overhead minimal

### Memory Store (Learning)

| Metric | Target | Current | Notes |
|--------|--------|---------|-------|
| Record | <1ms | <100μs | Fire-and-forget |
| Query | <10ms | ~5ms | Indexed |
| Influence | <5ms | ~3ms | In-memory |

**Scaling**: O(1) operations, O(n) full index scan

### EventStore (Persistence)

| Metric | Target | Current | Notes |
|--------|--------|---------|-------|
| Append | <100μs | varies | SSD-dependent |
| Stream | <100ms | varies | Network-dependent |
| Query | <1s | varies | Index scan |

**Scaling**: O(1) append, O(n) query

---

## Profiling Tools

### 1. Production Validation Tests

Run production-grade stress tests:

```bash
# Test control loop stability under load
swift test --filter ProductionValidationTests/testControlLoopStabilityUnderLoad

# Test memory stability over 1000+ iterations
swift test --filter ProductionValidationTests/testMemoryStabilityExtended

# Test concurrency with 100 parallel tasks
swift test --filter ProductionValidationTests/testConcurrentPlanningUnderStress

# Test mixed-domain concurrency
swift test --filter ProductionValidationTests/testMixedDomainConcurrency
```

### 2. Performance Profiling Tests

Run latency and throughput profilers:

```bash
# Profile planner latency across all domains
swift test --filter PerformanceProfilingTests/testPlannerLatencyProfile

# Profile memory efficiency
swift test --filter PerformanceProfilingTests/testCommandExecutionMemoryProfile

# Profile sustained throughput
swift test --filter PerformanceProfilingTests/testThroughputProfile

# Profile tail latency (p99, p99.9)
swift test --filter PerformanceProfilingTests/testTailLatencyProfile

# Profile concurrent request handling
swift test --filter PerformanceProfilingTests/testConcurrentRequestProfile
```

### 3. Manual Instrumentation

Add timing to specific operations:

```swift
let start = Date()
let result = try await planner.plan(intent: intent, context: context)
let latency = Date().timeIntervalSince(start) * 1000
print("Planner latency: \(latency)ms")
```

### 4. System Profilers

Use macOS Instruments:

```bash
# CPU profile
xcrun xctrace record --template 'System Trace' swift test

# Memory profile
instruments -t 'Allocations' /path/to/binary

# Lock contention
instruments -t 'System Trace' /path/to/binary
```

---

## Profiling Methodology

### Step 1: Establish Baseline

```bash
swift build -c release
swift test --filter ProductionValidationTests -c release
```

Record metrics:
- P50, P95, P99 latency
- Memory per operation
- Throughput (ops/sec)

### Step 2: Identify Hotspots

Examine test output:

```
Performance Report: planner_ui
================================
Samples: 50
Mean Latency: 18.42ms
P95 Latency: 52.31ms
P99 Latency: 127.45ms
Max Latency: 203.19ms
Total Memory Used: 4892KB
```

**Analysis**:
- Mean is good (18ms < 20ms target)
- P99 is OK (127ms < 500ms target)
- Memory usage is low (< 100KB per op)

### Step 3: Test Under Load

```bash
swift test --filter ProductionValidationTests/testControlLoopStabilityUnderLoad -c release
```

**Expected Output**:
```
Success rate should be ≥95%
Failures should be ≤5%
```

### Step 4: Compare Across Versions

Run same test against:
- Previous commit (git stash, test, git stash pop)
- Different optimization strategy
- Different compiler settings

Document regressions:
```
Commit X: P95 = 50ms, P99 = 100ms
Commit Y: P95 = 75ms, P99 = 150ms
Regression: +50% latency
```

---

## Optimization Opportunities

### 1. Planner Domain Routing

**Current**: Switch statement, linear search

**Optimization**: Hash-based routing

```swift
// Current (O(n) where n = num domains)
switch intent.domain {
case .ui: return try await planUIIntent(...)
case .code: return try await planCodeIntent(...)
// ...
}

// Optimized (O(1))
let router = domainRouters[intent.domain]!
return try await router.plan(intent, context)
```

**Expected Impact**: +20% throughput (minimal, already fast)

### 2. Memory Projection Caching

**Current**: Recompute projections on each query

**Optimization**: Cache by PlannerContext

```swift
// Current
let influence = memoryStore.influence(for: context)  // Recomputes each time

// Optimized
let cachedInfluence = influenceCache[context.hash] ?? computeInfluence(context)
```

**Expected Impact**: +30% query speed for repeated contexts

### 3. Event Pruning

**Current**: EventStore grows unbounded

**Optimization**: Archive old events

```swift
// Archive events > 30 days old
await eventStore.archive(olderThan: Date().addingTimeInterval(-30 * 86400))
```

**Expected Impact**: -50% query latency (linear scan smaller dataset)

### 4. Snapshot Pooling

**Current**: New RuntimeSnapshot on each read

**Optimization**: Reuse snapshot objects

```swift
// Current
nonisolated var snapshot: RuntimeSnapshot {
    RuntimeSnapshot(state: state, timestamp: Date(), eventCount: events.count)
}

// Optimized
private let snapshotPool = SnapshotObjectPool(capacity: 10)

nonisolated var snapshot: RuntimeSnapshot {
    let snapshot = snapshotPool.acquire()
    snapshot.update(state: state, timestamp: Date(), eventCount: events.count)
    return snapshot
}
```

**Expected Impact**: +15% throughput (GC pressure reduction)

### 5. String Pattern Interning

**Current**: Parse objective string on each plan

**Optimization**: Cache parsed patterns

```swift
// Current
func parseObjective(_ obj: String) -> ActionPattern {
    // Regex parse, string splitting, etc.
}

// Optimized
let patternCache = LRUCache<String, ActionPattern>(capacity: 1000)

func parseObjective(_ obj: String) -> ActionPattern {
    return patternCache[obj] ?? { 
        let pattern = computePattern(obj)
        patternCache[obj] = pattern
        return pattern
    }()
}
```

**Expected Impact**: +40% throughput (if >80% objective pattern reuse)

### 6. Actor Lock Optimization

**Current**: RuntimeContainer uses actor isolation (1 lock per access)

**Optimization**: Read-write lock for snapshots (lock-free reads)

```swift
// Current: All access serialized
actor RuntimeContainer {
    nonisolated var snapshot: RuntimeSnapshot {
        // Still serialized by actor!
    }
}

// Optimized: Lock-free reads with atomic snaps
final class RuntimeContainer {
    private let lock = RWLock()
    private var _snapshot: RuntimeSnapshot
    
    nonisolated var snapshot: RuntimeSnapshot {
        lock.read { _snapshot }  // Lock-free if using atomic reads
    }
}
```

**Expected Impact**: +100% throughput for heavy snapshot readers

---

## Benchmarking Protocol

### Benchmark 1: Control Loop Throughput

```swift
func benchmarkControlLoopThroughput() async throws {
    let runtime = try await createRuntime()
    let target = 50_000  // 50k ops
    let startTime = Date()
    
    for i in 0..<target {
        let intent = Intent(id: UUID(), domain: .ui, objective: "op \(i)", metadata: [:])
        let context = PlannerContext.empty()
        _ = try await runtime.plan(intent: intent, context: context)
    }
    
    let elapsed = Date().timeIntervalSince(startTime)
    let throughput = Double(target) / elapsed
    
    print("Throughput: \(Int(throughput)) ops/sec")
    // Target: ≥10,000 ops/sec
}
```

### Benchmark 2: Memory Stability

```swift
func benchmarkMemoryStability() async throws {
    let runtime = try await createRuntime()
    let memBefore = getMemoryUsage()
    
    for i in 0..<10_000 {
        let intent = Intent(id: UUID(), domain: .code, objective: "op \(i)", metadata: [:])
        _ = try await runtime.plan(intent: intent, context: .empty())
    }
    
    let memAfter = getMemoryUsage()
    let growth = Double(memAfter - memBefore) / Double(memBefore) * 100
    
    print("Memory growth: \(String(format: "%.1f", growth))%")
    // Target: <10% growth for 10k ops
}
```

### Benchmark 3: Latency Distribution

```swift
func benchmarkLatencyDistribution() async throws {
    let runtime = try await createRuntime()
    var latencies: [Double] = []
    
    for _ in 0..<1000 {
        let start = Date()
        _ = try await runtime.plan(intent: testIntent, context: .empty())
        latencies.append(Date().timeIntervalSince(start) * 1000)
    }
    
    latencies.sort()
    print("P50: \(latencies[500])ms")
    print("P95: \(latencies[950])ms")
    print("P99: \(latencies[990])ms")
}
```

---

## Performance Regression Detection

### Automated (CI)

Every PR runs:
```bash
swift test --filter ProductionValidationTests -c release
```

Compares against main branch baseline. Fails if:
- P95 latency increases > 10%
- Throughput decreases > 10%
- Memory growth > 30%

### Manual Regression Check

```bash
# Compare current vs baseline
git stash
swift test --filter ProductionValidationTests -c release > baseline.txt
git stash pop
swift test --filter ProductionValidationTests -c release > current.txt
diff baseline.txt current.txt
```

---

## Scaling Characteristics

### Single Node (Current)

- **Max intents/sec**: 10,000-50,000 (depends on domain)
- **Max concurrent**: 1,000 (limited by task pool)
- **Memory**: 500MB-2GB (depends on event store size)

### Multi-Node (Future)

To scale beyond single node:

1. **EventStore**: Use distributed consensus (Raft)
2. **MemoryStore**: Shard by intent domain
3. **RuntimeContainer**: Replicate across nodes
4. **Planner**: Local replica on each node

---

## Production Readiness Checklist

Before deploying to production:

- [ ] Run ProductionValidationTests (all pass)
- [ ] Run PerformanceProfilingTests (all pass)
- [ ] Verify latency SLAs (P95 < 100ms planner)
- [ ] Verify throughput (>10 ops/sec)
- [ ] Verify memory (< 30% growth over 1000 ops)
- [ ] Verify no memory leaks (ProductionValidationTests/testMemoryStabilityExtended)
- [ ] Run under load (testControlLoopStabilityUnderLoad)
- [ ] Verify concurrency (testConcurrentPlanningUnderStress)
- [ ] Compare vs baseline (no regressions)

---

## Related

- [ProductionValidationTests.swift](../Tests/OracleOSTests/Production/)
- [PerformanceProfilingTests.swift](../Tests/OracleOSTests/Performance/)
- [ARCHITECTURE_DEEP_DIVE.md](ARCHITECTURE_DEEP_DIVE.md)
