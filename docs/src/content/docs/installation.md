---
title: Installation
---

You can install Lutest with a toolchain manager.

## mise

Add Lutest to your local `mise.toml`:

```toml
[tools]
"github:cayasde/lutest" = "latest"
```

Then install the tool:

```sh
mise install
```

After that, you can run:

```sh
lutest --help
```

## Rokit

If you use Rokit, add Lutest with:

```sh
rokit add cayasde/lutest
```

Then verify the install:

```sh
lutest --help
```

## Notes

Lutest is currently distributed through GitHub Releases.

If you want a reproducible setup, pin a specific version in your toolchain config instead of using the latest release.
