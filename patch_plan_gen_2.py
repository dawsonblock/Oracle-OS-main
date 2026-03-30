import re

with open('Sources/OracleOS/Planning/Reasoning/PlanGenerator.swift', 'r') as f:
    text = f.read()

text = re.sub(r'        case \.mixed:\n.*?mixedTaskPlanner\.nextStep\(\n.*?\)', '', text, flags=re.DOTALL)
text = re.sub(r'        case \.mixed:\n            return mixedTaskPlanner\.nextStep\(\n.*?\n            \)\n', '', text, flags=re.DOTALL)

with open('Sources/OracleOS/Planning/Reasoning/PlanGenerator.swift', 'w') as f:
    f.write(text)

with open('Sources/OracleOS/Planning/MainPlanner.swift', 'r') as f:
    text2 = f.read()

text2 = re.sub(r'        case \.mixed:\n            return mixedTaskPlanner\.nextStep\(\n.*?\n            \)\n', '', text2, flags=re.DOTALL)

with open('Sources/OracleOS/Planning/MainPlanner.swift', 'w') as f:
    f.write(text2)
