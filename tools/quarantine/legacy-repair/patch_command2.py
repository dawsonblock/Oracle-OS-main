import re

c = """
extension CommandPayload {
    public var summary: String {
        switch self {
        case .build: return "Build"
        case .test: return "Test"
        case .git(let s): return "Git \\(s.operation.rawValue)"
        case .file(let s): return "\\(s.operation.rawValue) \\(s.path)"
        case .ui(let action): return action.name
        case .code(let action): return action.name
        }
    }
    public var categoryName: String {
        switch self {
        case .build: return "build"
        case .test: return "test"
        case .git: return "git"
        case .file: return "file"
        case .ui: return "ui"
        case .code: return "code"
        }
    }
    public var workspaceRelativePath: String? {
        switch self {
        case .file(let s): return s.path
        case .code(let s): return s.filePath ?? s.workspacePath
        default: return nil
        }
    }
    public var workspaceRoot: String? {
        switch self {
        case .build(let s): return s.workspaceRoot
        case .test(let s): return s.workspaceRoot
        case .git(let s): return s.workspaceRoot
        case .file(let s): return s.workspaceRoot ?? ""
        case .code(let action): return action.workspacePath
        case .ui: return nil
        }
    }
    public var touchesNetwork: Bool {
        switch self {
        case .git(let s): return s.operation == .push || s.operation == .pull
        default: return false
        }
    }
}
"""

with open('Sources/OracleOS/Core/Command/Command.swift', 'a') as f:
    f.write(c)

