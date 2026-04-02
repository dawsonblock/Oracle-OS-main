import re

with open('Sources/OracleOS/Code/Skills/CodeSkillSupport.swift', 'r') as f:
    content = f.read()

p = r'''    static func command\(
        category: CodeCommandCategory,
        workspaceRoot: URL,
        workspaceRelativePath: String\? = nil,
        summary: String,
        arguments: \[String\] = \[\],
        touchesNetwork: Bool = false
    \) -> CommandSpec \{
        CommandSpec\(
            category: category,
            executable: "/usr/bin/env",
            arguments: arguments,
            workspaceRoot: workspaceRoot\.path,
            workspaceRelativePath: workspaceRelativePath,
            summary: summary,
            touchesNetwork: touchesNetwork
        \)
    \}'''
    
r = '''    static func command(
        category: CodeCommandCategory,
        workspaceRoot: URL,
        workspaceRelativePath: String? = nil,
        summary: String,
        arguments: [String] = [],
        touchesNetwork: Bool = false
    ) -> CommandPayload {
        let root = workspaceRoot.path
        let path = workspaceRelativePath ?? ""
        switch category {
        case .build:
            return .build(BuildSpec(workspaceRoot: root))
        case .test:
            return .test(TestSpec(workspaceRoot: root))
        case .gitStatus:
            return .git(GitSpec(operation: .status, args: arguments, workspaceRoot: root))
        case .gitCommit:
            return .git(GitSpec(operation: .commit, args: arguments, workspaceRoot: root))
        case .gitBranch:
            return .git(GitSpec(operation: .branch, args: arguments, workspaceRoot: root))
        case .gitPush:
            return .git(GitSpec(operation: .push, args: arguments, workspaceRoot: root))
        case .editFile, .writeFile, .generatePatch:
            return .file(FileMutationSpec(path: path, operation: .write, content: nil, workspaceRoot: root))
        case .openFile:
            return .code(CodeAction(name: "readFile", filePath: path, workspacePath: root))
        case .searchCode, .indexRepository:
            return .code(CodeAction(name: "searchRepository", query: summary, workspacePath: root))
        default:
            return .code(CodeAction(name: category.rawValue, query: summary, workspacePath: root))
        }
    }'''

content = re.sub(p, r, content, flags=re.MULTILINE)
with open('Sources/OracleOS/Code/Skills/CodeSkillSupport.swift', 'w') as f:
    f.write(content)
