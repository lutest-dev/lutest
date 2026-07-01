---
title: Running Tests
---

Once you have a test module, running it is straightforward.

With no arguments, Lutest uses the `roots` from `lutest.toml`:

```powershell
lutest
```

If you want to run only one path, pass it directly:

```powershell
lutest tests
```

You can also pass more than one path:

```powershell
lutest src tests
```

That is the whole shape of the current CLI. You pass paths in, and Lutest runs the test modules it discovers there.

If discovery finds nothing, Lutest exits with a failure status and prints:

```text
no test modules found
```

When tests do run, output is grouped by module path. You will see totals for passed, failed, skipped, and `todo` tests, plus per-test error messages when something fails.
