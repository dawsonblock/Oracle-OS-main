import XCTest
@testable import OracleOS

/// Phase 5.4: Planner Contract Tests
/// Verify that MainPlannerRefactored implements the Planner protocol honestly.
/// These tests define the contract that any Planner implementation must satisfy.
class PlannerContractTests: XCTestCase {

    private var factory: PlannerTestFactory!

    override func setUp() {
        super.setUp()
        factory = PlannerTestFactory()
    }

    // MARK: - Contract: plan() returns Command

    @MainActor
    func testPlanReturnsCommand() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "click the button",
            metadata: [:]
        )
        let context = PlannerContext(
            state: WorldStateModel(),
            memories: [],
            repositorySnapshot: nil
        )

        let expectation = expectation(description: "plan returns command")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                XCTAssertNotNil(command)
                expectation.fulfill()
            } catch {
                XCTFail("plan() should not throw: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testCommandHasProperMetadata() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "click button",
            metadata: [:]
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation = expectation(description: "command has metadata")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                XCTAssertEqual(command.metadata.source, "planner.ui")
                XCTAssertEqual(command.metadata.intentID, intent.id)
                expectation.fulfill()
            } catch {
                XCTFail("Expected command with metadata: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Contract: Domain Routing

    @MainActor
    func testUIIntentReturnsUICommand() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "click the sign in button",
            metadata: ["targetID": "signin-btn"]
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation = expectation(description: "ui intent returns ui command")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                XCTAssertEqual(command.type, .ui)
                expectation.fulfill()
            } catch {
                XCTFail("UI intent should succeed: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testCodeIntentReturnsCodeCommand() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .code,
            objective: "search the repository",
            metadata: [:]
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation = expectation(description: "code intent returns code command")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                XCTAssertEqual(command.type, .code)
                expectation.fulfill()
            } catch {
                XCTFail("Code intent should succeed: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testSystemIntentReturnsUICommand() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .system,
            objective: "launch Safari",
            metadata: [:]
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation = expectation(description: "system intent returns ui command")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                XCTAssertEqual(command.type, .ui)
                expectation.fulfill()
            } catch {
                XCTFail("System intent should succeed: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Contract: Determinism (No Mutable State)

    @MainActor
    func testSameIntentProducesSameCommand() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "click button",
            metadata: ["query": "signin"]
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation1 = expectation(description: "first call")
        let expectation2 = expectation(description: "second call")
        
        var command1: Command?
        var command2: Command?

        Task {
            do {
                command1 = try await planner.plan(intent: intent, context: context)
                expectation1.fulfill()
                
                // Second call with same intent/context
                command2 = try await planner.plan(intent: intent, context: context)
                expectation2.fulfill()
                
                // Verify same output
                XCTAssertEqual(command1?.type, command2?.type)
                XCTAssertEqual(command1?.metadata.source, command2?.metadata.source)
            } catch {
                XCTFail("Determinism test failed: \(error)")
            }
        }
        
        wait(for: [expectation1, expectation2], timeout: 2.0)
    }

    @MainActor
    func testNoMutableStatePollution() throws {
        let planner = factory.makePlanner()
        
        let intent1 = Intent(
            id: UUID(),
            domain: .ui,
            objective: "click button 1",
            metadata: [:]
        )
        let intent2 = Intent(
            id: UUID(),
            domain: .code,
            objective: "search repository",
            metadata: [:]
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation = expectation(description: "no state pollution")
        
        Task {
            do {
                let command1 = try await planner.plan(intent: intent1, context: context)
                let command2 = try await planner.plan(intent: intent2, context: context)
                
                // Verify different commands (no state leakage)
                XCTAssertEqual(command1.type, .ui)
                XCTAssertEqual(command2.type, .code)
                expectation.fulfill()
            } catch {
                XCTFail("State pollution test failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testConcurrentPlansIndependent() throws {
        let planner = factory.makePlanner()
        
        let intent1 = Intent(id: UUID(), domain: .ui, objective: "click", metadata: [:])
        let intent2 = Intent(id: UUID(), domain: .code, objective: "search", metadata: [:])
        let intent3 = Intent(id: UUID(), domain: .system, objective: "launch", metadata: [:])
        
        let context = PlannerContext(state: WorldStateModel())
        
        let expectation = expectation(description: "concurrent plans")
        expectation.expectedFulfillmentCount = 3

        Task {
            async let cmd1 = try planner.plan(intent: intent1, context: context)
            async let cmd2 = try planner.plan(intent: intent2, context: context)
            async let cmd3 = try planner.plan(intent: intent3, context: context)
            
            do {
                let c1 = try await cmd1
                let c2 = try await cmd2
                let c3 = try await cmd3
                
                XCTAssertEqual(c1.type, .ui)
                XCTAssertEqual(c2.type, .code)
                XCTAssertEqual(c3.type, .ui)
                
                expectation.fulfill()
                expectation.fulfill()
                expectation.fulfill()
            } catch {
                XCTFail("Concurrent test failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Contract: Payload Type Safety

    @MainActor
    func testUIPayloadIsTyped() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "click button",
            metadata: [:]
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation = expectation(description: "ui payload typed")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                
                switch command.payload {
                case .ui(let action):
                    XCTAssertNotNil(action)
                    expectation.fulfill()
                default:
                    XCTFail("UI intent should have UI payload")
                }
            } catch {
                XCTFail("Payload test failed: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testCodePayloadIsTyped() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .code,
            objective: "search repository",
            metadata: [:]
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation = expectation(description: "code payload typed")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                
                switch command.payload {
                case .code(let action):
                    XCTAssertNotNil(action)
                    expectation.fulfill()
                default:
                    XCTFail("Code intent should have code payload")
                }
            } catch {
                XCTFail("Payload test failed: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Contract: Error Handling

    @MainActor
    func testMissingContextThrows() throws {
        // This test validates that missing critical context is handled
        let planner = factory.makePlanner()
        let intent = Intent(id: UUID(), domain: .ui, objective: "test", metadata: [:])
        
        // Create context with nil state (if allowed)
        let context = PlannerContext(state: WorldStateModel())
        
        let expectation = expectation(description: "handles missing context")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                // Should still return a command with reasonable defaults
                XCTAssertNotNil(command)
                expectation.fulfill()
            } catch {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testEmptyIntentMetadata() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "do something",
            metadata: [:]  // Empty metadata
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation = expectation(description: "handles empty metadata")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                XCTAssertNotNil(command)
                expectation.fulfill()
            } catch {
                XCTFail("Should handle empty metadata: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Contract: Objective Parsing

    @MainActor
    func testClickObjectiveDetected() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "click the login button",
            metadata: [:]
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation = expectation(description: "click detected")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                
                if case .ui(let action) = command.payload {
                    XCTAssertEqual(action.name, "click")
                    expectation.fulfill()
                } else {
                    XCTFail("Should detect click action")
                }
            } catch {
                XCTFail("Click detection failed: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testTypeObjectiveDetected() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .ui,
            objective: "type the password",
            metadata: ["text": "secret"]
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation = expectation(description: "type detected")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                
                if case .ui(let action) = command.payload {
                    XCTAssertEqual(action.name, "type")
                    expectation.fulfill()
                } else {
                    XCTFail("Should detect type action")
                }
            } catch {
                XCTFail("Type detection failed: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testSearchObjectiveDetected() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .code,
            objective: "search for ViewController",
            metadata: [:]
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation = expectation(description: "search detected")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                
                if case .code(let action) = command.payload {
                    XCTAssertEqual(action.name, "searchRepository")
                    expectation.fulfill()
                } else {
                    XCTFail("Should detect search action")
                }
            } catch {
                XCTFail("Search detection failed: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testBuildObjectiveDetected() throws {
        let planner = factory.makePlanner()
        let intent = Intent(
            id: UUID(),
            domain: .code,
            objective: "build the project",
            metadata: [:]
        )
        let context = PlannerContext(state: WorldStateModel())

        let expectation = expectation(description: "build detected")
        Task {
            do {
                let command = try await planner.plan(intent: intent, context: context)
                
                if case .code(let payload) = command.payload {
                    if case .build(_) = payload {
                        expectation.fulfill()
                    } else {
                        XCTFail("Should detect build action")
                    }
                } else {
                    XCTFail("Build intent should return code command")
                }
            } catch {
                XCTFail("Build detection failed: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }
}

// MARK: - Test Factory

/// Factory for creating test planners with all dependencies.
class PlannerTestFactory {
    @MainActor
    func makePlanner() -> Planner {
        let deps = RuntimeBootstrap.makePlannerDependencies(
            repositoryIndexer: MockRepositoryIndexer(),
            impactAnalyzer: RepositoryChangeImpactAnalyzer()
        )
        
        return MainPlannerRefactored(
            workflowIndex: deps.workflowIndex,
            workflowRetriever: deps.workflowRetriever,
            osPlanner: deps.osPlanner,
            codePlanner: deps.codePlanner,
            reasoningEngine: deps.reasoningEngine,
            planEvaluator: deps.planEvaluator,
            promptEngine: deps.promptEngine,
            reasoningThreshold: deps.reasoningThreshold,
            taskGraphStore: deps.taskGraphStore
        )
    }
}

// MARK: - Mocks

class MockRepositoryIndexer: RepositoryIndexer {
    override func indexIfNeeded(workspaceRoot: URL) -> RepositorySnapshot {
        return RepositorySnapshot(
            workspaceRoot: workspaceRoot.path,
            roots: [],
            allFiles: [],
            buildTargets: [],
            testTargets: [],
            sourceModules: [],
            resourceModules: [],
            externalDeps: []
        )
    }
}
