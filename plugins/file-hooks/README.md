# file-hooks

Run project-defined commands on the file Claude just edited.

This plugin ships **one shared mechanism** — a `PostToolUse` (`Edit|Write`) hook that,
after each edit, looks at the changed file and runs whatever commands the current
project declares for it. The commands themselves are **policy** and live in each
project, so the same plugin works across a TypeScript repo, a Python repo, a Go
repo, etc. — no per-project shell to maintain.

## Setup per project

1. Enable the plugin in the project's `.claude/settings.json` (or `settings.local.json`):

   ```json
   { "enabledPlugins": { "file-hooks@thedv91-skills": true } }
   ```

2. Declare the commands in `<project>/.claude/file-hooks.json`:

   ```json
   {
     "format": [
       { "match": "\\.(ts|tsx|js|jsx)$", "commands": ["yarn eslint {file}", "yarn prettier --write {file}"] }
     ],
     "check": [
       { "match": "\\.(ts|tsx|js|jsx)$", "commands": ["yarn types"] }
     ]
   }
   ```

A project with no `.claude/file-hooks.json` is a no-op — the hook exits immediately.

## Config format

Top-level keys are **phases**. This plugin runs two:

| Phase    | When it runs                         | Blocking? |
| -------- | ------------------------------------ | --------- |
| `format` | synchronously after the edit         | yes       |
| `check`  | in the background (`async`)          | no        |

Put fast, file-scoped work (lint, format) in `format`; put slow, project-wide
work (typecheck, tests) in `check` so it doesn't block Claude.

Each phase is a list of rules:

- `match` — a regex tested against the changed file's path (extended regex, `grep -E`).
- `commands` — commands to run when `match` hits. `{file}` is replaced with the
  shell-quoted path of the changed file. A command without `{file}` (e.g.
  `yarn types`) just runs project-wide.

Commands run from the project root and never fail the tool call — errors are
surfaced to Claude but don't block the edit.

> The dispatcher `eval`s each command with `{file}` substituted. Config is
> authored per-project and trusted; do not point it at untrusted input.
