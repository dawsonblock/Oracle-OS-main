```markdown
# Oracle-OS-main Development Patterns

> Auto-generated skill from repository analysis

## Overview

This skill provides a comprehensive guide to developing, extending, and maintaining the `Oracle-OS-main` codebase. The repository is primarily written in Swift and implements a modular, agent-oriented operating system kernel. It features strong architectural boundaries, conventional commit practices, and a focus on extensibility through skills, bundles, and agent definitions. This guide covers coding conventions, core workflows, testing patterns, and recommended commands for contributors.

## Coding Conventions

**File Naming**
- Use PascalCase for Swift source files and most code artifacts.
  - Example: `MainPlanner.swift`, `MCPDispatch.swift`

**Import Style**
- Use absolute imports in Swift files.
  - Example:
    ```swift
    import OracleOSCore
    import Foundation
    ```

**Export Style**
- Use default exports for modules and classes.
  - Example:
    ```swift
    public class MainPlanner { ... }
    ```

**Commit Messages**
- Follow [Conventional Commits](https://www.conventionalcommits.org/) with prefixes:
  - `feat`: For new features
  - `refactor`: For refactoring existing code
  - `fix`: For bug fixes
- Commit messages are typically concise but descriptive (average ~89 characters).
  - Example: `feat: add ECC agent skill integration for new bundle support`

## Workflows

### Feature Bundle Integration / ECC or Agent Skill

**Trigger:** When adding a new ECC bundle, agent skill, or capability to Oracle-OS-main  
**Command:** `/add-ecc-bundle`

1. Add or update `SKILL.md` in `.agents/skills/Oracle-OS-main/` and/or `.claude/skills/Oracle-OS-main/`.
2. Add or update agent definition YAML (e.g., `openai.yaml`) in `.agents/skills/Oracle-OS-main/agents/`.
3. Update or add ECC tools/configuration files:
    - `.claude/ecc-tools.json`
    - `.claude/identity.json`
4. Add or update Codex agent TOML files in `.codex/agents/*.toml`, and update `.codex/AGENTS.md` and `.codex/config.toml`.
5. Update or add instincts YAML in `.claude/homunculus/instincts/inherited/Oracle-OS-main-instincts.yaml`.
6. Update documentation and command markdowns in `.claude/commands/*.md`.

**Example: Adding a new agent skill**
```bash
cp .agents/skills/Oracle-OS-main/SKILL.md .agents/skills/Oracle-OS-main/skills/NewSkill.md
# Edit the new SKILL.md to document the new skill
vim .agents/skills/Oracle-OS-main/skills/NewSkill.md
```

---

### Core Refactor or Feature with Test Update

**Trigger:** When refactoring core logic or adding new features, ensuring tests are updated  
**Command:** `/refactor-core-feature`

1. Modify core Swift source files in `Sources/OracleOS/` (e.g., `MCPDispatch.swift`, `MainPlanner.swift`, `Command.swift`).
2. Update or add tests in `Tests/OracleOSTests/` and/or `Tests/OracleOSEvals/`.
3. Optionally update or add Python/JS patch/fix scripts for migration or compatibility.
4. Update documentation or phase-completion markers (e.g., `PHASE_X_DONE.md`, `REBUILD_PLAN.md`).

**Example: Refactoring a core module**
```swift
// Sources/OracleOS/Core/Command/Command.swift
public class Command {
    // Refactored logic here
}
```
```swift
// Tests/OracleOSTests/Core/CommandTests.swift
func testCommandExecution() {
    let command = Command()
    XCTAssertTrue(command.execute())
}
```

---

### Governance, Boundary, or Invariant Test Hardening

**Trigger:** When enforcing or verifying architectural boundaries, execution constraints, or durability invariants  
**Command:** `/add-governance-test`

1. Add or update test files in `Tests/OracleOSTests/Governance/` (e.g., `ExecutionBoundaryTests.swift`).
2. Update or refactor related core files to match new invariants (`Command.swift`, `PolicyEngine.swift`, routers).
3. Optionally update or remove transitional scripts or artifacts.
4. Mark phase completion in `PHASE_X_DONE.md` or similar.

**Example: Adding an invariant test**
```swift
// Tests/OracleOSTests/Governance/RuntimeInvariantTests.swift
func testKernelInvariant() {
    let kernel = OracleOSKernel()
    XCTAssertTrue(kernel.enforcesInvariant())
}
```

---

### Removal of Transitional or Obsolete Scripts

**Trigger:** When a major refactor or rebuild is complete and legacy scripts/artifacts are obsolete  
**Command:** `/cleanup-transitional-scripts`

1. Identify and delete `fix_*.py`, `patch_*.py`, `overwrite_script.py`, and similar transitional scripts.
2. Optionally update documentation to reflect cleanup.
3. Commit with a message referencing cleanup or removal.

**Example:**
```bash
rm fix_migration.py patch_legacy.py overwrite_script.py
git commit -am "chore: remove obsolete transitional scripts after refactor"
```

## Testing Patterns

- **Framework:** Not explicitly detected; tests are written in Swift, likely using XCTest or similar.
- **Test File Pattern:** Swift test files are in `Tests/OracleOSTests/` and subdirectories, named with `*Tests.swift`.
- **Test Structure:** Each test file targets a specific module or feature, with clear function-based test cases.

**Example:**
```swift
import XCTest

final class MainPlannerTests: XCTestCase {
    func testPlanGeneration() {
        let planner = MainPlanner()
        XCTAssertNotNil(planner.generatePlan())
    }
}
```

## Commands

| Command                     | Purpose                                                      |
|-----------------------------|--------------------------------------------------------------|
| /add-ecc-bundle             | Integrate a new ECC bundle or agent skill                    |
| /refactor-core-feature      | Refactor or add core features with corresponding tests       |
| /add-governance-test        | Add or update governance, boundary, or invariant tests       |
| /cleanup-transitional-scripts | Remove obsolete or transitional scripts after refactors      |
```
