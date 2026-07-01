---
title: Philosophy
---

This page explains the choices behind the current model.

Lutest is closer to how tests are commonly written in [Rust](https://rust-lang.org/) projects than to a separate-file test model.

## Why co-located tests

When tests live next to the code they exercise, they are easier to keep in sync with that code.

## Why avoid artificial public APIs

Internal helpers and non-exported behavior should stay testable without adding public APIs only for tests.

## Why use `assert`

Normal Luau `assert` already solves a large part of the problem.

Lutest does not try to replace it with a second assertion DSL right away.

## Why not make `.spec.luau` the main contract

Filename-based discovery tends to push tests into separate files and shape the code around that limitation.

Lutest instead treats a module as interesting because it depends on the configured Lutest package path.
