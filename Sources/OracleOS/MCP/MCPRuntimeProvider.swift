import Foundation

/// Manages cached access to the bootstrapped runtime.
///
/// This is the ONLY place that constructs or caches RuntimeBootstrap.
/// All MCP handlers access the runtime through this provider.
@MainActor
enum MCPRuntimeProvider {
    
    private static var _bootstrappedRuntime: BootstrappedRuntime?
    
    /// Get or create the bootstrapped runtime (cached after first use).
    ///
    /// This function is idempotent: multiple calls return the same runtime instance.
    /// Bootstrap happens once per process.
    static func getBootstrappedRuntime() async throws -> BootstrappedRuntime {
        if let existing = _bootstrappedRuntime {
            return existing
        }
        
        let built = try await RuntimeBootstrap.makeBootstrappedRuntime(configuration: .live())
        _bootstrappedRuntime = built
        
        if built.recoveryReport.didRecover {
            Log.info("Runtime recovery: replayed \(built.recoveryReport.eventsReplayed) events from \(built.recoveryReport.walEntriesRecovered) WAL entries")
        }
        
        return built
    }
    
    /// Access the cached runtime (must call getBootstrappedRuntime() first).
    ///
    /// This is a convenience for code that knows bootstrap has already happened.
    /// In normal flow, use getBootstrappedRuntime() instead.
    static var runtime: RuntimeOrchestrator? {
        _bootstrappedRuntime?.orchestrator
    }
    
    /// Access the cached container (must call getBootstrappedRuntime() first).
    static var container: RuntimeContainer? {
        _bootstrappedRuntime?.container
    }
}
