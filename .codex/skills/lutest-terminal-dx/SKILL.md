---
name: lutest-terminal-dx
description: Design or revise Lutest terminal UX, including CLI copy, help, errors, reports, colors, symbols, interactive prompts, and Roblox progress. Use when changing any user-visible terminal output or when reviewing its clarity, consistency, accessibility, TTY behavior, or CI output.
---

# Lutest Terminal DX

Make Lutest feel like one calm, precise terminal product. Apply this skill
alongside `lutest-error-handling` whenever an error message changes.

## Workflow

1. Inspect every affected output path and capture real current output.
2. Update `dx-viewer.html` with the complete proposed output first.
3. Do not change runtime or CLI output until the user explicitly approves the
   viewer proposal.
4. After approval, centralize presentation helpers only when more than one
   output surface needs the same rule; do not introduce a framework for one
   string.
5. Add or update focused output tests. Test an interactive path and a
   non-interactive path when relevant.

## Visual language

Use a neutral base and let color communicate state, never decoration.

- Use one identity/accent color for navigation, section labels, paths, and
  progress context.
- Use success, failure, warning, and todo colors only for their semantic
  states. Never rely on color alone.
- Use `›` for context or a section, `✓` for completion, `×` for failure,
  `!` for an action the user must take, and `·` for compact metadata.
- Keep symbols sparse: one leading symbol per meaningful line is enough.
- Prefer regular text and dim secondary information. Avoid banners, boxes,
  background colors, or repeated log-level labels in normal output.
- Keep paths, commands, counts, and the first actionable sentence visible
  without requiring color support.

## Copy and hierarchy

- State the outcome or problem first. Put the remedy immediately after it.
- Name the affected test file or test suite before its failure details.
- Keep successful output short. Show progress only for work that takes long
  enough to create doubt.
- Use one vocabulary consistently: `test file`, `test suite`, `test case`,
  `config`, `runner`, and `runtime`.
- Do not expose implementation details by default. Preserve raw details and
  stack traces for unexpected failures or test-file load errors.
- Make help scannable: command, purpose, then a few representative examples.
  Do not repeat every command in prose.

## TTY, streams, and automation

- Treat TTY and non-TTY output as separate interfaces.
- In an interactive terminal, show one continuously animated spinner for a
  remote operation and replace its message as the stage changes.
- Outside a TTY, never emit cursor control or animation. Print stable,
  line-oriented milestones instead.
- Respect `NO_COLOR`; do not make color necessary to understand output.
- Keep machine-readable output clean. Put human progress and diagnostics on
  stderr when the command later gains a machine-readable mode.
- Make network activity explicit and expose a useful timeout/failure state.

## Review checklist

- Can a user identify the outcome in one glance?
- Does every error say what failed, where it failed when known, and the next
  justified action?
- Does the same concept have the same wording, color, and symbol everywhere?
- Does the output remain understandable without ANSI color or Unicode width
  assumptions?
- Does CI receive stable lines rather than spinner frames?
- Did the viewer receive approval before the implementation changed?

Read [references/sources.md](references/sources.md) when making a substantial
design decision, adding a terminal capability, or justifying a new rule.
