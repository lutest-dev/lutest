---
title: Lutest
description: A test runner for Luau projects, centered today on the lute runtime and co-located test authoring.
---

Lutest is a test runner for Luau projects.

Today it is aimed at the `lute` runtime. Its job is simple: let you keep tests close to the code they exercise without turning every module into a special testing shape.

Here is the smallest useful example:

```luau
local t = require("@lib")

t.test("adds numbers", function()
	assert(1 + 2 == 3)
end)
```

When you run Lutest, that module is discovered, loaded, and treated as one suite.

That leads to three practical differences:

- tests can live next to normal modules
- modules do not need to return suite objects
- internal helpers can stay testable without artificial public APIs

If you have used `lute`'s built-in test runner before, the biggest shift is discovery. Lutest is not built around `*.test.luau` or `*.spec.luau` as the main contract.

## Start here

1. Go to [Installation](./installation/).
2. Follow [First Test](./first-test/).
3. Continue to [Running Tests](./running-tests/).
