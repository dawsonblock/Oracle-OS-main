# Phase 4: Memory Side Effect Decoupling

## Problem

Currently, memory recording is scattered:
- MemoryEventIngestor directly handles domain events
- MemoryUpdater directly mutates memory stores  
- Recording happens inline during execution
- No clear separation between execution spine and memory mutations

This couples memory concerns to the execution flow.

## Solution: Formal Projections

Convert direct mutations to projection pattern:
- **StrategyMemoryProjection**: Records controls, failures, strategies
- **ExecutionMemoryProjection**: Records command results
- **PatternMemoryProjection**: Records pattern success/failure

Each projection:
1. Takes immutable input (event or record)
2. Computes derived state
3. Writes to its memory store (side effect)
4. Optional: returns an Effect for async post-processing

## Key Benefits

1. **Decoupling**: Execution doesn't call memory mutators directly
2. **Testing**: Projections can be tested in isolation
3. **Async**: Projections can be run asynchronously without blocking execution
4. **Replay**: Projections can replay events from event log to rebuild state
5. **Clarity**: Clear dependency graph between events and memory tiers

## Architecture

```
DomainEvent
    ↓
MemoryEventIngestor (route to projections)
    ↓
    ├→ StrategyMemoryProjection → StrategyMemory
    ├→ ExecutionMemoryProjection → ExecutionMemoryStore  
    └→ PatternMemoryProjection → PatternMemoryStore

Result
    ↓
MemoryUpdater (helper for common patterns)
    ↓
    ├→ recordSuccess() → StrategyMemoryProjection
    └→ recordFailure() → StrategyMemoryProjection
```

## Migration Path

Phase 4.1: Create projection types and interfaces
Phase 4.2: Implement StrategyMemoryProjection
Phase 4.3: Implement ExecutionMemoryProjection  
Phase 4.4: Implement PatternMemoryProjection
Phase 4.5: Refactor MemoryEventIngestor to use projections
Phase 4.6: Add projection tests
