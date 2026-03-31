import Foundation

public enum BuildTool: String, Codable, Sendable, CaseIterable {
    case swiftPackage = "swift-package"
    case npm
    case pytest
    case xcodebuild
    case unknown
}

public enum BuildToolDetector {
    public static func detect(at workspaceRoot: URL) -> BuildTool {
        let fm = FileManager.default
        if fm.fileExists(atPath: workspaceRoot.appendingPathComponent("Package.swift").path) {
            return .swiftPackage
        }
        if fm.fileExists(atPath: workspaceRoot.appendingPathComponent("package.json").path) {
            return .npm
        }
        if fm.fileExists(atPath: workspaceRoot.appendingPathComponent("pytest.ini").path)
            || fm.fileExists(atPath: workspaceRoot.appendingPathComponent("pyproject.toml").path)
        {
            return .pytest
        }
        if let files = try? fm.contentsOfDirectory(atPath: workspaceRoot.path),
           files.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") })
        {
            return .xcodebuild
        }
        return .unknown
    }

    public static func defaultBuildCommand(
        for buildTool: BuildTool,
        workspaceRoot: URL
    ) -> BuildSpec? {
        // Typed build spec simplifies to just passing the root. WorkspaceRunner applies the tool-specific command.
        return BuildSpec(workspaceRoot: workspaceRoot.path)
    }

    public static func defaultTestCommand(
        for buildTool: BuildTool,
        workspaceRoot: URL
    ) -> TestSpec? {
        // Typed test spec simplifies to just passing the root.
        return TestSpec(workspaceRoot: workspaceRoot.path)
    }
}
