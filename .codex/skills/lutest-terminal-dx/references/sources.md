# Sources

Use these sources as decision criteria, not as visual templates.

## Command Line Interface Guidelines

<https://clig.dev/>

- Keep success output brief and make state changes explicit.
- Use color intentionally; disable it outside a terminal, for `NO_COLOR`, or
  when the user requests no color.
- Do not animate outside a TTY.
- Use symbols only when they improve scanning.
- Make errors human-readable, actionable, and low-noise.
- Keep help concise by default, with examples and next commands.
- Treat network activity as an explicit boundary and make it recoverable when
  practical.

## NO_COLOR

<https://no-color.org/>

Honor a non-empty `NO_COLOR` environment variable by suppressing ANSI color.
Never encode meaning in color alone.

## W3C WCAG 2.2 contrast minimum

<https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html>

Aim for readable foreground/background contrast. Terminal themes vary, so
avoid backgrounds and use color as an enhancement over text and symbols.

## Project constraints

- `tint` already detects color support and honors `NO_COLOR`.
- `utils/tty.luau` is the project TTY probe. Use it for animation decisions.
- `runtimes/roblox/progress.luau` owns Roblox progress behavior.
- `core/errors.luau` owns structured user-facing errors.
