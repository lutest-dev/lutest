---
title: CLI Reference
---

The current CLI is compact.

## Usage

```powershell
lutest test [paths...]
```

```powershell
lutest todo [paths...]
```

## Version

```powershell
lutest version
```

## Help

```powershell
lutest help
```

## Paths

When you pass paths to `lutest test` or `lutest todo`, Lutest uses them as discovery inputs.

When you do not pass paths to `lutest test` or `lutest todo`, Lutest uses `roots` from `lutest.toml`, or `.` when no config is present.

## Exit behavior

- exits with `0` when all discovered tests pass
- exits with `1` when discovery finds nothing
- exits with `1` when any test fails
