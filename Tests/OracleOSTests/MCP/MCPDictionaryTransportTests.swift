import XCTest
@testable import OracleOS

/// Cluster 3.4: MCP Dictionary Transport Tests
/// Verify that JSONValue correctly models JSON data without losing type information.
/// Test encoding/decoding round-trips and wire format compatibility.
class MCPDictionaryTransportTests: XCTestCase {

    // MARK: - JSON Null Handling

    func testNullEncoding() {
        let value: JSONValue = .null
        let data = try! JSONEncoder().encode(value)
        let json = try! JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(json is NSNull)
    }

    func testNullDecoding() {
        let data = "null".data(using: .utf8)!
        let value = try! JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(value, .null)
    }

    // MARK: - JSON Boolean Handling

    func testBooleanTrue() {
        let value: JSONValue = .bool(true)
        let data = try! JSONEncoder().encode(value)
        let json = try! JSONSerialization.jsonObject(with: data)
        XCTAssertEqual(json as? NSNumber, 1 as NSNumber)
    }

    func testBooleanFalse() {
        let value: JSONValue = .bool(false)
        let data = try! JSONEncoder().encode(value)
        let json = try! JSONSerialization.jsonObject(with: data)
        XCTAssertEqual(json as? NSNumber, 0 as NSNumber)
    }

    // MARK: - JSON Number Handling (Int vs Double)

    func testIntPreservation() {
        let value: JSONValue = .int(42)
        let data = try! JSONEncoder().encode(value)
        let json = try! JSONSerialization.jsonObject(with: data) as! NSNumber
        XCTAssertEqual(json.intValue, 42)
    }

    func testDoublePreservation() {
        let value: JSONValue = .double(3.14)
        let data = try! JSONEncoder().encode(value)
        let json = try! JSONSerialization.jsonObject(with: data) as! NSNumber
        XCTAssertEqual(json.doubleValue, 3.14, accuracy: 0.01)
    }

    func testIntToDoubleConversion() {
        let json: JSONValue = .int(42)
        XCTAssertEqual(json.doubleValue, 42.0)
    }

    func testDoubleToIntConversion() {
        let json: JSONValue = .double(42.0)
        XCTAssertEqual(json.intValue, 42)
    }

    func testDoubleToIntConversionRoundsDown() {
        let json: JSONValue = .double(42.7)
        XCTAssertNil(json.intValue)  // Fractional part lost
    }

    // MARK: - JSON String Handling

