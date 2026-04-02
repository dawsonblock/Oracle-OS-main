import XCTest
@testable import OracleOS

/// Performance Profiling Framework
/// Instruments for measuring latency, throughput, and resource efficiency
/// across all critical paths.
///
/// Usage:
/// ```swift
/// let profiler = PerformanceProfiler()
/// let measurement = try await profiler.measureAsync {
///     try await planner.plan(intent, context)
/// }
/// print(measurement.report())
/// ```
final class PerformanceProfilingTests: XCTestCase {
    
    // MARK: - Framework Types
    
    struct PerformanceMetric: Sendable {
        let name: String
        let latencyMs: Double
        let memoryDeltaBytes: Int
        let cpuTime: Double
        let timestamp: Date
    }
    
    struct PerformanceMeasurement: Sendable {
        let name: String
        let metrics: [PerformanceMetric]
        
        var meanLatency: Double {
            guard !metrics.isEmpty else { return 0 }
            return metrics.map { $0.latencyMs }.reduce(0, +) / Double(metrics.count)
        }
        
        var p95Latency: Double {
            let sorted = metrics.map { $0.latencyMs }.sorted()
            guard !sorted.isEmpty else { return 0 }
            let index = Int(Double(sorted.count) * 0.95)
            return sorted[min(index, sorted.count - 1)]
        }
        
        var p99Latency: Double {
            let sorted = metrics.map { $0.latencyMs }.sorted()
            guard !sorted.isEmpty else { return 0 }
            let index = Int(Double(sorted.count) * 0.99)
            return sorted[min(index, sorted.count - 1)]
        }
        
        var maxLatency: Double {
            metrics.map { $0.latencyMs }.max() ?? 0
        }
        
        var totalMemory: Int {
            metrics.map { $0.memoryDeltaBytes }.reduce(0, +)
        }
        
        func report() -> String {
            """
            Performance Report: \(name)
            ================================
            Samples: \(metrics.count)
            Mean Latency: \(String(format: "%.2f", meanLatency))ms
            P95 Latency: \(String(format: "%.2f", p95Latency))ms
            P99 Latency: \(String(format: "%.2f", p99Latency))ms
            Max Latency: \(String(format: "%.2f", maxLatency))ms
            Total Memory Used: \(totalMemory / 1024)KB
            """
        }
    }
    
    class PerformanceProfiler {
        private var metrics: [String: [PerformanceMetric]] = [:]
        
        func measureAsync<T>(
            name: String = "unnamed",
            iterations: Int = 1,
            _ block: @escaping () async throws -> T
        ) async throws -> (result: T, measurement: PerformanceMeasurement) {
            var result: T?
            var lastMetric: PerformanceMetric?
            
            for _ in 0..<iterations {
                let memBefore = try getMemoryUsage()
                let cpuBefore = getThreadCPUTime()
                let startTime = Date()
                
                result = try await block()
                
                let elapsed = Date().timeIntervalSince(startTime) * 1000
                let cpuTime = getThreadCPUTime() - cpuBefore
                let memAfter = try getMemoryUsage()
                let memDelta = memAfter - memBefore
                
                let metric = PerformanceMetric(
                    name: name,
                    latencyMs: elapsed,
                    memoryDeltaBytes: memDelta,
                    cpuTime: cpuTime,
                    timestamp: Date()
                )
                
                if metrics[name] == nil {
                    metrics[name] = []
                }
                metrics[name]?.append(metric)
                lastMetric = metric
            }
            
            let measurement = PerformanceMeasurement(
                name: name,
                metrics: metrics[name] ?? []
            )
            
            return (result: result!, measurement: measurement)
        }
        
        private func getMemoryUsage() throws -> Int {
            var info = task_vm_info_data_t()
            var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size)/4
            
