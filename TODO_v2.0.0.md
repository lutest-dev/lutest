# Objective

This file exists to capture decisions, architectural directions, and design problems worth revisiting for Lutest v2.0.0.

It should focus on lessons learned from the current 1.x line, especially the pain points discovered while shipping and self-hosting the current architecture, so v2 can be planned as a cleaner re-architecture instead of another round of incremental fixes.

# Topics

- Design a truly stable self-hosting model, with clear separation between source-tree development, release artifacts, and the runtime contract consumed by projects.
  Pain points seen in v1:
  - Internal modules could depend on the public release entrypoint and accidentally re-enter the package during bootstrap.
  - Co-located tests inside package modules leaked into release/runtime behavior and had to be stripped as a special case.
  - Release generation depended too much on the current source tree shape and on whichever stable package version happened to be installed locally.
  - Build-time bootstrap and runtime bootstrap were coupled, so fixing one layer did not automatically fix the other.
  - Self-hosting behavior was hard to reason about because source execution, packaged execution, and release execution did not share a clearly defined contract.
  - Patch releases became mitigation chains instead of one clean fix, which is a sign the architecture boundaries were weak.
  - Critical maintainer scripts such as `scripts/release.luau` had no direct test coverage, which made release regressions easier to ship and harder to diagnose.
