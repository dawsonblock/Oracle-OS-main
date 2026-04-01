---
name: phase-based-architecture-refactor
description: Workflow command scaffold for phase-based-architecture-refactor in Oracle-OS-main.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /phase-based-architecture-refactor

Use this workflow when working on **phase-based-architecture-refactor** in `Oracle-OS-main`.

## Goal

Formal, multi-phase architectural refactoring with documentation and code boundary enforcement. Each phase targets a specific architectural concern (e.g., execution boundary, planner simplification, event sourcing, memory projections, planner contract, persistence tiers, product boundary) and produces both code changes and a phase summary document.

## Common Files

- `docs/*.md`
- `PHASE_*_DONE.md`
- `REFACTOR_STATUS.md`
- `REFACTOR_COMPLETE.md`
- `Sources/OracleOS/Events/*`
- `Sources/OracleOS/Memory/*`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Implement code changes for the targeted architectural phase (e.g., decouple memory side effects, enforce event sourcing invariants, collapse planner surface).
- Update or add new documentation files summarizing the phase, its goals, and results (e.g., docs/..., PHASE_X_DONE.md, REFACTOR_STATUS.md).
- Add or update governance and boundary tests to enforce new invariants.
- Summarize the phase completion in a dedicated commit message and documentation.

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.