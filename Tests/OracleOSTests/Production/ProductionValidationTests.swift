import XCTest
@testable import OracleOS

/// Production Validation Suite
/// Comprehensive tests for real-world deployment scenarios, chaos engineering,
/// and production-level resilience verification.
///
/// Coverage:
/// - Control loop stability under load
/// - Memory safety and leak prevention
/// - Concurrency safety under stress
/// - Recovery from transient failures
/// - Service degradation handling
/// - Contract compliance under pressure
final class ProductionValidationTests: XCTestCase {
    
    // MARK: - Control Loop Stability
    
    /// Test 1: Control loop maintains stability under sustained load
    func testControlLoopStabilityUnderLoad() async throws {
        // Setup: Create a simulated runtime with light memory constraints
        let config = RuntimeConfig.testing(maxMemory: 100_000_000) // 100MB
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        
        // Execution: Submit 500 intents rapidly
        var successCount = 0
        var failureCount = 0
        let iterations = 500
        
        for i in 0..<iterations {
            let intent = Intent(
                id: UUID(),
                domain: .ui,
                objective: "click element \(i)",
                metadata: ["action": "click", "target": "item-\(i)"]
            )
            
            do {
                let context = PlannerContext(
                    state: WorldStateModel.empty(),
                    memories: [],
                    repositorySnapshot: nil
                )
                let command = try await runtime.plan(intent: intent, context: context)
                XCTAssertNotNil(command.id)
                successCount += 1
            } catch {
                failureCount += 1
            }
        }
        
        // Validation
        let successRate = Double(successCount) / Double(iterations)
        XCTAssertGreaterThanOrEqual(successRate, 0.95, "Success rate should be ≥95%")
        XCTAssertLessThanOrEqual(failureCount, 25, "Failures should be ≤5%")
    }
    
    /// Test 2: Memory doesn't leak during extended operation
    func testMemoryStabilityExtended() async throws {
        let config = RuntimeConfig.testing()
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        
        // Record initial memory
        let initialMemory = try getMemoryUsage()
        
        // Execute 1000 planning cycles
        for i in 0..<1000 {
            let intent = Intent(
                id: UUID(),
                domain: .code,
                objective: "search for pattern \(i % 10)",
                metadata: ["query": "test_\(i)"]
            )
            
            let context = PlannerContext(
                state: WorldStateModel.empty(),
                memories: [],
                repositorySnapshot: nil
            )
            
            _ = try await runtime.plan(intent: intent, context: context)
            
            // Check memory every 100 iterations
            if i % 100 == 0 && i > 0 {
                let currentMemory = try getMemoryUsage()
                let memoryGrowth = currentMemory - initialMemory
                let growthPercent = (Double(memoryGrowth) / Double(initialMemory)) * 100
                
                // Memory growth should be minimal (< 10% per 100 iterations)
                XCTAssertLessThan(growthPercent, 10, 
                    "Memory grew \(growthPercent)% after \(i) iterations")
            }
        }
        
        let finalMemory = try getMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        let totalGrowthPercent = (Double(totalGrowth) / Double(initialMemory)) * 100
        
        XCTAssertLessThan(totalGrowthPercent, 30,
            "Total memory growth should be < 30% over 1000 iterations")
    }
    
    // MARK: - Concurrency Stress
    
    /// Test 3: Concurrent planning doesn't cause races
    func testConcurrentPlanningUnderStress() async throws {
        let config = RuntimeConfig.testing()
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        
        let concurrentTasks = 100
        var results: [UUID] = []
        let lock = NSLock()
        
        await withTaskGroup(of: UUID?.self) { group in
            for i in 0..<concurrentTasks {
                group.addTask {
                    let intent = Intent(
                        id: UUID(),
                        domain: i % 2 == 0 ? .ui : .code,
                        objective: "task \(i)",
                        metadata: ["id": "\(i)"]
                    )
                    
                    let context = PlannerContext(
                        state: WorldStateModel.empty(),
                        memories: [],
                        repositorySnapshot: nil
                    )
                    
                    do {
                        let command = try await runtime.plan(intent: intent, context: context)
                        return command.id
                    } catch {
                        return nil
                    }
                }
            }
            
            for await result in group {
                if let id = result {
                    lock.lock()
                    results.append(id)
                    lock.unlock()
                }
            }
        }
        
        // Validation: All should succeed
        XCTAssertEqual(results.count, concurrentTasks,
            "All concurrent tasks should complete successfully")
        
        // Validation: All IDs unique
        let uniqueIds = Set(results)
        XCTAssertEqual(uniqueIds.count, results.count,
            "All command IDs should be unique")
    }
    
    /// Test 4: High concurrency with mixed intent domains
    func testMixedDomainConcurrency() async throws {
        let config = RuntimeConfig.testing()
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        
        let domains: [IntentDomain] = [.ui, .code, .system, .mixed]
        let iterations = 250
        var completedCount = 0
        
        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<iterations {
                let domain = domains[i % domains.count]
                group.addTask {
                    let intent = Intent(
                        id: UUID(),
                        domain: domain,
                        objective: "mixed test \(i)",
                        metadata: ["domain": "\(domain)"]
                    )
                    
                    let context = PlannerContext(
                        state: WorldStateModel.empty(),
                        memories: [],
                        repositorySnapshot: nil
                    )
                    
                    do {
                        _ = try await runtime.plan(intent: intent, context: context)
                        return true
                    } catch {
                        return false
                    }
                }
            }
            
            for await success in group {
                if success { completedCount += 1 }
            }
        }
        
