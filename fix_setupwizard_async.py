import re
import sys

def main():
    with open("Sources/oracle/SetupWizard.swift", "r") as f:
        text = f.read()

    # We previously ran `re.sub(r'runShell\(', 'await runShell(', text)` which was disastrous.
    # Let's fix that.
    text = text.replace("private func await runShell(", "private func runShell(")
    text = text.replace("private func await runShellLive(", "private func runShellLive(")
    text = text.replace("await await", "await")

    # Fix inline async issues:
    text = text.replace("let hasPython = checkPythonWithMLX()", "let hasPython = await checkPythonWithMLX()")
    text = text.replace("if !setupPythonVenv() {", "if await !setupPythonVenv() {")
    text = text.replace("|| await runShell(", "|| (await runShell(")
    text = text.replace(").exitCode == 0", ")).exitCode == 0")

    text = text.replace("private func downloadModel() -> Bool {", "private func downloadModel() async -> Bool {")
    text = text.replace("let hasModel = downloadModel()", "let hasModel = await downloadModel()")

    text = text.replace("await configureMCP()", "await configureMCP()") # Might duplicate, ensure clean
    
    # Let's fix the || await error correctly:
    text = text.replace("|| (await runShell(\"which claude 2>/dev/null\")).exitCode == 0", "|| (await runShell(\"which claude 2>/dev/null\").exitCode == 0)")

    with open("Sources/oracle/SetupWizard.swift", "w") as f:
        f.write(text)

if __name__ == "__main__":
    main()
