import re

with open('Sources/OracleOS/Execution/DefaultProcessAdapter.swift', 'r') as f:
    text = f.read()

text = text.replace('private func waitForProcess(_ process: Process', 'private func waitForProcess(_ process: Foundation.Process')

with open('Sources/OracleOS/Execution/DefaultProcessAdapter.swift', 'w') as f:
    f.write(text)
