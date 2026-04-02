import Foundation

/// A projection transforms events into memory mutations.
/// Projections are functions from state + event → new state + side effects.
/// They enable:
/// - Testing memory updates in isolation
/// - Async processing (projections can return effects for later execution)
/// - Event sourcing (replay events to rebuild state)
/// - Clear dependency tracking (which events affect which memory tier)
public protocol MemoryProjection {
    associatedtype Input
    associatedtype Output

    /// Process an input and return output + optional side effects.
    /// Side effects (e.g., disk I/O) are NOT executed by the projection.
    /// The caller decides whether to await them.
    func project(_ input: Input) -> (output: Output, effects: [MemoryEffect])
}

/// Side effect that the projection computed but did not execute.
/// Allows async/batch processing without blocking the execution spine.
public struct MemoryEffect: Sendable {
    public enum Kind: Sendable {
        case recordControl(KnownControl)
        case recordFailure(FailurePattern)
        case recordCommandResult(category: String, workspaceRoot: String, success: Bool)
    }

    public let kind: Kind
    public let priority: Int  // 0 = deferred, 1 = urgent, 2 = critical

    public init(_ kind: Kind, priority: Int = 0) {
        self.kind = kind
        self.priority = priority
    }

    public var isCritical: Bool { priority >= 2 }
    public var isUrgent: Bool { priority >= 1 }
}

/// Projection input: a domain event
public enum MemoryInput: Sendable {
    case fileModified(path: String, timestamp: Date)
    case commandExecuted(kind: String, success: Bool, duration: TimeInterval)
    case controlSelected(app: String, label: String?, role: String?, elementID: String?)
    case controlFailed(app: String, reason: String)
    case strategyAttempted(kind: String, success: Bool)
}

/// Projection output: the record that was created/updated
public protocol MemoryRecord: Sendable {
    var id: String { get }
    var timestamp: Date { get }
    var summary: String { get }
}

// MARK: - Strategy Memory Projection

/// Records successful controls and failure patterns.
/// Inputs: control selections, failures
/// Outputs: KnownControl, FailurePattern records
/// Side effects: write to StrategyMemory
public struct StrategyMemoryProjection {
    private let store: StrategyMemory

    public init(store: StrategyMemory) {
        self.store = store
    }

    public func projectControl(
        app: String,
        label: String?,
        role: String?,
        elementID: String?
    ) -> (record: KnownControl, effects: [MemoryEffect]) {
        let key = "\(app)-\(label ?? "unknown")"
        let control = KnownControl(
            key: key,
            app: app,
            label: label,
            role: role,
            elementID: elementID,
            successCount: 1,
            lastUsed: Date()
        )

        let effect = MemoryEffect(.recordControl(control), priority: 1)
        return (control, [effect])
    }

    public func projectFailure(
        app: String,
        reason: String,
        action: String
    ) -> (record: FailurePattern, effects: [MemoryEffect]) {
        let pattern = FailurePattern(
            app: app,
            failure: .unknown(reason),
            action: action
        )

        let effect = MemoryEffect(.recordFailure(pattern), priority: 1)
        return (pattern, [effect])
    }

    /// Execute a side effect synchronously.
    /// This should only be called for critical/urgent effects.
    public func executeEffect(_ effect: MemoryEffect) throws {
        guard case .recordControl(let control) = effect.kind else {
            if case .recordFailure(let pattern) = effect.kind {
                store.recordFailure(pattern)
            }
            return
        }
        store.recordControl(control)
    }
}

// MARK: - Execution Memory Projection

/// Records command execution results.
/// Inputs: command executed events
/// Outputs: execution record
/// Side effects: write to ExecutionMemoryStore
public struct ExecutionMemoryProjection {
    private let store: ExecutionMemoryStore

    public init(store: ExecutionMemoryStore) {
        self.store = store
    }

    public func projectCommandExecution(
        category: String,
        workspaceRoot: String,
        success: Bool
    ) -> (record: ExecutionRecord, effects: [MemoryEffect]) {
        let record = ExecutionRecord(
            id: UUID().uuidString,
            category: category,
            workspaceRoot: workspaceRoot,
            success: success,
            timestamp: Date()
        )

        let effect = MemoryEffect(
            .recordCommandResult(category: category, workspaceRoot: workspaceRoot, success: success),
            priority: 0
        )
        return (record, [effect])
    }

    /// Execute a side effect synchronously.
    public func executeEffect(_ effect: MemoryEffect) throws {
        guard case .recordCommandResult(let category, let workspaceRoot, let success) = effect.kind else {
            return
        }
        // ExecutionMemoryStore.recordCommandResult would be implemented here
        // For now, this is a placeholder
    }
}

// MARK: - Pattern Memory Projection

/// Records reusable patterns.
/// Inputs: strategy attempts
/// Outputs: pattern record
/// Side effects: write to PatternMemoryStore
public struct PatternMemoryProjection {
    private let store: PatternMemoryStore

    public init(store: PatternMemoryStore) {
        self.store = store
    }

    public func projectStrategyAttempt(
        kind: String,
        success: Bool
    ) -> (record: PatternRecord, effects: [MemoryEffect]) {
        let record = PatternRecord(
            id: UUID().uuidString,
            kind: kind,
            success: success,
            timestamp: Date()
        )

        let priority = success ? 1 : 0  // Successful patterns are more urgent
        let effect = MemoryEffect(.recordCommandResult(
            category: kind,
            workspaceRoot: "",
            success: success
        ), priority: priority)

        return (record, [effect])
    }

    /// Execute a side effect synchronously.
    public func executeEffect(_ effect: MemoryEffect) throws {
        // PatternMemoryStore side effects would be executed here
    }
}

// MARK: - Record Types

public struct ExecutionRecord: MemoryRecord, Sendable {
    public let id: String
    public let category: String
    public let workspaceRoot: String
    public let success: Bool
    public let timestamp: Date

    public var summary: String {
        "\(category): \(success ? "success" : "failure")"
    }
}

public struct PatternRecord: MemoryRecord, Sendable {
    public let id: String
    public let kind: String
    public let success: Bool
    public let timestamp: Date

    public var summary: String {
        "\(kind): \(success ? "success" : "failure")"
    }
}
