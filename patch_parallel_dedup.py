import re

with open('Sources/OracleOS/Execution/Experiments/ParallelRunner.swift', 'r') as f:
    content = f.read()

# remove a single duplicat convertProcessResult
p = r"(    private func convertProcessResult\(\s*_ result: ProcessResult,\s*spec: Any,\s*category: CodeCommandCategory\s*\) -> CommandResult {.*?})\s*(    private func convertProcessResult\(\s*_ result: ProcessResult,\s*spec: Any,\s*category: CodeCommandCategory\s*\) -> CommandResult {.*?})"
new_content = re.sub(p, r"\1", content, flags=re.DOTALL)

with open('Sources/OracleOS/Execution/Experiments/ParallelRunner.swift', 'w') as f:
    f.write(new_content)