    func testStringWithSpecialCharacters() {
        let value: JSONValue = .string("hello\nworld\t\"quoted\"")
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded.stringValue, "hello\nworld\t\"quoted\"")
    }

    func testUnicodeString() {
        let value: JSONValue = .string("こんにちは世界 🌍")
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded.stringValue, "こんにちは世界 🌍")
    }

    // MARK: - JSON Array Handling

    func testEmptyArray() {
        let value: JSONValue = .array([])
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded.arrayValue?.count, 0)
    }

    func testHomogeneousArray() {
        let value: JSONValue = .array([.int(1), .int(2), .int(3)])
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded.arrayValue?.count, 3)
        XCTAssertEqual(decoded[0]?.intValue, 1)
        XCTAssertEqual(decoded[1]?.intValue, 2)
        XCTAssertEqual(decoded[2]?.intValue, 3)
    }

    func testHeterogeneousArray() {
        let value: JSONValue = .array([
            .string("text"),
            .int(42),
            .double(3.14),
            .bool(true),
            .null
        ])
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded[0]?.stringValue, "text")
        XCTAssertEqual(decoded[1]?.intValue, 42)
        XCTAssertEqual(decoded[2]?.doubleValue, 3.14, accuracy: 0.01)
        XCTAssertEqual(decoded[3]?.boolValue, true)
        XCTAssertEqual(decoded[4], .null)
    }

    func testNestedArray() {
        let value: JSONValue = .array([
            .array([.int(1), .int(2)]),
            .array([.int(3), .int(4)])
        ])
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded[0]?[0]?.intValue, 1)
        XCTAssertEqual(decoded[1]?[1]?.intValue, 4)
    }

    // MARK: - JSON Object Handling

    func testEmptyObject() {
        let value: JSONValue = .object([:])
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded.objectValue?.count, 0)
    }

    func testSimpleObject() {
        let value: JSONValue = .object([
            "name": .string("oracle"),
            "version": .int(1),
            "active": .bool(true)
        ])
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded["name"]?.stringValue, "oracle")
        XCTAssertEqual(decoded["version"]?.intValue, 1)
        XCTAssertEqual(decoded["active"]?.boolValue, true)
    }

    func testObjectWithSpecialKeys() {
        let value: JSONValue = .object([
            "key-with-dash": .string("value"),
            "key.with.dot": .string("value"),
            "key with space": .string("value"),
            "": .string("empty key")
        ])
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded["key-with-dash"]?.stringValue, "value")
        XCTAssertEqual(decoded["key.with.dot"]?.stringValue, "value")
        XCTAssertEqual(decoded["key with space"]?.stringValue, "value")
        XCTAssertEqual(decoded[""]?.stringValue, "empty key")
    }

    func testNestedObject() {
        let value: JSONValue = .object([
            "user": .object([
                "name": .string("oracle"),
                "profile": .object([
                    "role": .string("assistant"),
                    "level": .int(42)
                ])
            ])
        ])
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded["user"]?["profile"]?["role"]?.stringValue, "assistant")
        XCTAssertEqual(decoded["user"]?["profile"]?["level"]?.intValue, 42)
    }

    // MARK: - toFoundation() Conversion

    func testToFoundationNull() {
        let value: JSONValue = .null
        let result = value.toFoundation()
        XCTAssertTrue(result is NSNull)
    }

    func testToFoundationBool() {
        let value: JSONValue = .bool(true)
        let result = value.toFoundation() as? Bool
        XCTAssertEqual(result, true)
    }

    func testToFoundationInt() {
        let value: JSONValue = .int(42)
        let result = value.toFoundation() as? Int
        XCTAssertEqual(result, 42)
    }

    func testToFoundationDouble() {
        let value: JSONValue = .double(3.14)
        let result = value.toFoundation() as? Double
        XCTAssertEqual(result, 3.14, accuracy: 0.01)
    }

    func testToFoundationString() {
        let value: JSONValue = .string("hello")
        let result = value.toFoundation() as? String
        XCTAssertEqual(result, "hello")
    }

    func testToFoundationArray() {
        let value: JSONValue = .array([.int(1), .int(2)])
        let result = value.toFoundation() as? [Any]
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?[0] as? Int, 1)
    }

    func testToFoundationObject() {
        let value: JSONValue = .object(["key": .string("value")])
        let result = value.toFoundation() as? [String: Any]
        XCTAssertEqual(result?["key"] as? String, "value")
    }

    // MARK: - Round-Trip via Foundation

    func testRoundTripThroughFoundation() {
        let original: JSONValue = .object([
            "name": .string("oracle"),
            "tags": .array([.string("a"), .string("b")]),
            "config": .object(["debug": .bool(true)])
        ])

        // Convert to Foundation types
        let foundation = original.toFoundation() as! [String: Any]

        // Simulate wire transmission (JSON serialization)
        let data = try! JSONSerialization.data(withJSONObject: foundation)

        // Deserialize back to JSONValue
        let dict = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let decoded = try! JSONDecoder().decode(
            JSONValue.self,
            from: try! JSONSerialization.data(withJSONObject: dict)
        )

        XCTAssertEqual(decoded, original)
    }

    // MARK: - MCP Tool Call Example

    func testMCPToolCallParameterExtraction() {
        // Simulate a wire message
        let wireParams: [String: Any] = [
            "name": "oracle_click",
            "arguments": [
                "x": 100.0,
                "y": 200.0,
                "app": "Chrome",
                "count": 1
            ]
        ]

        // Parse into MCPToolRequest (this uses JSONValue internally)
        guard let request = MCPToolRequest(params: wireParams) else {
            XCTFail("Failed to create MCPToolRequest")
            return
        }

        // Extract parameters using typed accessors
        let x = request.arguments["x"]?.doubleValue
        let y = request.arguments["y"]?.doubleValue
        let app = request.arguments["app"]?.stringValue
        let count = request.arguments["count"]?.intValue

        XCTAssertEqual(x, 100.0)
        XCTAssertEqual(y, 200.0)
        XCTAssertEqual(app, "Chrome")
        XCTAssertEqual(count, 1)
    }

    func testMCPToolResponseSerialization() {
        // Create a response with mixed types
        let response = MCPToolResponse(
            content: [.text("{\"success\": true, \"count\": 42}")],
            isError: false
        )

        // Convert to wire format
        let dict = response.toDict()
        let data = try! JSONSerialization.data(withJSONObject: dict)
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["isError"] as? Bool, false)
        let contentArray = json["content"] as? [[String: Any]]
        XCTAssertEqual(contentArray?.count, 1)
    }

    // MARK: - Large Structure Handling

    func testLargeArray() {
        var elements: [JSONValue] = []
        for i in 0..<1000 {
            elements.append(.int(i))
        }
        let value: JSONValue = .array(elements)
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded.arrayValue?.count, 1000)
        XCTAssertEqual(decoded[999]?.intValue, 999)
    }

    func testDeeplyNestedObject() {
        var value: JSONValue = .string("leaf")
        for _ in 0..<10 {
            value = .object(["level": value])
        }
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)

        var current = decoded
        for _ in 0..<10 {
            current = current["level"] ?? .null
        }
        XCTAssertEqual(current.stringValue, "leaf")
    }
}
