with open("Sources/OracleOS/Core/Command/Command.swift", "r") as f:
    text = f.read()

text = text.replace("""        case .code(let action):
            return action.name
        }""", """        case .code(let action):
            return action.name
        case .diagnostic(_):
            return "diagnostic"
        case .envSetup(_):
            return "envSetup"
        case .hostService(_):
            return "hostService"
        case .inference(_):
            return "inference"
        }""")

with open("Sources/OracleOS/Core/Command/Command.swift", "w") as f:
    f.write(text)
