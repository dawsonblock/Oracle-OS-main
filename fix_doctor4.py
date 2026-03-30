import re
import sys

def main():
    # Fix SetupWizard
    with open("Sources/oracle/SetupWizard.swift", "r") as f:
        setup_text = f.read()

    # outcome.events.compactMap ... => outcome.observations.map { $0.content }.joined(separator: "\n")
    setup_text = setup_text.replace(
        "let output = outcome.events.compactMap { $0.details[\"observation\"] ?? $0.details[\"content\"] }.joined(separator: \"\\n\")",
        "let output = outcome.observations.map { $0.content }.joined(separator: \"\\n\")"
    )
    setup_text = setup_text.replace(
        "return ShellResult(output: outcome.reason ?? \"\", exitCode: 1)",
        "return ShellResult(output: outcome.verifierReport.notes.first ?? outcome.status.rawValue, exitCode: 1)"
    )
    setup_text = setup_text.replace(
        "print(\"  ERROR: \\(outcome.reason ?? \"\")\")",
        "print(\"  ERROR: \\(outcome.verifierReport.notes.first ?? outcome.status.rawValue)\")"
    )

    with open("Sources/oracle/SetupWizard.swift", "w") as f:
        f.write(setup_text)

    # Fix Doctor
    with open("Sources/oracle/Doctor.swift", "r") as f:
        doctor_text = f.read()

    doctor_text = doctor_text.replace(
        "let output = outcome.events.compactMap { $0.details[\"observation\"] ?? $0.details[\"content\"] }.joined(separator: \"\\n\")",
        "let output = outcome.observations.map { $0.content }.joined(separator: \"\\n\")"
    )
    doctor_text = doctor_text.replace(
        "return ShellResult(output: outcome.reason ?? \"\", exitCode: 1)",
        "return ShellResult(output: outcome.verifierReport.notes.first ?? outcome.status.rawValue, exitCode: 1)"
    )

    with open("Sources/oracle/Doctor.swift", "w") as f:
        f.write(doctor_text)

if __name__ == "__main__":
    main()
