import re

files_to_patch = {
    'Sources/OracleOS/Runtime/GoalClassifier.swift': [
        (r'if workspaceRoot != nil && codeMatches > 0 && osMatches > 0 {\n            return \.mixed\n        }', r'if workspaceRoot != nil && codeMatches > 0 && osMatches > 0 {\n            return .os\n        }'),
        (r'if codeMatches > 0 && osMatches > 0 {\n            return \.mixed\n        }', r'if codeMatches > 0 && osMatches > 0 {\n            return .os\n        }')
    ],
    'Sources/OracleOS/Runtime/TaskContext.swift': [
        (r'\s*case \.mixed:\n\s*\[\.handoff, \.engineering\]', r'')
    ],
    'Sources/OracleOS/Planning/Workflows/WorkflowReplayValidator.swift': [
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

print("Patched mixed references set 2")
