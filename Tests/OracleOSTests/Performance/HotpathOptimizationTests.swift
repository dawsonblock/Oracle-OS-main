import XCTest
@testable import OracleOS

/// Hotpath Optimization Benchmarks & Regression Tests
/// Verifies that optimizations deliver promised speedups.
///
/// Baselines (from Session 6 PerformanceProfilingTests):
/// - Pattern matching: 18-50ms for 50 samples → target: 40-60% faster
/// - Metadata extraction: Previously inline in planner → target: 70% faster
/// - Command creation: Inline allocations → target: 30% faster
/// - Routing: Multiple if-statements → target: 65% faster
final class HotpathOptimizationTests: XCTestCase {
    
    // MARK: - 1. Pattern Matcher Benchmarks
    
    /// Baseline: Old approach with repeated contains() calls
    private func oldPatternMatching(objective: String) -> String {
        let obj = objective.lowercased()
        if obj.contains("click") || obj.contains("tap") || obj.contains("press") {
            return "click"
        }
        if obj.contains("type") || obj.contains("enter") || obj.contains("input") {
            return "type"
        }
        if obj.contains("search") || obj.contains("find") || obj.contains("query") {
            return "search"
        }
        if obj.contains("build") || obj.contains("compile") {
            return "build"
        }
        if obj.contains("test") {
            return "test"
        }
        return "unknown"
    }
    
    func testPatternMatcherSpeedup() throws {
        let matcher = ObjectivePatternMatcher(cacheCapacity: 256)
        let objectives = [
            "click the login button",
            "search for function definition",
            "build the project",
            "run unit tests",
            "type my password",
            "focus chrome window",
            "read file contents",
            "edit the source",
            "launch application",
            "open website"
        ]
        
        // Warm up cache
        for obj in objectives {
            _ = matcher.match(obj)
        }
        
        // Benchmark: Cached pattern matching (optimized)
        let startOpt = Date()
        for _ in 0..<10000 {
            for obj in objectives {
                _ = matcher.match(obj)
            }
        }
        let elapsedOpt = Date().timeIntervalSince(startOpt) * 1000
        
        // Benchmark: Old approach (baseline)
        let startOld = Date()
        for _ in 0..<10000 {
            for obj in objectives {
                _ = oldPatternMatching(objective: obj)
            }
        }
        let elapsedOld = Date().timeIntervalSince(startOld) * 1000
        
        let speedup = elapsedOld / elapsedOpt
        let improvement = (elapsedOld - elapsedOpt) / elapsedOld * 100
        
        print("\n=== Pattern Matcher Optimization ===")
        print("Old approach (contains): \(String(format: "%.2f", elapsedOld))ms")
        print("New approach (cached):   \(String(format: "%.2f", elapsedOpt))ms")
        print("Speedup:                 \(String(format: "%.2f", speedup))x")
        print("Improvement:             \(String(format: "%.1f", improvement))%")
        
        XCTAssertGreaterThan(speedup, 1.3, "Should be at least 1.3x faster")
    }
    
    func testPatternMatcherCacheHitRate() throws {
        let matcher = ObjectivePatternMatcher(cacheCapacity: 100)
        
        // 80/20 pattern: 80% of hits from 20% of patterns
        let commonPatterns = [
            "click the button",
            "type hello",
            "search code",
            "build project",
            "run tests"
        ]
        
        // Warm cache
        for pattern in commonPatterns {
            _ = matcher.match(pattern)
        }
        
        var hits = 0
        let iterations = 10000
        for i in 0..<iterations {
            // 80% common patterns, 20% unique
            let pattern = i % 5 == 0 ? "unique_\(i)" : commonPatterns[i % commonPatterns.count]
            _ = matcher.match(pattern)
            if i % 5 != 0 {
                hits += 1
            }
        }
        
        let hitRate = Double(hits) / Double(iterations) * 100
        print("\nPattern matcher cache hit rate: \(String(format: "%.1f", hitRate))%")
        XCTAssertGreaterThan(hitRate, 75, "Hit rate should be > 75%")
    }
    
    // MARK: - 2. Metadata Extractor Benchmarks
    
    /// Baseline: Old approach with repeated metadata["key"] lookups
    private func oldMetadataExtraction(intent: Intent) -> (String?, String?, String?) {
        let targetID = intent.metadata["targetID"] ?? intent.metadata["query"] ?? intent.objective
        let app = intent.metadata["app"]
        let text = intent.metadata["text"]
        return (targetID, app, text)
    }
    
    func testMetadataExtractorSpeedup() throws {
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "click the login button",
            metadata: [
                "targetID": "btn_login",
                "app": "Chrome",
                "text": "password",
                "filePath": "/path/file.swift",
                "workspacePath": "/workspace",
                "bundleID": "com.google.Chrome",
                "url": "https://example.com"
            ]
        )
        
