import re

with open("Sources/OracleOS/Planning/Strategies/StrategySelector.swift", "r") as f:
    text = f.read()

# Remove the legacy select method
pattern_select = r"// MARK: - Legacy entry point \(preserved for backward compatibility\)\n.*?// MARK: - Strategy resolution"
text = re.sub(pattern_select, "// MARK: - Strategy resolution", text, flags=re.DOTALL)

# Remove the StrategySelection struct entirely
pattern_struct = r"/// The result of strategy selection including the chosen strategy and metadata\.\npublic struct StrategySelection: Sendable \{.*?\n\}"
text = re.sub(pattern_struct, "", text, flags=re.DOTALL)

with open("Sources/OracleOS/Planning/Strategies/StrategySelector.swift", "w") as f:
    f.write(text)
