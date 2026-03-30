import re

files_to_patch = {
    'Sources/OracleOS/Planning/Strategies/StrategySelector.swift': [
        (r'if \(agentKind == \.code \|\| agentKind == \.mixed\)', r'if agentKind == .code'),
        (r'applicableAgentKinds: \[\.code, \.mixed\]', r'applicableAgentKinds: [.code]'),
        (r'applicableAgentKinds: \[\.os, \.mixed\]', r'applicableAgentKinds: [.os]')
    ],
    'Sources/OracleOS/Planning/Workflows/WorkflowIndex.swift': [
        (r'\|\| agentKind == \.mixed\n', r''),
    ],
    'Sources/OracleOS/Runtime/PlanningContext.swift': [
        (r'agentKind: AgentKind = \.mixed', r'agentKind: AgentKind = .code'),
    ],
    'Sources/OracleOS/Planning/Memory/UnifiedMemoryStore.swift': [
        (r'\(context.agentKind == \.code \|\| context.agentKind == \.mixed \|\| context.agentKind == nil\)', r'(context.agentKind == .code || context.agentKind == nil)'),
    ],
    'Sources/OracleOS/Planning/MainPlanner.swift': [
        (r'\s*case \.mixed:\n\s*return \.operatingSystem', r''),
        (r'\s*case \.mixed:\n\s*return \.mixed', r''),
    ],
    'Sources/OracleOS/Runtime/RuntimeExecutionDriver.swift': [
        (r'\(intent.agentKind == \.mixed \? \.system : \.ui\)', r'.ui'),
        (r'\(intent\.agentKind == \.mixed \? \.system : \.ui\)', r'.ui')
    ],
    'Sources/OracleOS/Intent/Actions/Actions.swift': [
        (r'\s*case \.mixed: \.mixed', r''),
        (r'case \.os, \.mixed:', r'case .os:')
    ],
    'Sources/OracleOS/Planning/Workflows/WorkflowSynthesizer.swift': [
        (r'\s*case PlannerFamily\.mixed\.rawValue:\n\s*return \.handoff', r'')
    ]
}

for file_path, replacements in files_to_patch.items():
    with open(file_path, 'r') as f:
        text = f.read()
    
    for old, new in replacements:
        text = re.sub(old, new, text)
        
    with open(file_path, 'w') as f:
        f.write(text)

print("Patched mixed references")

