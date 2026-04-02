import re

with open('Sources/OracleOS/Intent/Policies/PolicyRules.swift', 'r') as f:
    content = f.read()

p = r'''    private static func codeClassification\(
        for intent: ActionIntent,
        context: PolicyEvaluationContext
    \) -> \(protectedOperation: ProtectedOperation\?, riskLevel: RiskLevel, reason: String\?\) \{
        guard let command = intent\.codeCommand else \{
            return \(\.workspaceWrite, \.blocked, "Arbitrary shell execution is blocked"\)
        \}

        guard let workspaceRoot = context\.workspaceRoot \?\? intent\.workspaceRoot, !workspaceRoot\.isEmpty else \{
            return \(\.workspaceWrite, \.blocked, "Workspace root is required for code actions"\)
        \}

        if let relativePath = context\.workspaceRelativePath \?\? intent\.workspaceRelativePath \{
            if relativePath\.hasPrefix\("/"\) || relativePath\.contains\("\.\./"\) \{
                return \(\.workspaceWrite, \.blocked, "Workspace path escapes the active workspace"\)
            \}
        \}

        if command\.touchesNetwork \{
            return \(\.externalNetworkFetch, \.risky, "Remote network actions require approval"\)
        \}

        switch command\.category \{
        case \.indexRepository, \.searchCode, \.openFile, \.parseBuildFailure, \.parseTestFailure, \.build, \.test, \.formatter, \.linter, \.gitStatus, \.gitBranch, \.gitCommit:
            return \(nil, \.low, nil\)
        case \.gitPush:
            let summary = command\.summary\.lowercased\(\)
            if summary\.contains\("--force"\) || summary\.contains\("force"\) || summary\.contains\("delete"\) || summary\.contains\(" rebase "\) || summary\.contains\(" merge "\) \{
                return \(\.destructiveVCS, \.blocked, "Destructive VCS actions are blocked by policy"\)
            \}
            return \(\.gitPush, \.risky, "Git push requires approval"\)
        case \.editFile, \.writeFile, \.generatePatch:
            let path = intent\.workspaceRelativePath \?\? command\.workspaceRelativePath \?\? ""
            if path\.isEmpty \{
                return \(\.workspaceWrite, \.blocked, "Workspace write target is missing"\)
            \}
            return \(\.workspaceWrite, \.risky, "Workspace write needs approval outside trusted test roots"\)
        \}
    \}'''

r = r'''    private static func codeClassification(
        for intent: ActionIntent,
        context: PolicyEvaluationContext
    ) -> (protectedOperation: ProtectedOperation?, riskLevel: RiskLevel, reason: String?) {
        guard let command = intent.commandPayload else {
            return (.workspaceWrite, .blocked, "Arbitrary shell execution is blocked")
        }

        guard let workspaceRoot = context.workspaceRoot ?? intent.workspaceRoot ?? command.workspaceRoot, !workspaceRoot.isEmpty else {
            return (.workspaceWrite, .blocked, "Workspace root is required for code actions")
        }

        let resolvedPath = context.workspaceRelativePath ?? intent.workspaceRelativePath ?? command.workspaceRelativePath
        if let relativePath = resolvedPath {
            if relativePath.hasPrefix("/") || relativePath.contains("../") {
                return (.workspaceWrite, .blocked, "Workspace path escapes the active workspace")
            }
        }

        if command.touchesNetwork {
            return (.externalNetworkFetch, .risky, "Remote network actions require approval")
        }

        switch command {
        case .build, .test, .code:
            return (nil, .low, nil)
        case .git(let spec):
            if spec.operation == .push {
                let summary = command.summary.lowercased()
                if summary.contains("--force") || summary.contains("force") || summary.contains("delete") || summary.contains(" rebase ") || summary.contains(" merge ") {
                    return (.destructiveVCS, .blocked, "Destructive VCS actions are blocked by policy")
                }
                return (.gitPush, .risky, "Git push requires approval")
            }
            return (nil, .low, nil)
        case .file:
            let path = resolvedPath ?? ""
            if path.isEmpty {
                return (.workspaceWrite, .blocked, "Workspace write target is missing")
            }
            return (.workspaceWrite, .risky, "Workspace write needs approval outside trusted test roots")
        case .ui:
            return (nil, .low, nil)
        }
    }'''

content = re.sub(p, r, content)
with open('Sources/OracleOS/Intent/Policies/PolicyRules.swift', 'w') as f:
    f.write(content)
