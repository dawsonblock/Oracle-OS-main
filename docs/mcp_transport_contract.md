# Phase 3: MCP Transport Contract

## Transport Boundary

MCPBoundary.swift is the ONLY sanctioned transport contract for MCP tool communication.

```
Wire (JSON-RPC)
    ↓
MCPServer (parses JSON)
    ↓
MCPToolRequest (name: String, arguments: JSONValue)
    ↓
MCPDispatch.handle(MCPToolRequest)
    ↓
Tool Handler (reads args via JSONValue accessors, not casting)
    ↓
MCPToolResponse (content: [MCPContent], isError: Bool)
    ↓
MCPServer (serializes to wire)
    ↓
Wire (JSON-RPC)
```

## Contract Enforcement

### JSONValue as the Dynamic Carrier
- **What it is**: Typed, Sendable enum representing JSON
- **When to use**: All tool argument reading
- **What it replaces**: `[String: Any]` casts on input path
- **Accessors**: `stringValue`, `intValue`, `doubleValue`, `boolValue`, `arrayValue`, `objectValue`

### MCPToolRequest (Inbound)
- **Sendable**: Yes (concurrency-safe)
- **Fields**:
  - `name: String` — tool name
  - `arguments: JSONValue` — typed JSON payload
- **Rule**: Read arguments ONLY through JSONValue accessors, never cast to dictionary

### MCPToolResponse (Outbound)
- **Sendable**: Yes (concurrency-safe)
- **Fields**:
  - `content: [MCPContent]` — response units
  - `isError: Bool` — error flag
- **Constructors**: `.error(message)`, `.imageAndCaption(...)`

### MCPContent (Response Content)
- **Sendable**: Yes
- **Types**: `.text(String)`, `.image(data: String, mimeType: String)`
- **Serialization**: `toDict()` converts to wire format

## Migration Path

### Before (Violations)
```swift
// In MCPDispatch tool handler:
let argsDict = request.arguments as? [String: Any]  // ❌ VIOLATION
let recipeName = argsDict?["name"] as? String
let params = argsDict?["params"] as? [String: Any]
```

### After (Correct)
```swift
// In MCPDispatch tool handler:
let recipeName = request.arguments["name"]?.stringValue  // ✅ CORRECT
let params = request.arguments["params"]?.objectValue
```

## Boundaries to Enforce

### Input Path (Strict)
- ✅ JSONValue subscript accessors
- ❌ No `[String: Any]` casting
- ❌ No direct dictionary access

### Internal Tool Handlers
- ✅ May build `[String: Any]` for internal use
- ✅ May use JSONSerialization internally
- ✅ Must NOT leak dictionaries to response building

### Output Path (Typed)
- ✅ Build MCPContent units
- ✅ MCPToolResponse wraps content
- ✅ Call `toDict()` only at wire boundary

## Cluster 3.1 Completion

✅ MCPBoundary.swift is the canonical transport anchor  
✅ JSONValue is the only dynamic carrier  
✅ MCPToolRequest/Response are properly typed  
✅ Sendable compliance verified  
✅ Enforcement tests in place  

## Next: Cluster 3.2

Decompose MCPDispatch into:
- MCPRuntimeProvider (cached runtime)
- MCPToolRouter (request routing)
- MCPDispatch (thin orchestration)
