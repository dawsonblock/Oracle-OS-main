import re

with open('Sources/OracleOS/Planning/MainPlanner.swift', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'MixedTaskPlanner' in line:
        continue
    if 'mixedTaskPlanner:' in line:
        continue
    if 'self.mixedTaskPlanner =' in line:
        continue
    new_lines.append(line)

with open('Sources/OracleOS/Planning/MainPlanner.swift', 'w') as f:
    f.writelines(new_lines)
