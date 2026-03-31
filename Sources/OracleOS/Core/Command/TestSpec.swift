import Foundation

/// Typed test specification. No generic shell execution.
public struct TestSpec: Sendable, Codable {
    public let workspaceRoot: String
    public let target: String?

    public init(
        workspaceRoot: String,
        target: String? = nil
    ) {
        self.workspaceRoot = workspaceRoot
        self.target = target
    }
}
