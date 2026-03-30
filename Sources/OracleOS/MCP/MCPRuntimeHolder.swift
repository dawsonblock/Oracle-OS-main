import Foundation

/// Safely holds and lazily initializes the single Oracle OS runtime
/// for the MCP process. Eliminates synchronous file access on main thread.
public actor MCPRuntimeHolder {
    public static let shared = MCPRuntimeHolder()
    
    private var bootstrappedRuntime: BootstrappedRuntime?
    private var runtimeContext: RuntimeContext?
    
    private init() {}
    
    public func getBootstrappedRuntime() async throws -> BootstrappedRuntime {
        if let existing = bootstrappedRuntime {
            return existing
        }
        
        let runtime = try await RuntimeBootstrap.makeBootstrappedRuntime(configuration: .live())
        bootstrappedRuntime = runtime
        return runtime
    }
    
    public func getRuntimeContext() async throws -> RuntimeContext {
        if let existing = runtimeContext {
            return existing
        }
        
        let bootstrapped = try await getBootstrappedRuntime()
        let ctx = RuntimeContext(container: bootstrapped.container)
        self.runtimeContext = ctx
        return ctx
    }
}
