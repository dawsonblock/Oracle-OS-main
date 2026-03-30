import re
import sys

def main():
    # Fix Doctor
    with open("Sources/oracle/Doctor.swift", "r") as f:
        text = f.read()

    text = text.replace("func await checkProcesses", "func checkProcesses")
    text = text.replace("func await checkMCPConfig", "func checkMCPConfig")
    text = text.replace("func await checkVisionBinary", "func checkVisionBinary")

    text = text.replace("let cmd = Command(type: .action, payload: .diagnostic(spec), metadata: CommandMetadata(source: \"doctor\", context: [:]))", 
                        "let cmd = Command(type: .system, payload: .diagnostic(spec), metadata: CommandMetadata(intentID: UUID(), source: \"doctor\"))")

    with open("Sources/oracle/Doctor.swift", "w") as f:
        f.write(text)

    # Fix SetupWizard
    with open("Sources/oracle/SetupWizard.swift", "r") as f:
        setup_text = f.read()

    setup_text = setup_text.replace("let cmd = Command(type: .action, payload: .envSetup(spec), metadata: CommandMetadata(source: \"setup\", context: [:]))", 
                                    "let cmd = Command(type: .system, payload: .envSetup(spec), metadata: CommandMetadata(intentID: UUID(), source: \"setup\"))")

    with open("Sources/oracle/SetupWizard.swift", "w") as f:
        f.write(setup_text)

if __name__ == "__main__":
    main()
