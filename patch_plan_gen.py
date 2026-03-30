import re

with open('Sources/OracleOS/Planning/Reasoning/PlanGenerator.swift', 'r') as f:
    text = f.read()

text = re.sub(r'    private let mixedTaskPlanner: MixedTaskPlanner\n', '', text)
text = re.sub(r'        mixedTaskPlanner: MixedTaskPlanner\? = nil\n', '', text)
text = re.sub(r'        self\.mixedTaskPlanner = mixedTaskPlanner \?\? MixedTaskPlanner\(\n.*?osPlanner: self\.osPlanner,\n.*?codePlanner: self\.codePlanner\n.*?\)\n', '', text, flags=re.DOTALL)


with open('Sources/OracleOS/Planning/Reasoning/PlanGenerator.swift', 'w') as f:
    f.write(text)
