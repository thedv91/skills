---
description: Review the diff between the current branch and a target branch, understand the project's business logic, and give structured feedback.
argument-hint: "<target-branch> (e.g. main, develop). Empty = main"
allowed-tools: Bash(git rev-parse:*), Bash(git fetch:*), Bash(git merge-base:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git show:*), Bash(git status:*), Bash(find:*), Bash(ls:*), Bash(cat:*), Bash(yarn test:*), Bash(yarn typecheck:*), Bash(yarn lint:*), Bash(yarn eslint:*), Bash(npm test:*), Bash(npm run test:*), Bash(npm run typecheck:*), Bash(npm run lint:*), Bash(pnpm test:*), Bash(pnpm run test:*), Bash(pnpm typecheck:*), Bash(pnpm lint:*), Bash(pnpm eslint:*), Bash(npx tsc:*), Bash(npx eslint:*), Bash(npx vitest run:*), Bash(npx jest:*), Bash(tsc:*), Bash(eslint:*), Bash(vitest run:*), Bash(jest:*), Bash(pytest:*), Bash(go test:*), Bash(go vet:*), Bash(cargo test:*), Bash(cargo check:*), Bash(cargo clippy:*), Read, Grep, Glob, mcp__code-review-graph__*, mcp__codegraph__*, mcp__plugin_serena_serena__*, mcp__serena__*
---

# Code Review (business-logic aware)

Target branch to compare against: **$ARGUMENTS** (defaults to `main` if empty).

## Collect the diff

Resolve TARGET first: TARGET = `$ARGUMENTS` (the branch the user passed), or
`main` if it is empty. Prefer `$ARGUMENTS` over positional `$1` — in some
harnesses `$1` is not populated and silently renders empty, which would make a
non-default target fall back to `main` and review the wrong branch. If
`$ARGUMENTS` is also empty, fall back to the `<command-args>` value from the
invocation wrapper before defaulting to `main`. Do NOT rely on
`${1:-main}`-style shell defaulting anywhere. Resolve TARGET yourself, then use
it verbatim below.

Run the following with Bash to gather context (replace `<TARGET>`):

```
git rev-parse --abbrev-ref HEAD
git fetch --quiet 2>/dev/null; true
git merge-base <TARGET> HEAD
git diff --stat <TARGET>...HEAD
git log --oneline <TARGET>..HEAD
```

Then fetch the full diff with generated/lock files excluded:

```
git diff <TARGET>...HEAD -- . ':(exclude)pnpm-lock.yaml' ':(exclude)package-lock.json' ':(exclude)yarn.lock' ':(exclude)*.lock' ':(exclude)*.snap' ':(exclude)**/_generated/**' ':(exclude)*.min.*'
```

**Large-diff guard:** read the `--stat` output first. If the full diff exceeds
~3,000 lines, do NOT dump it in one command — pull it in chunks per
feature/directory (`git diff <TARGET>...HEAD -- <path>`), starting with the
files at the center of the business flow. Excluded generated files are only
noted as present, never reviewed line by line.

If `git diff` is empty → report "No changes between the current branch and `<TARGET>`" and STOP.

If the target branch does not exist → try `origin/<TARGET>`. Still missing → list branches (`git branch -a`) and ask the user.

## Auto-detect available skills (do not skip)

Scan the skill directories on this machine to see if any skill can assist this review.
This is automatic: do NOT hardcode skill names — read their descriptions and decide.

Keep the scan narrow and cheap. The plugin cache (`~/.claude/plugins`) holds
hundreds of unrelated skills, so do NOT read every `SKILL.md` frontmatter. First
list candidates from the project + user skill dirs, then grep those files for
review-relevant keywords (review, test, security, accessibility, performance,
lint, quality) and only read the frontmatter of the matches:

```
find .claude/skills ~/.claude/skills -name SKILL.md 2>/dev/null
grep -rilE 'code.?review|security|accessib|test.?(coverage|strateg)|performance.?(audit|budget)|code.?quality|best.?practice' \
  .claude/skills ~/.claude/skills --include=SKILL.md 2>/dev/null
```

