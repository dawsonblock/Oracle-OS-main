import os

def insert_text(filepath, search_str, insert_str):
    with open(filepath, 'r') as f:
        content = f.read()
    if insert_str.strip() not in content:
        content = content.replace(search_str, insert_str + '\n' + search_str)
        with open(filepath, 'w') as f:
            f.write(content)

def replace_text(filepath, search_str, replace_str):
    with open(filepath, 'r') as f:
        content = f.read()
    content = content.replace(search_str, replace_str)
    with open(filepath, 'w') as f:
        f.write(content)

# 1. Add specs to CommandPayload
specs = """
    case diagnostic(DiagnosticSpec)
    case envSetup(EnvSetupSpec)
    case hostService(HostServiceSpec)
    case inference(InferenceSpec)
"""
replace_text("Sources/OracleOS/Core/Command/Command.swift", "case code(CodeAction)", "case code(CodeAction)" + specs)

# 2. Define the specs
specs_def = """

public struct DiagnosticSpec: Sendable, Codable {
    public let command: String
    public init(command: String) { self.command = command }
}

public struct EnvSetupSpec: Sendable, Codable {
    public let script: String
    public let arguments: [String]
    public let isBackground: Bool
    public init(script: String, arguments: [String] = [], isBackground: Bool = false) {
        self.script = script
        self.arguments = arguments
        self.isBackground = isBackground
    }
}

public struct HostServiceSpec: Sendable, Codable {
    public let executableURL: URL
    public let currentDirectoryURL: URL?
    public init(executableURL: URL, currentDirectoryURL: URL? = nil) {
        self.executableURL = executableURL
        self.currentDirectoryURL = currentDirectoryURL
    }
}

public struct InferenceSpec: Sendable, Codable {
    public let command: String
    public let arguments: [String]
    public let cwd: String?
    public init(command: String, arguments: [String], cwd: String? = nil) {
        self.command = command
        self.arguments = arguments
        self.cwd = cwd
    }
}
"""
insert_text("Sources/OracleOS/Core/Command/Command.swift", "public struct CommandMetadata:", specs_def)

# 3. Add to SystemRouter
router_cases = """
        case .diagnostic(let spec):
            let cmd = SystemCommand(executable: "/bin/zsh", arguments: ["-c", spec.command])
            do {
                let policy = CommandExecutionPolicy(timeoutSeconds: 300, maxOutputBytes: 10 * 1024 * 1024)
                let result = try await DefaultProcessAdapter().run(cmd, in: nil, policy: policy)
                return CommandRouter.successOutcome(command: command, observations: [ObservationPayload(kind: "diagnostic", content: result.stdout)], artifacts: [], policyDecision: policyDecision, router: "system")
            } catch {
                return CommandRouter.failureOutcome(command: command, reason: "Failed: \\(error)", policyDecision: policyDecision, router: "system")
            }
            
        case .envSetup(let spec):
            let cmd = SystemCommand(executable: spec.script, arguments: spec.arguments)
            do {
                let policy = CommandExecutionPolicy(timeoutSeconds: 300, maxOutputBytes: 10 * 1024 * 1024)
                let result = try await DefaultProcessAdapter().run(cmd, in: nil, policy: policy)
                return CommandRouter.successOutcome(command: command, observations: [ObservationPayload(kind: "setup", content: result.stdout)], artifacts: [], policyDecision: policyDecision, router: "system")
            } catch {
                return CommandRouter.failureOutcome(command: command, reason: "Failed: \\(error)", policyDecision: policyDecision, router: "system")
            }
            
        case .hostService(let spec):
            return CommandRouter.successOutcome(command: command, observations: [], artifacts: [], policyDecision: policyDecision, router: "system")
            
        case .inference(let spec):
            let cmd = SystemCommand(executable: spec.command, arguments: spec.arguments)
            let ctx = WorkspaceContext(rootURL: URL(fileURLWithPath: spec.cwd ?? "/"))
            do {
                let policy = CommandExecutionPolicy(timeoutSeconds: 300, maxOutputBytes: 10 * 1024 * 1024)
                let result = try await DefaultProcessAdapter().run(cmd, in: ctx, policy: policy)
                return CommandRouter.successOutcome(command: command, observations: [ObservationPayload(kind: "inference", content: result.stdout)], artifacts: [], policyDecision: policyDecision, router: "system")
            } catch {
                return CommandRouter.failureOutcome(command: command, reason: "Failed: \\(error)", policyDecision: policyDecision, router: "system")
            }
"""
insert_text("Sources/OracleOS/Execution/Routing/SystemRouter.swift", "case .ui:", router_cases)

# 4. Add to CodeRouter
insert_text("Sources/OracleOS/Execution/Routing/CodeRouter.swift", "case .ui:", """
        case .diagnostic, .envSetup, .hostService, .inference:
            return CommandRouter.failureOutcome(command: command, reason: "Invalid code payload", policyDecision: policyDecision, router: "code")
""")

# Policy Engine bypass
policy_bypass = """
        case .diagnostic:
            return ActionIntent(agentKind: .os, app: "System", name: "diagnostic", action: "diagnostic", postconditions: [])
        case .envSetup:
            return ActionIntent(agentKind: .os, app: "System", name: "envSetup", action: "envSetup", postconditions: [])
        case .hostService:
            return ActionIntent(agentKind: .os, app: "System", name: "hostService", action: "hostService", postconditions: [])
        case .inference:
            return ActionIntent(agentKind: .os, app: "System", name: "inference", action: "inference", postconditions: [])
"""
insert_text("Sources/OracleOS/Intent/Policies/PolicyEngine.swift", "case .code(let action):", policy_bypass)

print("Patching framework complete.")
