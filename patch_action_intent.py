import re

with open('Sources/OracleOS/Execution/ActionIntent.swift', 'r') as f:
    content = f.read()

# Replace `codeCommand: CommandSpec?` with `commandPayload: CommandPayload?`
content = content.replace('public let codeCommand: CommandSpec?', 'public let commandPayload: CommandPayload?')
content = content.replace('codeCommand: CommandSpec? = nil,', 'commandPayload: CommandPayload? = nil,')
content = content.replace('self.codeCommand = codeCommand', 'self.commandPayload = commandPayload')
content = content.replace('commandCategory: String? { codeCommand?.category.rawValue }', 'commandCategory: String? { commandPayload?.categoryName }')
content = content.replace('commandSummary: String? { codeCommand?.summary }', 'commandSummary: String? { commandPayload?.summary }')
content = content.replace('workspaceRoot ?? codeCommand?.workspaceRoot', 'workspaceRoot ?? commandPayload?.workspaceRoot')
content = content.replace('workspaceRelativePath ?? codeCommand?.workspaceRelativePath', 'workspaceRelativePath ?? commandPayload?.workspaceRelativePath')

p1 = r'''    public static func code\(
        name: String\? = nil,
        command: CommandSpec,
        workspaceRelativePath: String\? = nil,
        text: String\? = nil,
        postconditions: \[Postcondition\] = \[\]
    \) -> ActionIntent \{
        ActionIntent\(
            agentKind: \.code,
            app: "Workspace",
            name: name \?\? command\.summary,
            action: command\.category\.rawValue,
            query: workspaceRelativePath \?\? command\.workspaceRelativePath,
            text: text,
            workspaceRoot: command\.workspaceRoot,
            workspaceRelativePath: workspaceRelativePath \?\? command\.workspaceRelativePath,
            codeCommand: command,
            postconditions: postconditions
        \)
    \}'''
r1 = '''    public static func code(
        name: String? = nil,
        command: CommandPayload,
        workspaceRelativePath: String? = nil,
        text: String? = nil,
        postconditions: [Postcondition] = []
    ) -> ActionIntent {
        ActionIntent(
            agentKind: .code,
            app: "Workspace",
            name: name ?? command.summary,
            action: command.categoryName,
            query: workspaceRelativePath ?? command.workspaceRelativePath,
            text: text,
            workspaceRoot: command.workspaceRoot,
            workspaceRelativePath: workspaceRelativePath ?? command.workspaceRelativePath,
            commandPayload: command,
            postconditions: postconditions
        )
    }'''

content = re.sub(p1, r1, content)
with open('Sources/OracleOS/Execution/ActionIntent.swift', 'w') as f:
    f.write(content)
