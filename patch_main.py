import sys

def patch_main():
    path = "Sources/oracle/main.swift"
    with open(path, "r") as f:
        content = f.read()
        
    old_setup = """    case "setup":
        let wizard = SetupWizard()
        await wizard.run()"""
        
    new_setup = """    case "setup":
        guard let runtime = try? await RuntimeBootstrap.makeBootstrappedRuntime() else {
            print("Failed to initialize runtime")
            return
        }
        let wizard = SetupWizard(executor: runtime.container.executor)
        await wizard.run()"""
        
    old_doctor = """    case "doctor":
        var doctor = Doctor()
        await doctor.run()"""
        
    new_doctor = """    case "doctor":
        guard let runtime = try? await RuntimeBootstrap.makeBootstrappedRuntime() else {
            print("Failed to initialize runtime")
            return
        }
        var doctor = Doctor(executor: runtime.container.executor)
        await doctor.run()"""
        
    content = content.replace(old_setup, new_setup)
    content = content.replace(old_doctor, new_doctor)
    
    with open(path, "w") as f:
        f.write(content)

patch_main()
print("done main.swift")
