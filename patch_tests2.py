import re
import os

path = "Tests/OracleOSTests/Core/StrategyLayerTests.swift"
with open(path, "r") as f:
    text = f.read()

text = text.replace("selector.select(", "selector.selectStrategy(")

text = re.sub(
    r"#expect\(selection\.selected\.kind == \.recovery\)\n\s*#expect\(selection\.conditions\.contains\(\.modalPresent\)\)",
    "#expect(selection.kind == .recoveryMode)",
    text
)

text = re.sub(
    r"#expect\(selection\.conditions\.contains\(\.repositoryOpen\)\)\n\s*#expect\(selection\.conditions\.contains\(\.testsFailing\)\)\n\s*let strategyKind = selection\.selected\.kind\n\s*#expect\(strategyKind == \.testFix \|\| strategyKind == \.codeRepair\)",
    "let strategyKind = selection.kind\n        #expect(strategyKind == .repoRepair)",
    text
)

text = re.sub(
    r"#expect\(selection\.selected\.kind != \.recovery\)\n\s*#expect\(selection\.score > 0\)",
    "#expect(selection.kind != .recoveryMode)\n        #expect(selection.confidence > 0)",
    text
)

text = text.replace("#expect(withMemory.score >= withoutMemory.score)", "#expect(withMemory.confidence >= withoutMemory.confidence)")

text = text.replace("#expect(!selection.alternatives.isEmpty || selection.score > 0)", "#expect(selection.confidence > 0)")

with open(path, "w") as f:
    f.write(text)
