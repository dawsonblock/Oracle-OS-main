# Diagnostics

Diagnostics are only valid when regenerated for the current commit on a Swift-capable host.

Stale diagnostics are archived in `docs/archive/diagnostics/` for historical reference only.

To generate fresh diagnostics:
```
swift build
swift test
```

See `STATUS.md` for the current truth about what is authoritative and what is not.
