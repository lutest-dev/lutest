---
title: CLI Reference
---

The current CLI is compact.

## Usage

```powershell
lutest test [paths...] [--runtime lute|roblox]
```

```powershell
lutest todo [paths...] [--runtime lute|roblox]
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

When you pass paths to `lutest test` or `lutest todo`, Lutest uses them as discovery inputs. Without `--runtime`, both commands use `lute`.

When you do not pass paths to `lutest test` or `lutest todo`, Lutest uses roots for the selected runtime from `lutest.toml`, or `.` for the local runtime when no config is present.

## Exit behavior

- exits with `0` when all discovered tests pass
- exits with `1` when discovery finds nothing
- exits with `1` when any test fails
- exits with `1` when a Roblox remote execution cannot complete
