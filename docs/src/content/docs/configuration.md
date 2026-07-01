---
title: Configuration
---

Lutest reads `lutest.toml` from the project root.

The current shape is:

```toml
[discovery]
require = "@lib"
roots = ["."]
ignore = ["vendor", "luau_packages", ".git"]
gitignore = true
```

Most projects only need to care about three keys.

`require` tells Lutest which package path marks a module as test-bearing.

`roots` tells Lutest where to start when you run `lutest` with no explicit paths.

`ignore` prunes paths you never want discovery to scan.

`gitignore` is the switch that decides whether `.gitignore` should also be respected.

Here is the practical way to think about those settings:

- change `require` when your project uses a different import path for the Lutest package
- change `roots` when you do not want the default run to scan the whole repository
- change `ignore` when you have generated code, vendor code, or large directories that should always be skipped