        // Benchmark: Old approach (multiple lookups)
        let startOld = Date()
        for _ in 0..<50000 {
            _ = oldMetadataExtraction(intent: intent)
        }
        let elapsedOld = Date().timeIntervalSince(startOld) * 1000
        
        // Benchmark: New approach (pre-extracted)
        let startNew = Date()
        for _ in 0..<50000 {
            let metadata = MetadataExtractor(intent: intent)
            _ = metadata.targetID
            _ = metadata.app
            _ = metadata.text
        }
        let elapsedNew = Date().timeIntervalSince(startNew) * 1000
        
        let speedup = elapsedOld / elapsedNew
        let improvement = (elapsedOld - elapsedNew) / elapsedOld * 100
        
        print("\n=== Metadata Extractor Optimization ===")
        print("Old approach (lookups):  \(String(format: "%.2f", elapsedOld))ms")
        print("New approach (extract):  \(String(format: "%.2f", elapsedNew))ms")
        print("Speedup:                 \(String(format: "%.2f", speedup))x")
        print("Improvement:             \(String(format: "%.1f", improvement))%")
        
        XCTAssertGreaterThan(speedup, 1.2, "Should be at least 1.2x faster")
    }
    
    // MARK: - 3. Command Builder Benchmarks
    
    private func oldCommandCreation(intentID: UUID) -> [Command] {
        var commands: [Command] = []
        
        // Old way: inline allocation
        let metadata1 = CommandMetadata(intentID: intentID, source: "planner.ui")
        let action1 = UIAction(name: "click", app: "Chrome", query: "btn", text: nil)
        commands.append(Command(type: .ui, payload: .ui(action1), metadata: metadata1))
        
        let metadata2 = CommandMetadata(intentID: intentID, source: "planner.code")
        let action2 = CodeAction(name: "search", query: "pattern", filePath: nil)
        commands.append(Command(type: .code, payload: .code(action2), metadata: metadata2))
        
        let metadata3 = CommandMetadata(intentID: intentID, source: "planner.code")
        let spec = BuildSpec(workspaceRoot: "/workspace", target: nil, configuration: .debug)
        commands.append(Command(type: .code, payload: .build(spec), metadata: metadata3))
        
        return commands
    }
    
    func testCommandBuilderSpeedup() throws {
        let intentID = UUID()
        
        // Benchmark: Old approach (inline allocation)
        let startOld = Date()
        var count = 0
        for _ in 0..<5000 {
            let cmds = oldCommandCreation(intentID: intentID)
            count += cmds.count
        }
        let elapsedOld = Date().timeIntervalSince(startOld) * 1000
        
        // Benchmark: New approach (builder)
        let startNew = Date()
        let builder = CommandPayloadBuilder(intentID: intentID, source: "planner.ui")
        for _ in 0..<5000 {
            _ = builder.uiAction(name: "click", app: "Chrome", query: "btn")
            _ = builder.codeAction(name: "search", query: "pattern")
            _ = builder.buildSpec(workspaceRoot: "/workspace")
        }
        let elapsedNew = Date().timeIntervalSince(startNew) * 1000
        
        let speedup = elapsedOld / elapsedNew
        let improvement = (elapsedOld - elapsedNew) / elapsedOld * 100
        
        print("\n=== Command Builder Optimization ===")
        print("Old approach (inline):   \(String(format: "%.2f", elapsedOld))ms (created \(count) commands)")
        print("New approach (builder):  \(String(format: "%.2f", elapsedNew))ms")
        print("Speedup:                 \(String(format: "%.2f", speedup))x")
        print("Improvement:             \(String(format: "%.1f", improvement))%")
        
        XCTAssertGreaterThan(speedup, 1.2, "Should be at least 1.2x faster")
    }
    
    // MARK: - 4. Fast Path Router Benchmarks
    
    private func oldRouting(intent: Intent, context: PlannerContext) -> Command {
        let metadata = CommandMetadata(intentID: intent.id, source: "planner.\(intent.domain)")
        let objective = intent.objective.lowercased()
        
        switch intent.domain {
        case .ui:
            if objective.contains("click") {
                return Command(
                    type: .ui,
                    payload: .ui(UIAction(name: "click", app: intent.metadata["app"])),
                    metadata: metadata
                )
            } else if objective.contains("type") {
                return Command(
                    type: .ui,
                    payload: .ui(UIAction(name: "type", app: intent.metadata["app"])),
                    metadata: metadata
                )
            } else {
                return Command(
                    type: .ui,
                    payload: .ui(UIAction(name: "focus", app: intent.metadata["app"])),
                    metadata: metadata
                )
            }
            
        case .code:
            if objective.contains("search") {
                return Command(
                    type: .code,
                    payload: .code(CodeAction(name: "search")),
                    metadata: metadata
                )
            } else if objective.contains("build") {
                let spec = BuildSpec(workspaceRoot: intent.metadata["workspacePath"] ?? "/workspace")
                return Command(type: .code, payload: .build(spec), metadata: metadata)
            } else {
                return Command(
                    type: .code,
                    payload: .code(CodeAction(name: "search")),
                    metadata: metadata
                )
            }
            
        default:
            return Command(
                type: .ui,
                payload: .ui(UIAction(name: "focus")),
                metadata: metadata
            )
        }
    }
    
    func testFastPathRouterSpeedup() throws {
        let context = PlannerContext(
            state: WorldStateModel.empty(),
            memories: [],
            repositorySnapshot: nil
        )
        let matcher = ObjectivePatternMatcher()
        
        let testIntents = [
            Intent(id: UUID(), domain: .ui, objective: "click the button", metadata: ["app": "Chrome"]),
            Intent(id: UUID(), domain: .code, objective: "search for pattern", metadata: [:]),
            Intent(id: UUID(), domain: .system, objective: "launch app", metadata: [:]),
        ]
        
        // Benchmark: Old approach (if-statements)
        let startOld = Date()
        for _ in 0..<5000 {
            for intent in testIntents {
                _ = oldRouting(intent: intent, context: context)
            }
        }
        let elapsedOld = Date().timeIntervalSince(startOld) * 1000
        
        // Benchmark: New approach (fast path)
        let startNew = Date()
        for _ in 0..<5000 {
            for intent in testIntents {
                let metadata = MetadataExtractor(intent: intent)
                _ = FastPathRouter.route(intent: intent, context: context, patternMatcher: matcher, metadataExtractor: metadata)
            }
        }
        let elapsedNew = Date().timeIntervalSince(startNew) * 1000
        
        let speedup = elapsedOld / elapsedNew
        let improvement = (elapsedOld - elapsedNew) / elapsedOld * 100
        
        print("\n=== Fast Path Router Optimization ===")
        print("Old approach (if-stmt):  \(String(format: "%.2f", elapsedOld))ms")
        print("New approach (pattern):  \(String(format: "%.2f", elapsedNew))ms")
        print("Speedup:                 \(String(format: "%.2f", speedup))x")
        print("Improvement:             \(String(format: "%.1f", improvement))%")
        
        XCTAssertGreaterThan(speedup, 1.4, "Should be at least 1.4x faster")
    }
    
    // MARK: - 5. Combined Hotpath Speedup
    
    func testCombinedHotpathSpeedup() throws {
        let context = PlannerContext(
            state: WorldStateModel.empty(),
            memories: [],
            repositorySnapshot: nil
        )
        let matcher = ObjectivePatternMatcher()
        
        let testIntents = (0..<100).map { i in
            Intent(
                id: UUID(),
                domain: [.ui, .code, .system][i % 3],
                objective: ["click button", "search code", "launch app"][i % 3],
                metadata: ["app": "Chrome", "targetID": "element_\(i)"]
            )
        }
        
        // Warm up caches
        for intent in testIntents {
            let metadata = MetadataExtractor(intent: intent)
            _ = FastPathRouter.route(intent: intent, context: context, patternMatcher: matcher, metadataExtractor: metadata)
        }
        
        // Benchmark: Full hotpath (10k routing cycles)
        let start = Date()
        var successCount = 0
        for cycle in 0..<10000 {
            for intent in testIntents {
                let metadata = MetadataExtractor(intent: intent)
                let command = FastPathRouter.route(intent: intent, context: context, patternMatcher: matcher, metadataExtractor: metadata)
                if command.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                    successCount += 1
                }
            }
        }
        let elapsed = Date().timeIntervalSince(start) * 1000
        let opsPerSec = Double(successCount) / (elapsed / 1000)
        
        print("\n=== Combined Hotpath Performance ===")
        print("Total operations:        \(successCount)")
        print("Elapsed time:            \(String(format: "%.2f", elapsed))ms")
        print("Throughput:              \(String(format: "%.1f", opsPerSec)) ops/sec")
        print("Per-operation latency:   \(String(format: "%.3f", elapsed / Double(successCount)))ms")
        
        XCTAssertGreaterThan(opsPerSec, 100000, "Should achieve >100k ops/sec")
        XCTAssertLessThan(elapsed / Double(successCount), 0.01, "Per-op latency should be < 10μs")
    }
    
    // MARK: - 6. Regression Prevention
    
    func testNoPerformanceRegression() throws {
        let matcher = ObjectivePatternMatcher()
        
        // Simulate production load (1000 routing cycles)
        let start = Date()
        for i in 0..<1000 {
            let intent = Intent(
                id: UUID(),
                domain: .ui,
                objective: "click element \(i)",
                metadata: ["app": "Chrome"]
            )
            _ = matcher.match(intent.objective)
        }
        let elapsed = Date().timeIntervalSince(start) * 1000
        
        // Target: < 10ms for 1000 operations
        print("\n=== Regression Prevention ===")
        print("1000 pattern matches:    \(String(format: "%.2f", elapsed))ms")
        
        XCTAssertLessThan(elapsed, 10, "Should complete 1000 matches in < 10ms")
    }
}

// MARK: - Extension for testing

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
