#!/usr/bin/env python3
"""MCP boundary guard for Oracle-OS.

Enforces the sealed MCP transport contract:
- MCPDispatch.dispatch() must use JSONValue + typed accessors
- MCPDispatch must not cast arguments to [String: Any]
- MCPServer (wire edge) and toDict() methods are exceptions

Rule: Inside MCPDispatch.dispatch(), all parameter reads must use:
  - args[key]?.stringValue
  - args[key]?.intValue
  - args[key]?.doubleValue
  - args[key]?.boolValue
  - args[key]?.arrayValue
  - args[key]?.objectValue

Never:
  - args as? [String: Any]
  - JSONSerialization + cast to [String: Any] in input path
"""

import os
import re
import sys

def scan_mcp_dispatch():
    """
    Scan MCPDispatch.swift for [String: Any] usage in the input path.
    
    Allow:
    - MCPServer.swift (wire edge, already escaped)
    - Lines in formatResult, errorContent, toDict methods
    - Comments
    
    Flag:
    - dispatch() function using [String: Any]
    - Any cast of 'args' or 'request' to [String: Any]
    """
    
    path = "Sources/OracleOS/MCP/MCPDispatch.swift"
    
    if not os.path.isfile(path):
        print(f"Warning: {path} not found, skipping MCP boundary guard.")
        return []
    
    with open(path) as f:
        lines = f.readlines()
    
    violations = []
    in_dispatch = False
    in_response_formatting = False
    dispatch_start_line = 0
    
    for lineno, line in enumerate(lines, 1):
        stripped = line.lstrip()
        
        # Skip comments
        if stripped.startswith("//"):
            continue
        
        # Track when we enter dispatch() function
        if "private static func dispatch(request: MCPToolRequest)" in line:
            in_dispatch = True
            dispatch_start_line = lineno
            in_response_formatting = False
        elif in_dispatch and "private static func " in line and "dispatch" not in line:
            in_dispatch = False
            in_response_formatting = True
        elif in_dispatch and "} // MARK:" in line:
            in_dispatch = False
            in_response_formatting = True
        
        # Inside dispatch(), check for [String: Any] patterns
        if in_dispatch:
            # Check for direct cast of args or request
            if re.search(r'\bas\?\s*\[\s*String\s*:\s*Any\s*\]', line):
                violations.append((lineno, line.rstrip(), "Found 'as? [String: Any]' cast in dispatch()"))
            
            # Check for JSONSerialization producing [String: Any] in input path
            if "JSONSerialization" in line and "objectValue" not in line:
                # This is likely a serialization in the response path, but flag it
                if "as?" in line and "[String: Any]" in line:
                    violations.append((lineno, line.rstrip(), "Found JSONSerialization + [String: Any] cast in dispatch()"))
    
    return violations


def main():
    violations = scan_mcp_dispatch()
    
    if violations:
        print("\nMCP BOUNDARY VIOLATIONS FOUND\n")
        print("Rule: dispatch() must use JSONValue typed accessors (e.g. args[key]?.stringValue)")
        print("      never cast to [String: Any] in the input path.\n")
        
        for lineno, line, reason in violations:
            print(f"Sources/OracleOS/MCP/MCPDispatch.swift:{lineno}")
            print(f"  {line}")
            print(f"  -> {reason}\n")
        
        sys.exit(1)
    
    print("MCP boundary guard passed.")
    sys.exit(0)


if __name__ == "__main__":
    main()
