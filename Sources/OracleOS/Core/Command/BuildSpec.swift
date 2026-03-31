import Foundation

public enum BuildConfiguration: String, Sendable, Codable {
    case debug
    case release
}

/// Typed build specification. No generic shell execution.
public struct BuildSpec: Sendable, Codable {
    public let workspaceRoot: String
    public let target: String?
    public let configuration: BuildConfiguration?

    public init(
        workspaceRoot: String,
        target: String? = nil,
        configuration: BuildConfiguration? = .debug
    ) {
        self.workspaceRoot = workspaceRoot
        self.target = target
        self.configuration = configuration
    }
}
