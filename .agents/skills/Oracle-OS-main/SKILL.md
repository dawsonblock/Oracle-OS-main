```markdown
# Oracle-OS-main Development Patterns

> Auto-generated skill from repository analysis

## Overview

This skill teaches you the core development patterns, coding conventions, and architectural workflows used in the `Oracle-OS-main` Swift codebase. The repository is focused on building a robust, modular system with strong boundaries, explicit dependency management, and phased architectural refactoring. It emphasizes clarity, safety, and maintainability through strict typing, clear documentation, and systematic removal of legacy code.

## Coding Conventions

- **File Naming:**  
  Use PascalCase for all file names.
  - Example: `MainPlanner.swift`, `VerifiedExecutor.swift`

- **Import Style:**  
  Use absolute imports.
  - Example:
    ```swift
    import OracleOSCore
    ```

- **Export Style:**  
  Use default exports for modules and types.

- **Commit Message Patterns:**  
  - Prefixes: `refactor:`, `feat:`, `fix:`
  - Example:  
    ```
    refactor: enforce execution boundary in planner and update related tests
    ```

- **Initializer and Dependency Injection:**  
  Require explicit dependencies in initializers; avoid default values and optionals.
  - Example:
    ```swift
    class Planner {
        let memoryStore: MemoryStore
        let repositoryIndexer: RepositoryIndexer

        init(memoryStore: MemoryStore, repositoryIndexer: RepositoryIndexer) {
            self.memoryStore = memoryStore
            self.repositoryIndexer = repositoryIndexer
        }
    }
    ```

## Workflows

### Phase-Based Architecture Refactor
**Trigger:** When undertaking a major architectural refactor or kernel hardening  
**Command:** `/start-architecture-phase`

1. Identify the architectural concern for the current phase (e.g., execution boundary, planner simplification).
2. Implement code changes for the targeted phase (e.g., decouple memory side effects, enforce event sourcing).
3. Update or add documentation files summarizing the phase, its goals, and results (e.g., `docs/PHASE_1_DONE.md`).
4. Add or update governance and boundary tests to enforce new invariants.
5. Summarize phase completion in a dedicated commit and documentation.

**Example:**
```markdown
# PHASE_2_DONE.md

## Goal
Collapse planner surface and enforce event sourcing invariants.

## Summary
- Refactored `MainPlanner.swift` to remove legacy entry points.
- Updated governance tests.
```

---

### Typed Command and Execution Boundary Enforcement
**Trigger:** When strengthening runtime safety or removing legacy execution paths  
**Command:** `/enforce-typed-commands`

1. Remove or refactor legacy command cases (e.g., `.shell`) from `Command.swift` and related files.
2. Update routers, planners, and executors to handle only typed commands/specs.
3. Update or add governance and execution boundary tests.
4. Update policy and planning logic to validate by type.
5. Document changes and update phase/rebuild summary files.

**Example:**
```swift
// Before
enum Command {
    case shell(String)
    case build(BuildSpec)
}

// After
enum Command {
    case build(BuildSpec)
    case test(TestSpec)
    case fileMutation(FileMutationSpec)
}
```

---

### Refactor Initializers and Dependencies
**Trigger:** When improving code clarity and enforcing dependency injection  
**Command:** `/refactor-initializers`

1. Update class initializers to require explicit parameters.
2. Remove default values and optional parameters from constructors.
3. Update all instantiations in source and test files to provide required dependencies.
4. Add or update convenience initializers for testing as needed.
5. Update related test files for compatibility.

**Example:**
```swift
// Before
init(memoryStore: MemoryStore? = nil) { ... }

// After
init(memoryStore: MemoryStore) { ... }
```

---

### Remove Legacy or Obsolete Code Paths
**Trigger:** When cleaning up after a major refactor or deprecating legacy features  
**Command:** `/remove-legacy-paths`

1. Identify and remove obsolete files (e.g., patching scripts, deprecated planners).
2. Update all references to ensure no usage of removed paths.
3. Update or add tests to confirm absence of legacy code.
4. Document removals in phase or rebuild summary files.

**Example:**
```diff
- Sources/OracleOS/Planning/MixedTaskPlanner.swift
- fix_legacy_patch.py
```

---

### Documentation and Phase Summary Update
**Trigger:** When a phase is completed or architectural changes need to be communicated  
**Command:** `/update-phase-docs`

1. Create or update summary markdown files (e.g., `PHASE_X_DONE.md`, `REFACTOR_STATUS.md`).
2. Document what changed, key insights, and next steps.
3. Ensure documentation matches the current codebase state.

**Example:**
```markdown
# REFACTOR_STATUS.md

- Phase 3 complete: Event sourcing invariants enforced.
- Next: Memory projection refactor.
```

## Testing Patterns

- **Framework:** Unknown (not explicitly detected)
- **Test File Pattern:** `*.test.ts` (note: this may be legacy or for non-Swift portions)
- **Governance Tests:**  
  Specialized tests enforce architectural boundaries and invariants.
  - Example:  
    `Tests/OracleOSTests/Governance/ExecutionBoundaryTests.swift`

- **Test Update Pattern:**  
  When refactoring, always update or add tests to reflect new boundaries or removed code.

## Commands

| Command                  | Purpose                                                        |
|--------------------------|----------------------------------------------------------------|
| /start-architecture-phase| Begin a new architectural refactor phase                       |
| /enforce-typed-commands  | Enforce strict typed command and execution boundaries          |
| /refactor-initializers   | Refactor initializers to require explicit dependencies         |
| /remove-legacy-paths     | Remove legacy or obsolete code paths and update references     |
| /update-phase-docs       | Update documentation and phase summary files                   |
```