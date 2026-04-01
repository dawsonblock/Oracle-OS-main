import Foundation

/// Reducers are the ONLY entities that may update committed WorldState.
///
/// **Invariants**:
/// 1. **Deterministic**: Same input (event stream) always yields same output (state)
/// 2. **Idempotent**: apply(events, state) twice yields same final state as once
/// 3. **No side effects**: Only state mutation; no I/O, no calls to external systems
/// 4. **Total function**: Must handle all event types (no exceptions)
///
/// **Why**:
/// - Determinism ensures replay works: old events → same state
/// - Idempotency ensures crash recovery: partially applied events are safe to re-apply
/// - No side effects ensures state mutation is the only outcome
/// - Totality ensures corruption is caught early
///
/// **Enforcement**:
/// - `apply()` receives immutable events
/// - State is passed `inout` so reducer can mutate it, but nothing else
/// - Reducers run under lock in `CommitCoordinator`
/// - Events are stored in append-only `EventStore` before reducer runs
///
/// **Testing**:
/// - Every reducer must have "idempotent" test: replay same events twice, assert state is identical
/// - Every reducer must have "replay" test: apply subset of events, verify each intermediate state
/// - Every reducer must handle unknown event types gracefully (ignore or error, never corrupt)
public protocol EventReducer: Sendable {
    /// Apply a batch of events to the world state.
    /// MUST be idempotent: apply(events, s) == apply(apply(events, s), events)
    /// MUST be deterministic: same events always produce same mutations
    func apply(events: [EventEnvelope], to state: inout WorldStateModel)
}