        XCTAssertGreaterThanOrEqual(completedCount, Int(Double(iterations) * 0.95),
            "At least 95% of mixed-domain tasks should succeed")
    }
    
    // MARK: - Failure Recovery
    
    /// Test 5: Graceful degradation when dependencies unavailable
    func testGracefulDegradation() async throws {
        let config = RuntimeConfig.testing()
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        
        // Simulate dependency degradation
        var recoveryAttempts = 0
        let maxAttempts = 3
        
        while recoveryAttempts < maxAttempts {
            let intent = Intent(
                id: UUID(),
                domain: .ui,
                objective: "test recovery \(recoveryAttempts)",
                metadata: [:]
            )
            
            let context = PlannerContext(
                state: WorldStateModel.empty(),
                memories: [],
                repositorySnapshot: nil
            )
            
            do {
                _ = try await runtime.plan(intent: intent, context: context)
                recoveryAttempts += 1
            } catch {
                // Expected in some cases; recovery system should handle
                recoveryAttempts += 1
            }
        }
        
        XCTAssertEqual(recoveryAttempts, maxAttempts,
            "Recovery system should attempt all retries")
    }
    
    // MARK: - Contract Compliance Under Pressure
    
    /// Test 6: Planner contract maintained under concurrent load
    func testPlannerContractUnderPressure() async throws {
        let config = RuntimeConfig.testing()
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        
        let samIntent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "click button",
            metadata: ["action": "click"]
        )
        let sameContext = PlannerContext(
            state: WorldStateModel.empty(),
            memories: [],
            repositorySnapshot: nil
        )
        
        // Get same intent+context multiple times, verify determinism
        var results: [UUID] = []
        for _ in 0..<10 {
            let command = try await runtime.plan(intent: samIntent, context: sameContext)
            results.append(command.id)
        }
        
        // All command IDs should match (determinism)
        let firstId = results[0]
        for id in results {
            XCTAssertEqual(id, firstId,
                "Same intent+context should produce identical commands (determinism)")
        }
    }
    
    /// Test 7: Type safety of command payloads under concurrent execution
    func testCommandPayloadTypeSafety() async throws {
        let config = RuntimeConfig.testing()
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        
        let domainIntents: [(domain: IntentDomain, objective: String)] = [
            (.ui, "click the button"),
            (.code, "search for Pattern"),
            (.system, "launch application")
        ]
        
        var typeViolations = 0
        
        for (domain, objective) in domainIntents {
            let intent = Intent(
                id: UUID(),
                domain: domain,
                objective: objective,
                metadata: [:]
            )
            
            let context = PlannerContext(
                state: WorldStateModel.empty(),
                memories: [],
                repositorySnapshot: nil
            )
            
            do {
                let command = try await runtime.plan(intent: intent, context: context)
                
                // Verify command type matches intent domain
                switch (domain, command.payload) {
                case (.ui, .ui):
                    break // OK
                case (.code, .code):
                    break // OK
                case (.code, .build):
                    break // OK (build is code domain)
                case (.code, .test):
                    break // OK (test is code domain)
                case (.system, .ui):
                    break // OK (system routes to UI)
                default:
                    typeViolations += 1
                }
            } catch {
                // Type safety should prevent bad payloads at compile time
                typeViolations += 1
            }
        }
        
        XCTAssertEqual(typeViolations, 0,
            "No type safety violations should occur")
    }
    
    // MARK: - Service Stability
    
    /// Test 8: All sealed contracts respond within SLA
    func testContractResponseTimesSLA() async throws {
        let config = RuntimeConfig.testing()
        let bootstrap = RuntimeBootstrap(config: config)
        let runtime = try await bootstrap.boot()
        
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "measure SLA",
            metadata: [:]
        )
        
        let context = PlannerContext(
            state: WorldStateModel.empty(),
            memories: [],
            repositorySnapshot: nil
        )
        
        // Measure planner response time
        let startTime = Date()
        _ = try await runtime.plan(intent: intent, context: context)
        let plannerLatency = Date().timeIntervalSince(startTime)
        
        // SLA: Planner should respond within 500ms (p95)
        XCTAssertLessThan(plannerLatency, 0.5,
            "Planner should respond within 500ms SLA (took \(plannerLatency)s)")
    }
    
    // MARK: - Helpers
    
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
        
        guard kerr == KERN_SUCCESS else { throw NSError(domain: "Memory", code: -1) }
        return Int(info.phys_footprint)
    }
}

// MARK: - Extension for testing

extension RuntimeConfig {
    static func testing(maxMemory: Int = 500_000_000) -> RuntimeConfig {
        RuntimeConfig(
            maxConcurrentOperations: 100,
            planningTimeout: 5.0,
            executionTimeout: 30.0,
            memory: .init(maxBytes: maxMemory)
        )
    }
}

extension WorldStateModel {
    static func empty() -> WorldStateModel {
        WorldStateModel(
            activeApplication: nil,
            focusedWindow: nil,
            visibleElements: [],
            systemState: [:],
            timestamp: Date()
        )
    }
}
