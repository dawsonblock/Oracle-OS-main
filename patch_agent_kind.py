import re

with open('Sources/OracleOS/Runtime/AgentKind.swift', 'r') as f:
    text = f.read()

text = re.sub(r'\s*case \.mixed', '', text)
text = re.sub(r'\s*case mixed', '', text)

with open('Sources/OracleOS/Runtime/AgentKind.swift', 'w') as f:
    f.write(text)
