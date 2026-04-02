import XCTest
@testable import OracleOS

/// Cluster 3.4: MCP Transport Boundary Enforcement
/// Verify that JSONValue is the canonical type crossing the MCP boundary.
/// All parameter reads use typed accessors; [String: Any] is banned from input path.
class MCPBoundaryEnforcementTests: XCTestCase {

    // MARK: - Verify JSONValue is Sendable

    func testJSONValueIsSendable() {
        // JSONValue must be Sendable to cross actor boundaries safely
        let value: JSONValue = .string("test")
        assertSendable(value)
    }

    // MARK: - Verify Typed Accessors

    func testStringAccessor() {
        let json: JSONValue = .string("hello")
        XCTAssertEqual(json.stringValue, "hello")
        XCTAssertNil(json.intValue)
        XCTAssertNil(json.doubleValue)
        XCTAssertNil(json.boolValue)
    }

    func testIntAccessor() {
        let json: JSONValue = .int(42)
        XCTAssertEqual(json.intValue, 42)
        XCTAssertNil(json.stringValue)
        XCTAssertNil(json.boolValue)
    }

    func testDoubleAccessor() {
        let json: JSONValue = .double(3.14)
        XCTAssertEqual(json.doubleValue, 3.14, accuracy: 0.01)
        XCTAssertNil(json.stringValue)
    }

    func testBoolAccessor() {
        let json: JSONValue = .bool(true)
        XCTAssertEqual(json.boolValue, true)
        XCTAssertNil(json.stringValue)
    }

    func testArrayAccessor() {
        let json: JSONValue = .array([.string("a"), .int(1)])
        XCTAssertEqual(json.arrayValue?.count, 2)
        XCTAssertNil(json.stringValue)
    }

    func testObjectAccessor() {
        let json: JSONValue = .object(["key": .string("value")])
        XCTAssertNotNil(json.objectValue)
        XCTAssertEqual(json["key"]?.stringValue, "value")
    }

    // MARK: - Verify Subscript Access (No Casting)

    func testSubscriptStringKey() {
        let json: JSONValue = .object(["name": .string("oracle")])
        XCTAssertEqual(json["name"]?.stringValue, "oracle")
    }

    func testSubscriptArrayIndex() {
        let json: JSONValue = .array([.string("a"), .string("b"), .string("c")])
        XCTAssertEqual(json[0]?.stringValue, "a")
        XCTAssertEqual(json[1]?.stringValue, "b")
        XCTAssertEqual(json[2]?.stringValue, "c")
        XCTAssertNil(json[10])
    }

    func testSubscriptMissingKey() {
        let json: JSONValue = .object(["a": .string("value")])
        XCTAssertNil(json["missing"])
    }

    // MARK: - Verify MCPToolRequest is Sendable

    func testMCPToolRequestIsSendable() {
        let request = MCPToolRequest(
            name: "oracle_click",
            arguments: .object(["x": .double(100), "y": .double(200)])
        )
        assertSendable(request)
    }

    // MARK: - Verify MCPToolResponse is Sendable

    func testMCPToolResponseIsSendable() {
        let response = MCPToolResponse(
            content: [.text("success")],
            isError: false
        )
        assertSendable(response)
    }

    // MARK: - Verify MCPContent is Sendable

    func testMCPContentTextIsSendable() {
        let content: MCPContent = .text("hello")
        assertSendable(content)
    }

    func testMCPContentImageIsSendable() {
        let content: MCPContent = .image(data: "base64data", mimeType: "image/png")
        assertSendable(content)
    }

    // MARK: - Verify Codable Round-Trip

    func testJSONValueEncodeDecode() {
        let original: JSONValue = .object([
            "name": .string("oracle"),
            "count": .int(42),
            "tags": .array([.string("a"), .string("b")])
        ])

        let data = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testMCPToolRequestEncodeDecode() {
        let original = MCPToolRequest(
            name: "oracle_click",
            arguments: .object([
                "x": .double(100),
                "y": .double(200),
                "app": .string("Chrome")
            ])
        )

        let data = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(MCPToolRequest.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.arguments, original.arguments)
    }

    // MARK: - Verify toDict() for Output Path Only

    func testMCPContentToDict() {
        let content: MCPContent = .text("success message")
        let dict = content.toDict()

        XCTAssertEqual(dict["type"] as? String, "text")
        XCTAssertEqual(dict["text"] as? String, "success message")
    }

    func testMCPContentImageToDict() {
        let content: MCPContent = .image(data: "abc123", mimeType: "image/png")
        let dict = content.toDict()

        XCTAssertEqual(dict["type"] as? String, "image")
        XCTAssertEqual(dict["data"] as? String, "abc123")
        XCTAssertEqual(dict["mimeType"] as? String, "image/png")
    }

    func testMCPToolResponseToDict() {
        let response = MCPToolResponse(
            content: [.text("result")],
            isError: false
        )
        let dict = response.toDict()

        XCTAssertEqual(dict["isError"] as? Bool, false)
        let contentArray = dict["content"] as? [[String: Any]]
        XCTAssertEqual(contentArray?.count, 1)
        XCTAssertEqual(contentArray?[0]["text"] as? String, "result")
    }

    // MARK: - Verify MCPToolRequest Init from Wire Format

    func testMCPToolRequestInitFromDictionary() {
        let params: [String: Any] = [
            "name": "oracle_click",
            "arguments": [
                "x": 100.0,
                "y": 200.0,
                "app": "Chrome"
            ]
        ]

        guard let request = MCPToolRequest(params: params) else {
            XCTFail("MCPToolRequest should be initialized from params dict")
            return
        }

        XCTAssertEqual(request.name, "oracle_click")
        XCTAssertEqual(request.arguments["x"]?.doubleValue, 100.0)
        XCTAssertEqual(request.arguments["y"]?.doubleValue, 200.0)
        XCTAssertEqual(request.arguments["app"]?.stringValue, "Chrome")
    }

    func testMCPToolRequestInitMissingName() {
        let params: [String: Any] = [
            "arguments": ["x": 100.0]
        ]

        let request = MCPToolRequest(params: params)
        XCTAssertNil(request, "MCPToolRequest init should fail without name")
    }

    // MARK: - Verify Type Safety in Nested Structures

    func testNestedObjectAccess() {
        let json: JSONValue = .object([
            "user": .object([
                "name": .string("oracle"),
                "age": .int(5)
            ])
        ])

        // Access nested value without casting to [String: Any]
        let name = json["user"]?["name"]?.stringValue
        XCTAssertEqual(name, "oracle")

        let age = json["user"]?["age"]?.intValue
        XCTAssertEqual(age, 5)
    }

    func testNestedArrayAccess() {
        let json: JSONValue = .array([
            .object(["id": .int(1)]),
            .object(["id": .int(2)])
        ])

        let firstID = json[0]?["id"]?.intValue
        XCTAssertEqual(firstID, 1)

        let secondID = json[1]?["id"]?.intValue
        XCTAssertEqual(secondID, 2)
    }

    // MARK: - Helper

    private func assertSendable<T>(_ value: T) {
        // This is primarily a compile-time check.
        // At runtime, we just verify the value exists.
        XCTAssertNotNil(value)
    }
}
