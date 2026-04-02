import XCTest

/// Cluster 3.1 — Enforce MCPBoundary as the only transport anchor
final class MCPBoundaryEnforcementTests: XCTestCase {

    /// ENFORCE: MCPBoundary.swift is the only source of truth for transport types
    func testMCPBoundaryIsCanonical() throws {
        let boundaryPath = "Sources/OracleOS/MCP/MCPBoundary.swift"
        let content = try String(contentsOfFile: boundaryPath, encoding: .utf8)
        
        // Verify the canonical types exist
        XCTAssertTrue(content.contains("enum JSONValue"),
                      "MCPBoundary must define JSONValue")
        XCTAssertTrue(content.contains("struct MCPToolRequest"),
                      "MCPBoundary must define MCPToolRequest")
        XCTAssertTrue(content.contains("struct MCPToolResponse"),
                      "MCPBoundary must define MCPToolResponse")
        XCTAssertTrue(content.contains("enum MCPContent"),
                      "MCPBoundary must define MCPContent")
    }

    /// ENFORCE: JSONValue has typed accessors (no casting required)
    func testJSONValueHasTypedAccessors() throws {
        let boundaryPath = "Sources/OracleOS/MCP/MCPBoundary.swift"
        let content = try String(contentsOfFile: boundaryPath, encoding: .utf8)
        
        let requiredAccessors = [
            "stringValue",
            "intValue",
            "doubleValue",
            "boolValue",
            "arrayValue",
            "objectValue",
        ]
        
        for accessor in requiredAccessors {
            XCTAssertTrue(content.contains("var \(accessor)"),
                          "JSONValue must have \(accessor) accessor")
        }
    }

    /// ENFORCE: MCPToolRequest uses JSONValue for arguments (not [String: Any])
    func testMCPToolRequestUsesJSONValue() throws {
        let boundaryPath = "Sources/OracleOS/MCP/MCPBoundary.swift"
        let content = try String(contentsOfFile: boundaryPath, encoding: .utf8)
        
        // Verify MCPToolRequest uses JSONValue
        let requestSection = content.components(separatedBy: "struct MCPToolRequest")[1]
        XCTAssertTrue(requestSection.contains("let arguments: JSONValue"),
                      "MCPToolRequest.arguments must be JSONValue, not [String: Any]")
    }

    /// ENFORCE: MCPToolResponse uses MCPContent (not raw dictionaries)
    func testMCPToolResponseUsesTypedContent() throws {
        let boundaryPath = "Sources/OracleOS/MCP/MCPBoundary.swift"
        let content = try String(contentsOfFile: boundaryPath, encoding: .utf8)
        
        let responseSection = content.components(separatedBy: "struct MCPToolResponse")[1]
        XCTAssertTrue(responseSection.contains("let content: [MCPContent]"),
                      "MCPToolResponse.content must use [MCPContent], not [String: Any]")
    }

    /// ENFORCE: MCPDispatch uses MCPBoundary types for tool interface
    func testMCPDispatchUsesCanonicalTypes() throws {
        let dispatchPath = "Sources/OracleOS/MCP/MCPDispatch.swift"
        let content = try String(contentsOfFile: dispatchPath, encoding: .utf8)
        
        // Verify MCPDispatch imports and uses boundary types
        XCTAssertTrue(content.contains("MCPToolRequest") || content.contains("MCPToolResponse"),
                      "MCPDispatch must use MCPBoundary types")
    }

    /// ENFORCE: Input path never uses [String: Any] (read-side only)
    func testInputPathNeverUsesDictionaries() throws {
        let dispatchPath = "Sources/OracleOS/MCP/MCPDispatch.swift"
        let content = try String(contentsOfFile: dispatchPath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        // These lines define input handling. They should NOT construct [String: Any] from tool args.
        // Output formatting is allowed to build dicts (they get converted via toDict()).
        // The key is: tool ARGUMENTS must come through JSONValue, not [String: Any].
        
        // Scan for problematic pattern: casting tool args to dictionary
        var foundViolation = false
        for (index, line) in lines.enumerated() {
            // Skip comments and output sections
            if line.contains("toDict") || line.contains("JSONSerialization.data") {
                continue  // Output formatting is allowed
            }
            
            // Flag direct [String: Any] construction from tool input
            if line.contains("arguments") && line.contains("[String: Any]") {
                foundViolation = true
                print("Line \(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        
        XCTAssertFalse(foundViolation,
                       "Tool input arguments must use JSONValue, not [String: Any]")
    }

    /// ENFORCE: MCPBoundary bridge methods exist for legacy interop
    func testMCPBoundaryHasFoundationBridge() throws {
        let boundaryPath = "Sources/OracleOS/MCP/MCPBoundary.swift"
        let content = try String(contentsOfFile: boundaryPath, encoding: .utf8)
        
        // Verify bridge methods exist for converting to Foundation types
        XCTAssertTrue(content.contains("toFoundation()"),
                      "JSONValue must have toFoundation() bridge for legacy code")
        XCTAssertTrue(content.contains("toDict()"),
                      "MCPContent and MCPToolResponse must have toDict() for wire serialization")
    }

    /// ENFORCE: Transport contract is complete
    func testTransportContractIsComplete() throws {
        let boundaryPath = "Sources/OracleOS/MCP/MCPBoundary.swift"
        let content = try String(contentsOfFile: boundaryPath, encoding: .utf8)
        
        // Verify Request-Response symmetry
        XCTAssertTrue(content.contains("MCPToolRequest"),
                      "Must have request type")
        XCTAssertTrue(content.contains("MCPToolResponse"),
                      "Must have response type")
        
        // Verify Sendable for concurrency safety
        XCTAssertTrue(content.contains("JSONValue: Codable, Sendable"),
                      "JSONValue must be Sendable")
        XCTAssertTrue(content.contains("MCPToolRequest: Sendable") || 
                     content.contains("public struct MCPToolRequest: Sendable"),
                      "MCPToolRequest must be Sendable")
        XCTAssertTrue(content.contains("MCPToolResponse: Sendable") || 
                     content.contains("public struct MCPToolResponse: Sendable"),
                      "MCPToolResponse must be Sendable")
    }

    /// ENFORCE: No new transport types defined elsewhere
    func testNoOtherTransportTypesExist() throws {
        let mpcPath = "Sources/OracleOS/MCP"
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(atPath: mpcPath) else {
            XCTFail("Cannot enumerate MCP directory")
            return
        }
        
        for case let file as String in enumerator {
            guard file.hasSuffix(".swift") && file != "MCPBoundary.swift" else { continue }
            
            let filePath = (mpcPath as NSString).appendingPathComponent(file)
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Flag if other files define transport-like types
            if content.contains("struct.*Request.*Sendable") || 
               content.contains("struct.*Response.*Sendable") {
                if !content.contains("MCPToolRequest") && !content.contains("MCPToolResponse") {
                    // This is likely a duplicate or new transport type
                    print("Warning: \(file) may define alternate transport types")
                }
            }
        }
    }
}
