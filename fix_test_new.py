with open("Tests/OracleOSTests/Governance/ExecutionBoundaryTests.swift", "r") as f:
    c = f.read()
    
new_c = c.replace('    }\n}', '''    }

    func testNoLegacyPlannersOrExperimentalMemoryExist() throws {
        let sourcesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")

        guard let enumerator = FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            XCTFail("Could not enumerate Sources directory")
            return
        }

        var badFiles = [String]()
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let name = fileURL.lastPathComponent
            if name.contains("PlannerFacade") || name.contains("ExperimentalMemory") || name.contains("LegacyPlanner") {
                badFiles.append(name)
            }
        }
        XCTAssertTrue(badFiles.isEmpty, "Found legacy planners or experimental memory paths: \\(badFiles.joined(separator: ", "))")
    }
}''')

with open("Tests/OracleOSTests/Governance/ExecutionBoundaryTests.swift", "w") as f:
    f.write(new_c)
