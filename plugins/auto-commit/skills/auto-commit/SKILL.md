---
name: auto-commit
description: >
  Commit tracked git changes after any build or task completes, using
  Conventional Commits. Assesses scope with `git status` and `git diff --stat
  HEAD`: small changes (<= 5 files OR <= 150 line delta) become one commit;
  larger changes are split into multiple logical commits grouped by
  architectural layer (config -> data -> logic -> API -> UI -> tests -> docs).
  Trigger on "/auto-commit", "commit these changes", "save this", "wrap up", or
  after a feature/fix has been verified to work. Pass `--dry-run` to print the
  planned commits without executing. Commit-only: never stages with `-A`/`.`,
  never amends, never pushes. Depends only on `git`.
license: MIT
metadata:
  version: "1.0.0"
---

# auto-commit

Commit the **tracked** changes in the working tree. Decide between a single
commit and several logical commits based on the size of the change, write a
Conventional Commits message for each, and report what was committed.

This skill **only commits**. It never pushes, never amends, never force-adds
ignored files, and never stages with `git add -A` or `git add .` — every
`git add` names specific files.

## Invocation

- `/auto-commit` — assess, then commit.
- `/auto-commit --dry-run` — print the planned commits (groups + messages) and
  stop. Make **no** changes to the index or history.

## Workflow

### 1. Assess scope

Run, in this order:

```
git status --porcelain=v1
git diff --stat HEAD
```

`git diff --stat HEAD` reports tracked changes (staged + unstaged) against
`HEAD`; its final line gives the **line delta** (insertions + deletions). The
porcelain status identifies untracked files (`??`), conflicts, and renames.

### 2. Check stop conditions — pause and ASK the user when any holds

- **Clean tree.** No tracked changes to commit → output exactly
  `Nothing to commit.` and stop. (Untracked-only working trees count as clean
  here — see step 3.)
- **Merge conflicts.** Any porcelain entry whose two-letter code is one of
  `DD AU UD UA DU AA UU` ("both modified" / unmerged). Stop and ask the user to
  resolve the conflict first.
- **Outside project root.** A change path that resolves outside the repository
  root. Stop and ask.
- **Possible secrets.** The diff (`git diff HEAD`) contains any of the patterns
  `_KEY=`, `_SECRET=`, `_TOKEN=`, `PASSWORD=`. Stop, name the file + line, and
  ask the user to confirm before committing.

### 3. Select the files to commit

- Include only **tracked** changes: modified (`M`), deleted (`D`), renamed
  (`R`), and copied (`C`) entries from porcelain — staged or unstaged.
- **Skip untracked files (`??`) silently.** Do not `git add` them, do not
  mention them as an error. (`.gitignore` is already respected; never
  `git add -f`.)
- If, after skipping untracked files, no tracked change remains, treat the tree
  as clean: output `Nothing to commit.` and stop.

### 4. Choose the commit strategy

Let `F` = number of tracked changed files, `D` = line delta from
`git diff --stat HEAD`.

- **Single commit** when `F <= 5` AND `D <= 150` → one commit covering every
  tracked file.
- **Multi-commit** when `F > 5` OR `D > 150` → group files by the layers below
  and make one commit per non-empty group.

### 5. Group files (multi-commit mode)

Assign each tracked file to the **first** matching layer, in this priority
order. A group with no files is skipped entirely.

| # | Layer | Matches (filename / path) |
|---|-------|---------------------------|
| 1 | Infrastructure / config | `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `tsconfig*.json`, `*.config.{js,ts,mjs,cjs}`, `.env.example`, `Dockerfile`, `docker-compose*`, `.github/**`, `.gitlab-ci*`, CI/build config |
| 2 | Data layer | migrations, `**/schema*`, `**/models/**`, `**/entities/**`, seeds, `*.prisma`, `*.sql` |
| 3 | Business logic | `**/services/**`, `**/lib/**`, `**/utils/**`, `**/helpers/**`, `**/domain/**`, `**/hooks/**` (non-UI) |
| 4 | API layer | `**/routes/**`, `**/controllers/**`, `**/resolvers/**`, `**/api/**`, `**/handlers/**`, `**/endpoints/**` |
| 5 | UI | `**/components/**`, `**/pages/**`, `**/app/**` (views), `*.css`, `*.scss`, `*.{vue,svelte}`, styles |
| 6 | Tests | `*.test.*`, `*.spec.*`, `**/__tests__/**`, `**/tests/**`, `**/e2e/**` |
| 7 | Documentation | `*.md`, `README*`, `docs/**`, `CHANGELOG*` |

Tests (layer 6) and docs (layer 7) take precedence over their content layer — a
`*.test.ts` under `services/` is a **test** commit, not a logic commit. If a
file matches nothing above, place it in the closest layer by directory; if still
unclear, fold it into layer 3 (business logic).

Commit groups in ascending layer order (config first, docs last) so history
reads bottom-up.

### 6. Build each commit message

Format (Conventional Commits):

```
<type>(<scope>): <imperative summary>
```

- **Subject** <= 72 chars, imperative mood, **no trailing period**.
- **type** — infer from the group's content:
  `feat` (new behavior), `fix` (bug fix), `refactor` (restructure, no behavior
  change), `test` (tests), `docs` (docs), `chore` (config/tooling/deps),
  `style` (formatting only), `perf` (performance), `ci` (CI config).
- **scope** — the dominant directory or module of the group (e.g. `auth`,
  `api`, `db`). Omit `(scope)` only when no single module dominates.
- Never produce an empty or generic message ("update files", "changes"). Name
  *what* changed.

In single-commit mode, choose the type/scope that best summarizes the whole
change set.

### 7. Execute (skip entirely in `--dry-run`)

For each group, in layer order:

1. `git add <file1> <file2> ...` — only this group's files, named explicitly.
2. `git commit -m "<message>"`.
3. On success, output: `✅ Committed: <message>`
4. **If `git commit` fails, stop immediately** and report the error verbatim.
   Do not retry, do not amend, do not continue to the next group.

In `--dry-run`, do none of the above — only print the plan (see below).

### 8. Report

**`--dry-run` output** — the plan only, no execution:

```
Planned commits (dry run): N
1. <type>(<scope>): <summary>
   files: a.ts, b.ts
2. ...
```

**Normal output** — after all commits succeed, a summary table:

```
Commits made: N
<type>(<scope>): <summary>
<type>(<scope>): <summary>
...
```

## Hard constraints

- NEVER `git add -A` or `git add .` — always stage specific files.
- NEVER `git commit --amend`.
- NEVER `git push`.
- NEVER `git add -f` / force-add `.gitignore`d files.
- Clean tree (no tracked changes) → `Nothing to commit.` and stop.
- A failing `git commit` stops the run immediately; report the error, no retry.
- No empty or generic commit messages.
- Untracked files are skipped silently; only tracked changes are committed.