            let kerr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(
                        mach_task_self_,
                        task_flavor_t(TASK_VM_INFO),
                        $0,
                        &count
                    )
                }
            }
            
            guard kerr == KERN_SUCCESS else {
                throw NSError(domain: "Memory", code: -1)
            }
            return Int(info.phys_footprint)
        }
        
        private func getThreadCPUTime() -> Double {
            var info = thread_extended_info_data_t()
            var count = mach_msg_type_number_t(THREAD_EXTENDED_INFO_COUNT)
            
            thread_info(
                mach_thread_self(),
                thread_flavor_t(THREAD_EXTENDED_INFO),
                &info,
                &count
            )
            
            return Double(info.tei_user_time) + Double(info.tei_system_time)
        }
    }
    
    // MARK: - Profiling Tests
    
    /// Test 1: Profile planner latency across domains
    func testPlannerLatencyProfile() async throws {
        let config = RuntimeConfig.testing()
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        let profiler = PerformanceProfiler()
        
        let domains: [IntentDomain] = [.ui, .code, .system]
        
        for domain in domains {
            let intent = Intent(
                id: UUID(),
                domain: domain,
                objective: "profile test for \(domain)",
                metadata: [:]
            )
            
            let context = PlannerContext(
                state: WorldStateModel.empty(),
                memories: [],
                repositorySnapshot: nil
            )
            
            let (_, measurement) = try await profiler.measureAsync(
                name: "planner_\(domain)",
                iterations: 50
            ) {
                try await runtime.plan(intent: intent, context: context)
            }
            
            // Log results
            print("\n" + measurement.report())
            
            // Verify SLAs
            XCTAssertLessThan(measurement.p95Latency, 100,
                "P95 latency for \(domain) should be < 100ms")
            XCTAssertLessThan(measurement.p99Latency, 200,
                "P99 latency for \(domain) should be < 200ms")
        }
    }
    
    /// Test 2: Profile memory efficiency of command execution
    func testCommandExecutionMemoryProfile() async throws {
        let config = RuntimeConfig.testing()
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        let profiler = PerformanceProfiler()
        
        // Test with various command payloads
        let commands = [
            ("ui", Intent(id: UUID(), domain: .ui, objective: "click", metadata: [:])),
            ("code", Intent(id: UUID(), domain: .code, objective: "search", metadata: [:])),
            ("system", Intent(id: UUID(), domain: .system, objective: "launch", metadata: [:])),
        ]
        
        for (name, intent) in commands {
            let context = PlannerContext(
                state: WorldStateModel.empty(),
                memories: [],
                repositorySnapshot: nil
            )
            
            let (_, measurement) = try await profiler.measureAsync(
                name: "execution_\(name)",
                iterations: 100
            ) {
                try await runtime.plan(intent: intent, context: context)
            }
            
            print("\n" + measurement.report())
            
            // Memory should be bounded
            let avgMemory = measurement.totalMemory / measurement.metrics.count
            XCTAssertLessThan(avgMemory, 5_000_000, // 5MB per operation
                "Average memory per operation should be < 5MB")
        }
    }
    
    /// Test 3: Profile throughput under sustained load
    func testThroughputProfile() async throws {
        let config = RuntimeConfig.testing()
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        
        let startTime = Date()
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "throughput test",
            metadata: [:]
        )
        let context = PlannerContext(
            state: WorldStateModel.empty(),
            memories: [],
            repositorySnapshot: nil
        )
        
        var completedCount = 0
        let durationTarget = 10.0 // seconds
        
        while Date().timeIntervalSince(startTime) < durationTarget {
            do {
                _ = try await runtime.plan(intent: intent, context: context)
                completedCount += 1
            } catch {
                break
            }
        }
        
        let actualDuration = Date().timeIntervalSince(startTime)
        let throughput = Double(completedCount) / actualDuration
        
        print("\nThroughput Profile")
        print("==================")
        print("Duration: \(String(format: "%.2f", actualDuration))s")
        print("Completed: \(completedCount)")
        print("Throughput: \(String(format: "%.1f", throughput)) ops/sec")
        
        // Throughput SLA: at least 10 ops/sec
        XCTAssertGreaterThanOrEqual(throughput, 10,
            "Throughput should be at least 10 ops/sec")
    }
    
    /// Test 4: Profile tail latency (p99, p99.9)
    func testTailLatencyProfile() async throws {
        let config = RuntimeConfig.testing()
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        let profiler = PerformanceProfiler()
        
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "tail latency test",
            metadata: [:]
        )
        let context = PlannerContext(
            state: WorldStateModel.empty(),
            memories: [],
            repositorySnapshot: nil
        )
        
        let (_, measurement) = try await profiler.measureAsync(
            name: "tail_latency",
            iterations: 500
        ) {
            try await runtime.plan(intent: intent, context: context)
        }
        
        print("\nTail Latency Profile")
        print("====================")
        print("P50: \(String(format: "%.2f", measurement.metrics[measurement.metrics.count / 2].latencyMs))ms")
        print("P95: \(String(format: "%.2f", measurement.p95Latency))ms")
        print("P99: \(String(format: "%.2f", measurement.p99Latency))ms")
        print("P99.9: \(String(format: "%.2f", measurement.maxLatency))ms")
        
        // Tail latency SLAs
        XCTAssertLessThan(measurement.p99Latency, 500,
            "P99 latency should be < 500ms")
        XCTAssertLessThan(measurement.maxLatency, 1000,
            "Max latency should be < 1000ms")
    }
    
    /// Test 5: Profile concurrent request handling
    func testConcurrentRequestProfile() async throws {
        let config = RuntimeConfig.testing()
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        
        let concurrency = 50
        let iterations = 10
        
        var allMetrics: [Double] = []
        
        for _ in 0..<iterations {
            let startTime = Date()
            
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<concurrency {
                    group.addTask {
                        let intent = Intent(
                            id: UUID(),
                            domain: i % 2 == 0 ? .ui : .code,
                            objective: "concurrent test \(i)",
                            metadata: [:]
                        )
                        
                        let context = PlannerContext(
                            state: WorldStateModel.empty(),
                            memories: [],
                            repositorySnapshot: nil
                        )
                        
                        _ = try? await runtime.plan(intent: intent, context: context)
                    }
                }
            }
            
            let elapsed = Date().timeIntervalSince(startTime) * 1000
            allMetrics.append(elapsed)
        }
        
        let avgTime = allMetrics.reduce(0, +) / Double(allMetrics.count)
        let throughput = Double(concurrency) / (avgTime / 1000)
        
        print("\nConcurrent Request Profile")
        print("==========================")
        print("Concurrency: \(concurrency)")
        print("Avg Time per Batch: \(String(format: "%.2f", avgTime))ms")
        print("Throughput: \(String(format: "%.1f", throughput)) ops/sec")
        
        XCTAssertGreaterThanOrEqual(throughput, 50,
            "Concurrent throughput should be ≥ 50 ops/sec")
    }
}