Read `name` + `description` (frontmatter only) **only for the matches whose
filename/path signals relevance** (contains `review`, or the changed code's
domain) — the grep just confirms a skill worth checking exists; do NOT read the
frontmatter of every hit (bare keywords like `test` still over-match). Then:

1. **Code-review skills** (e.g. `code-review`, `engineering:code-review`):
   if present → read it fully and USE its criteria/checklist together with the steps
   below. Prefer the skill's standards where they are more detailed.
2. **Domain skills matching the project** (e.g. `testing-strategy`, `security`,
   `accessibility-review`, or an org's internal skill): if changed files fall in that
   skill's scope → apply its perspective too.
3. **Report-export skills** (e.g. `docx`, `pdf`): only use if the user asks to export a file.

Briefly tell the user which skills were picked up and what for, e.g.
_"Detected & applied: engineering:code-review (checklist), testing-strategy (test
coverage assessment)."_ If no skill is relevant → skip silently.

## Map the BLAST RADIUS first (mandatory, do not skip)

Before judging any changed line, determine **every place the change reaches**.
Do this deterministically with the code-graph tools — do NOT infer the impact by
reading the changed file and reasoning about who is affected, then stopping at
the first couple of consumers you can picture. The bug is almost always in a
consumer you did not open.

For EACH changed symbol / exported function / prop / derived value / type in the
diff, enumerate its references **with a tool, not from memory**:

1. **Query the graph (preferred).** If a code-graph MCP server is available
   (check the tool list), use it — one call returns the full impact set. Prefer
   them in this order:
   - **`code-review-graph`** (tools `mcp__code-review-graph__*`) — purpose-built
     for exactly this; use it first when connected. Workflow:
     1. Ensure the graph is current: `build_or_update_graph_tool(base="<TARGET>")`
        (incremental; harmless if already up to date).
     2. **Always start cheap:** `get_minimal_context_tool(task="review changes")`
        returns ~100 tokens — overall risk, communities, affected flows, and the
        tools it suggests calling next. Let it steer the rest of this workflow.
     3. **Blast radius + context.** `get_review_context_tool` at
        `detail_level="standard"` embeds the whole impact-set graph (plus source
        snippets), which **overflows the token limit on any non-trivial change —
        the call errors and dumps to a file, returning nothing usable.** Verified:
        it still overflowed even scoped to the changed files with `max_depth=1`,
        and even with `include_source=false` (the graph alone was too big). So do
        NOT rely on `standard` for context. Instead:
        - `get_review_context_tool(base="<TARGET>", detail_level="minimal")` for the
          risk / test-gap overview (counts only — no snippets, no file list), then
        - `get_impact_radius_tool(base="<TARGET>", detail_level="minimal", max_depth=1)`
          for the blast-radius file list.
        Use the changed files' source from the **Collect the diff** `git diff` as
        your snippets, and open each impacted file the radius list names. Only reach for
        `standard` when the impact set is genuinely tiny, accepting it may error.
     4. Widen the blast radius as needed: `get_impact_radius_tool(base="<TARGET>")`
        for the whole diff, or `query_graph_tool(pattern="callers_of" | "callees_of"
        | "imports_of", target=<symbol>)` to walk the call/dependency graph for a
        specific changed symbol.
     5. Test coverage → feeds **Verify & ground**: `query_graph_tool(pattern="tests_for",
        target=<function>)` tells you which changed functions have no test.
     6. Risk → feeds **Classify severity**: `detect_changes_tool` returns per-change risk
        scores (security sensitivity, test-coverage gaps, cross-community callers).
        Use them as one input to severity, not as a substitute for your judgement.
     7. Flows → feeds the Correctness "trace one concrete input" step:
        `get_affected_flows_tool` with `list_flows_tool` show which execution paths
        the change touches.

     Token hygiene: `detail_level="minimal"` returns only summary counts (risk,
     impacted-file count) — **no source snippets and no file list**; use it for the
     overview, then `get_impact_radius_tool(detail_level="minimal")` for the actual
     blast-radius files. Avoid `"standard"` — it overflows the token limit even
     when scoped (see above).
   - **`codegraph`** — `codegraph_explore "<changed symbols / file names>"`: read
     the **"Blast radius — what depends on these"** section it prints, plus the
     verbatim source of each consumer (treat that source as already Read).
     `codegraph_callers <symbol>` — direct callers of a function/method.
   - **serena** — `find_referencing_symbols` (name_path + relative_path) — precise
     LSP references; `get_symbols_overview` / `find_symbol` to locate the target.
