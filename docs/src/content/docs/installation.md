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

## Loom

Today, if you want to consume Lutest as a package inside a `lute` project, the practical path is Loom.

`pesde` and `wally` are not a good fit for Lutest in its current shape, so this project uses `lute`'s own package flow instead.

Create a `loom.config.luau` in your project root:

```luau
return {
	package = {
		name = "my-project",
		version = "0.1.1",
		dependencies = {
			lutest = {
				name = "lutest",
				rev = "v0.1.1",
				sourceKind = "github",
				source = "https://github.com/cayasde/lutest",
			},
		},
	},
}
```

Then install it with:

```sh
lute pkg install
```

That creates `loom.lock.luau` and installs the dependency into `Packages/`.

When you want to move to a newer release later, update `rev` to the new tag and run `lute pkg install` again.
