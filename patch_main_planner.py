import re

with open('Sources/OracleOS/Planning/MainPlanner+Planner.swift', 'r') as f:
    content = f.read()

p = r'''        if let codeCommand = actionIntent\.codeCommand \{
            let workspace = codeCommand\.workspaceRoot
            let path = codeCommand\.workspaceRelativePath \?\? ""
            let content = actionIntent\.text
            
            switch codeCommand\.category \{
            case \.build:
                let spec = BuildSpec\(workspaceRoot: workspace\)
                return Command\(type: \.code, payload: \.build\(spec\), metadata: metadata\)
            case \.test:
                let spec = TestSpec\(workspaceRoot: workspace\)
                return Command\(type: \.code, payload: \.test\(spec\), metadata: metadata\)
            case \.editFile, \.writeFile, \.generatePatch:
                let spec = FileMutationSpec\(path: path, operation: \.write, content: content, workspaceRoot: workspace\)
                return Command\(type: \.code, payload: \.file\(spec\), metadata: metadata\)
            case \.gitStatus:
                let spec = GitSpec\(operation: \.status, args: codeCommand\.arguments, workspaceRoot: workspace\)
                return Command\(type: \.code, payload: \.git\(spec\), metadata: metadata\)
            case \.gitCommit:
                let spec = GitSpec\(operation: \.commit, args: codeCommand\.arguments, workspaceRoot: workspace\)
                return Command\(type: \.code, payload: \.git\(spec\), metadata: metadata\)
            case \.gitBranch:
                let spec = GitSpec\(operation: \.branch, args: codeCommand\.arguments, workspaceRoot: workspace\)
                return Command\(type: \.code, payload: \.git\(spec\), metadata: metadata\)
            case \.gitPush:
                let spec = GitSpec\(operation: \.push, args: codeCommand\.arguments, workspaceRoot: workspace\)
                return Command\(type: \.code, payload: \.git\(spec\), metadata: metadata\)
            case \.openFile:
                let action = CodeAction\(name: "readFile", filePath: path, workspacePath: workspace\)
                return Command\(type: \.code, payload: \.code\(action\), metadata: metadata\)
            case \.searchCode, \.indexRepository:
                let action = CodeAction\(name: "searchRepository", query: codeCommand\.summary, workspacePath: workspace\)
                return Command\(type: \.code, payload: \.code\(action\), metadata: metadata\)
            default:
                let action = CodeAction\(name: codeCommand\.category\.rawValue, query: codeCommand\.summary, workspacePath: workspace\)
                return Command\(type: \.code, payload: \.code\(action\), metadata: metadata\)
            \}
        \}'''

r = r'''        if let payload = actionIntent.commandPayload {
            // Check if we need to supplement content (like text for writing)
            var finalPayload = payload
            if case .file(let s) = payload, s.operation == .write {
                let text = actionIntent.text
                finalPayload = .file(FileMutationSpec(path: s.path, operation: .write, content: text, workspaceRoot: s.workspaceRoot))
            }
            return Command(type: .code, payload: finalPayload, metadata: metadata)
        }'''

content = re.sub(p, r, content)
with open('Sources/OracleOS/Planning/MainPlanner+Planner.swift', 'w') as f:
    f.write(content)

