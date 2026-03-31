// MCPBoundary.swift - Typed contracts for MCP tool communication
//
// This file defines the canonical types that cross the MCP boundary.
// All tool input arrives as MCPToolRequest (name + JSONValue arguments).
// All tool output leaves as MCPToolResponse (typed content array).
//
// Rule: [String: Any] must never appear on the input path inside MCPDispatch.
//       Use JSONValue subscript accessors everywhere input args are read.

import Foundation

// MARK: - JSONValue

/// A typed, Sendable representation of JSON.
///
/// Use this as the only dynamic carrier inside MCPDispatch.
/// Never cast to [String: Any] on the input path.
///
/// Typed accessors (stringValue, intValue, doubleValue, boolValue,
/// arrayValue, objectValue) replace all "as? T" casts on args.
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    // MARK: Subscript access

    /// Returns the value for `key` if this is an object, else nil.
    public subscript(key: String) -> JSONValue? {
        guard case .object(let dict) = self else { return nil }
        return dict[key]
    }

    /// Returns the element at `index` if this is an array and index is in range, else nil.
    public subscript(index: Int) -> JSONValue? {
        guard case .array(let arr) = self, arr.indices.contains(index) else { return nil }
        return arr[index]
    }

    // MARK: Typed accessors

    public var stringValue: String? {
        guard case .string(let s) = self else { return nil }
        return s
    }

    public var intValue: Int? {
        switch self {
        case .int(let i):    return i
        case .double(let d): return Int(exactly: d)
        default:             return nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i):    return Double(i)
        default:             return nil
        }
    }

    public var boolValue: Bool? {
        guard case .bool(let b) = self else { return nil }
        return b
    }

    public var arrayValue: [JSONValue]? {
        guard case .array(let a) = self else { return nil }
        return a
    }

    public var objectValue: [String: JSONValue]? {
        guard case .object(let o) = self else { return nil }
        return o
    }

    // MARK: Foundation interop

    /// Convert to a Foundation-compatible Any for callers that still need it
    /// (e.g. JSONSerialization, legacy ToolResult data payloads).
    /// Prefer typed accessors over toFoundation() in new code.
    public func toFoundation() -> Any {
        switch self {
        case .null:           return NSNull()
        case .bool(let b):    return b
        case .int(let i):     return i
        case .double(let d):  return d
        case .string(let s):  return s
        case .array(let a):   return a.map { $0.toFoundation() }
        case .object(let o):  return o.mapValues { $0.toFoundation() }
        }
    }

    // MARK: Codable

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? c.decode(Int.self) {
            self = .int(i)
        } else if let d = try? c.decode(Double.self) {
            self = .double(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else {
            self = .object(try c.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null:           try c.encodeNil()
        case .bool(let b):    try c.encode(b)
        case .int(let i):     try c.encode(i)
        case .double(let d):  try c.encode(d)
        case .string(let s):  try c.encode(s)
        case .array(let a):   try c.encode(a)
        case .object(let o):  try c.encode(o)
        }
    }
}

// MARK: - MCPToolRequest

/// An inbound MCP tools/call request.
///
/// `arguments` is the typed JSON payload — use JSONValue subscript
/// accessors to extract values. Do not call toFoundation() and cast
/// to [String: Any] inside dispatch logic.
public struct MCPToolRequest: Sendable {
    public let name: String
    public let arguments: JSONValue

    public init(name: String, arguments: JSONValue) {
        self.name = name
        self.arguments = arguments
    }

    /// Build from a raw JSON-RPC params dict (called once at the wire edge in MCPServer).
    public init?(params: [String: Any]) {
        guard let name = params["name"] as? String else { return nil }
        self.name = name
        // Decode arguments via JSONSerialization round-trip to produce typed JSONValue.
        if let argsObj = params["arguments"],
           let data = try? JSONSerialization.data(withJSONObject: argsObj),
           let value = try? JSONDecoder().decode(JSONValue.self, from: data) {
            self.arguments = value
        } else {
            self.arguments = .object([:])
        }
    }
}

// MARK: - MCPContent

/// A single unit of MCP response content.
public enum MCPContent: Sendable {
    case text(String)
    case image(data: String, mimeType: String)

    /// Serialise to the [String: Any] dict MCPServer writes to the wire.
    public func toDict() -> [String: Any] {
        switch self {
        case .text(let s):
            return ["type": "text", "text": s]
        case .image(let d, let m):
            return ["type": "image", "data": d, "mimeType": m]
        }
    }
}

// MARK: - MCPToolResponse

/// An outbound MCP tools/call response.
public struct MCPToolResponse: Sendable {
    public let content: [MCPContent]
    public let isError: Bool

    public init(content: [MCPContent], isError: Bool = false) {
        self.content = content
        self.isError = isError
    }

    /// Convenience: inline error response.
    public static func error(_ message: String) -> MCPToolResponse {
        MCPToolResponse(content: [.text(message)], isError: true)
    }

    /// Convenience: image with text caption (MCP v1 dual-content pattern).
    public static func imageAndCaption(
        base64: String,
        mimeType: String,
        caption: String
    ) -> MCPToolResponse {
        MCPToolResponse(
            content: [.image(data: base64, mimeType: mimeType), .text(caption)],
            isError: false
        )
    }

    /// Serialise to the [String: Any] dict MCPServer writes to the wire.
    public func toDict() -> [String: Any] {
        [
            "content": content.map { $0.toDict() },
            "isError": isError,
        ]
    }
}
