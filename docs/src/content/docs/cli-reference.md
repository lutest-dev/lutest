---
title: CLI Reference
---

The current CLI is compact.

## Usage

```powershell
lutest [paths...]
```

## Help

```powershell
lutest --help
lutest -h
```

## Paths

When you pass paths, Lutest uses them as discovery inputs.

When you do not pass paths, Lutest uses `roots` from `lutest.toml`, or `.` when no config is present.

## Exit behavior

- exits with `0` when all discovered tests pass
- exits with `1` when discovery finds nothing
- exits with `1` when any test fails