2. **Fallback when no graph server is connected:** `grep -rln '<name>' <src>` for
   every changed identifier — never assume the count, list the files.
3. **Open EVERY site the query returns.** If it lists 3 files, read 3. When two
   surfaces do the same job (desktop ↔ mobile, sibling switch branches, an
   inline path + its detail/hover/tooltip variant), **diff them against each
   other** — divergence between siblings is the #1 bug smell.
   **Wide-blast exception:** for a symbol with more than ~20 references,
   reading every site is not feasible — group the references by surface
   (route, platform, sibling variant), read at least one representative per
   group plus every site adjacent to the changed code, and **state the actual
   coverage in the report** (e.g. "read 8 of 41 references, one per surface
   group") instead of implying full coverage.

Then, for each significantly changed file:

4. **Read** the whole file (not just the diff hunk) for the context the changed
   function/class lives in.
5. From the reference set above, specifically check:
   - Callers of the changed function/API — does the change break a contract?
   - Related model/schema/type definitions — how does the data flow?
   - Corresponding tests — were they updated accordingly?
   - Config / business-rule files (constants, rules, validators).
6. Ask yourself: _"What business goal is this code trying to achieve? After the change, does it still achieve that goal — at **every** consumer, not just the one in the diff?"_

Anchor every "I checked all N usages" claim to an actual tool result, not to
memory. A consumer you skipped without declaring it is a bug in the review,
not a clean pass. Prioritize files at the center of the business flow; read
as many related files as the reference set demands.

## Verify & ground (do not skip when the stack allows it)

A review that only reasons about the diff is unverified. Before writing the
report, ground your correctness claims in real tool output:

1. **Run the project's non-mutating checks** — tests, typecheck, and lint,
   scoped to the changed files where possible. Detect the **package manager**
   (from the `packageManager` field / lockfile → pnpm | yarn | npm) **and the
   runner** (package.json scripts, Makefile, CLAUDE.md). Prefer the underlying
   binary scoped to the change (`npx eslint <files>`, `tsc --noEmit`) over
   aggregate scripts. In a non-JS stack run the equivalent (`go test`, `pytest`,
   `cargo test`); ask permission if the command falls outside the allowed set.
2. **Only non-mutating commands.** Run tests / typecheck / lint — never a build
   that emits artifacts, codegen, or a formatter in `--write` mode. A review must
   not change the tree. **Aggregate scripts often hide these:** a repo's
   `typecheck` may run `codegen` first and `lint` may chain a `--write` formatter
   (e.g. `pnpm typecheck` → `codegen && …`, `pnpm lint` → `format:fix && …`).
   Read the script in package.json before running it; if it mutates, invoke the
   binary directly (`tsc --noEmit`, `eslint` without `--fix`).
3. **If you cannot run them** (sandbox, missing deps), say so explicitly in the
   report and mark the affected findings **unverified** — do not imply you
   checked.
4. Anchor every "this works" / "tests pass" / "✅ looks good" claim to an actual
   result from this step, not to a reading of the code. If the diff adds a test,
   confirm it actually runs and passes.

## Review across dimensions

### Business Logic (most important dimension)

- Does the change match the business intent? Does it violate any implicit rule (e.g. "an order can only be created when balance > 0")?
- Business edge cases: empty state, cancellation, refund, duplication, user permissions.
- Are contracts between modules broken? Are callers affected but left unfixed?
- Any unintended behavior change (regression)?
- **Scope check:** use the commit messages / ticket refs from `git log` to
  establish what the change was *meant* to do, then flag any behavior change in
  code unrelated to that goal — an out-of-scope regression hides in the parts of
  the diff nobody was looking at.

### Security

SQL/NoSQL injection, XSS, CSRF, auth/authorization flaws, secrets in code, SSRF, path traversal, unsafe deserialization.

### Performance

N+1 queries, unbounded loops/queries, O(n²) complexity in hot paths, missing indexes, resource leaks, redundant allocations.

### Correctness

Null/empty/overflow, off-by-one, race conditions & concurrency, error handling & propagation, type safety.

- **Trace one concrete input.** Pick a real scenario (actual numbers/state) and
  follow it through the changed code path step by step — the value at each line,
  not a hand-wave. Most correctness bugs surface the moment you compute a real
  case instead of describing the logic.

### Maintainability

Naming, single responsibility, code duplication, test coverage, docs for non-obvious logic.

## Classify severity

Each issue MUST be assigned exactly one of 4 levels:

- **CRITICAL** — Absolute merge blocker. Immediate serious impact: exploitable security hole (injection, leaked secret, auth bypass), data loss/corruption, broken core business logic (wrong billing, wrong stock deduction), production crash, broken contract that breaks callers.
- **HIGH** — Should fix before merge. Clear correctness bug but narrower scope: race condition, unhandled business edge case (order cancellation, refund, duplication), missing important input validation, N+1 / performance issue in a hot path, faulty error handling that swallows exceptions.
- **MEDIUM** — Should fix, not a merge blocker. Affects quality/maintainability: missing tests for important logic, code duplication, high complexity that is hard to read, misleading naming, performance issue outside hot paths.
- **LOW** — Nice-to-have. Style, minor naming, missing comments, micro-optimizations, non-urgent refactor suggestions.

**Severity realism — trace impact before you finalize.** A finding's severity is
its *real-world* worst case, not its worst case in isolation. Before locking a
level, trace the issue downstream: is there a later gate, validation, or
compensating control that catches it? If the worst case genuinely cannot occur,
**downgrade honestly and name the mitigation** in the finding. Inflating a
mitigated issue erodes trust in your real findings just as much as missing one.
This is distinct from uncertainty: when you are genuinely unsure of the impact,
pick the higher level; when you have *verified* a mitigation, lower it and say so.

When torn between two levels → pick the higher one and state why.

## Produce the report

Write the report in English, following this template:

```markdown
## Code Review: <current branch> → <TARGET>

### Overview

<1-3 sentences: what the diff does, overall quality, whether it should merge>

### Summary

| Severity    | Count |
| ----------- | ----- |
| 🔴 CRITICAL | x     |
| 🟠 HIGH     | x     |
| 🟡 MEDIUM   | x     |
| 🔵 LOW      | x     |

### 🧠 Business Logic

<The most important section. State the business intent you understood, whether the
change achieves it, and any regression / broken-contract risk.>

### Issues

List in order CRITICAL → HIGH → MEDIUM → LOW.

| #   | Severity | File:Line | Category | Issue | Fix |
| --- | -------- | --------- | -------- | ----- | --- |

<Severity: CRITICAL / HIGH / MEDIUM / LOW>
<Category: Business / Security / Performance / Correctness / Maintainability>

For each CRITICAL and HIGH issue, add a short explanation below the table:
why it is wrong + sample fix code (if helpful).

### ✅ What looks good

- <Positive observations>

### Verdict

**Approve** / **Request changes** / **Needs discussion**

- Any CRITICAL → must be **Request changes**.
- Any HIGH → default to **Request changes**; a genuinely debatable HIGH may
  be **Needs discussion** — say why.
- Only MEDIUM/LOW left → may **Approve** with notes.
  Include a short reason.
```

## Principles

- Cite specific `file:line`, no vague statements.
- Each issue includes: why it is wrong + how to fix (sample code if helpful).
- If unsure about the business intent, state the assumption you are using instead of guessing.
- Be honest: if the code is good, say so; don't invent problems.
- **Ground before you praise.** Anything in "✅ What looks good" or any "this is
  correct" claim must trace to a tool result (a passing test, a clean typecheck)
  or an explicit code trace — not a vibe. If you could not verify, say so.
