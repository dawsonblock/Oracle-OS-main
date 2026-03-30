import sys

def patch_file():
    path = "Sources/oracle/SetupWizard.swift"
    with open(path, "r") as f:
        content = f.read()
        
    content = content.replace("""struct SetupWizard {

    func run()\"", """struct SetupWizard {
    let executor: VerifiedExecutor

    func run()""")
    content = content.replace(
        "let executor = VerifiedExecutor()",
        "// let executor = VerifiedExecutor()"
    )
    
    with open(path, "w") as f:
        f.write(content)

patch_file()
print("done setupwizard")
