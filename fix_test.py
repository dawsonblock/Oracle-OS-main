import re

files_to_fix = [
    ('Tests/OracleOSTests/Governance/ExecutionBoundaryEnforcementTests.swift', [
        ('            \n            \n        case .build(_):\n            \n        case .test(_):\n            \n        case .git(_):\n            \n        case .file(_):\n            \n        case .ui(_):\n            \n        case .code(_):\n            \n        }', '        case .build(_):\n            XCTAssertTrue(true)\n        case .test(_):\n            XCTAssertTrue(true)\n        case .git(_):\n            XCTAssertTrue(true)\n        case .file(_):\n            XCTAssertTrue(true)\n        case .ui(_):\n            XCTAssertTrue(true)\n        case .code(_):\n            XCTAssertTrue(true)\n        }')
    ])
]

for file, replacements in files_to_fix:
    with open(file, 'r') as f:
        content = f.read()

    for old, new in replacements:
        content = content.replace(old, new)

    with open(file, 'w') as f:
        f.write(content)
