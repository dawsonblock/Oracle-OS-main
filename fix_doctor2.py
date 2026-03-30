import re
import sys

def main():
    with open("Sources/oracle/Doctor.swift", "r") as f:
        text = f.read()

    # Fix checkProcesses declaration
    text = text.replace("private mutating func await checkProcesses() async {", "private mutating func checkProcesses() async {")
    
    # Make checkMCPConfig async
    text = text.replace("private mutating func checkMCPConfig() {", "private mutating func checkMCPConfig() async {")
    text = text.replace("checkMCPConfig()", "await checkMCPConfig()")
    
    # Make checkVisionBinary async
    text = text.replace("private mutating func checkVisionBinary() {", "private mutating func checkVisionBinary() async {")
    text = text.replace("checkVisionBinary()", "await checkVisionBinary()")
    
    # Actually wait for the changes to not have "await await"
    text = text.replace("await await", "await")

    # Fix Command instantiation
    text = text.replace("let cmd = Command(payload: .diagnostic(spec))", "let cmd = Command(type: .action, payload: .diagnostic(spec), metadata: CommandMetadata(source: \"doctor\", context: [:]))")

    with open("Sources/oracle/Doctor.swift", "w") as f:
        f.write(text)

    # Note: also we need to fix SetupWizard command instantiation
    with open("Sources/oracle/SetupWizard.swift", "r") as f:
        setup_text = f.read()
    
    setup_text = setup_text.replace("let cmd = Command(payload: .envSetup(spec))", "let cmd = Command(type: .action, payload: .envSetup(spec), metadata: CommandMetadata(source: \"setup\", context: [:]))")
    
    with open("Sources/oracle/SetupWizard.swift", "w") as f:
        f.write(setup_text)

    with open("Sources/oracle/main.swift", "r") as f:
        main_text = f.read()
    main_text = main_text.replace("await await", "await")
    with open("Sources/oracle/main.swift", "w") as f:
        f.write(main_text)

if __name__ == "__main__":
    main()
