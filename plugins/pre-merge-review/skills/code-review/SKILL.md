---
name: code-review
description: >
  Review the diff of the current git branch against a target branch the user
  provides, checking only the changed code against a set of standards. Trigger
  this skill on requests like "code review", "review diff", "review against
  target branch", "review my branch before merge", or "pre-merge review". Each
  standard lives in its own file under references/ so the rule set can be
  extended without editing this file. Read-only git only.
license: MIT
metadata:
  version: "1.0.0"
---

# code-review

Review the work introduced on the **current branch** relative to a **target
branch**, judging only the changed lines against a set of standards. Standards
are stored one-per-file under `references/`; `references/index.md` is the single
source of truth that maps file types/paths to the standards that apply.

## When to apply

Apply when the user wants a review of the current branch's changes versus a
target branch — e.g. before opening or merging a pull request. Do **not** apply
when the user wants a full-repo audit, a review of a single file in isolation,
or a review of code that is not part of this branch's diff.

## Workflow

1. **Get the target branch.** Take it as input from the user (e.g. `main`,
   `develop`, `origin/main`). If none was given, **ASK for it before doing
   anything else** — do not assume a default.

2. **Compute the changed set via merge-base** so only this branch's own work is
   reviewed (commits the target made after the branch point are excluded):
   - File list: `git diff --merge-base <target> --name-only`
   - Hunks: `git diff --merge-base <target>`

   These are read-only commands. Never `commit`, `checkout`, `reset`, `push`,
   or otherwise mutate the repository.

3. **Understand the intent first.** Before judging anything, establish what the
   change is for: read the branch's commit messages
   (`git log <target>..HEAD --oneline` and message bodies) and the
   PR title/description if one exists. A finding only makes sense relative to
   what the author was trying to do.

4. **Select which standards apply (progressive disclosure).** Read
   `references/index.md` and use its mapping to decide which reference files to
   load. Load **only** the relevant ones — never the whole set.
   - Load every standard whose **Triggers** column is `Always`.
   - Add each standard whose trigger matches a changed file's type/path.

   `index.md` is the authoritative list — do not hard-code standard names here.
   If a changed file maps to no language standard, the `Always` standards still
   apply.

5. **Read surrounding code and call sites.** For each non-trivial hunk, open the
   full file and follow callers/callees before judging. Never evaluate a hunk in
   isolation — a line that looks wrong in the diff may be correct in context, and
   vice versa.

6. **Verify each finding before reporting it.** Re-examine the candidate issue
   adversarially: can you point to the exact line and prove it is wrong (or trace
   an input that breaks it)? Drop anything you cannot substantiate — a false
   positive costs more trust than a missed nit. See the false-positive list under
   *Confidence control*.

7. **Report findings grouped by standard**, in the output format below.

## Confidence control

Aim for **high signal**: a short list of real, substantiated issues beats a long
list padded with maybes.

- Report only findings you are **>80% confident are real**. When unsure, leave
  it out rather than padding the report.
- **Skip pure style nits** (formatting, subjective naming preferences) unless a
  standard explicitly flags them.
- **Skip pre-existing issues in unchanged code** — review only what this branch
  changed. The one exception: a **CRITICAL security** issue you can see in the
  surrounding code; surface it, labeled as pre-existing.
- Do not invent weaknesses to fill a quota. If a standard has no findings, say so.

**Do NOT flag (false positives that erode trust):**

- Pre-existing issues outside the diff (except the CRITICAL-security exception).
- Code that *looks* like a bug but is actually correct in context — verify
  before reporting.
- Pedantic nitpicks a senior engineer would not raise.
- Anything a linter/formatter/type-checker already catches.
- Issues that only manifest under specific inputs/state you cannot show actually
  occur.
- A rule that the code explicitly and deliberately silences (e.g. an
  `eslint-disable` with a stated reason).

## Output format

Group findings under a heading per standard (e.g. `## Security`). For each
finding:

```
[SEVERITY] Short title
File: path/to/file.ext:line
Issue: What is wrong and why it matters, in one or two sentences.
Fix:   The concrete change that resolves it.
```

Severity labels: **CRITICAL**, **HIGH**, **MEDIUM**, **LOW**. Each standard
file declares its default severity tier; an individual finding may be raised or
lowered from that tier when the specific case warrants it.

## Verdict rules

End the review with one verdict, derived from the highest severity present:

- **APPROVE** — no CRITICAL and no HIGH findings.
- **WARNING** — one or more HIGH findings, but no CRITICAL.
- **BLOCK** — any CRITICAL finding.

Guiding principle: approve a change when it clearly improves the codebase's
overall health, even if it is not perfect — MEDIUM/LOW findings are advice, not
gates. Reserve WARNING/BLOCK for issues that genuinely should not merge as-is.
It is fine to call out notably good work (a clean refactor, a well-placed test)
alongside the findings; praise is informational and never changes the verdict.

Then print a summary count table:

| Severity | Count |
| -------- | ----- |
| CRITICAL | n     |
| HIGH     | n     |
| MEDIUM   | n     |
| LOW      | n     |

## Extending this skill

Adding a new standard is two steps and requires **no edit to this file**:

1. Drop a new `references/<name>.md` file (severity-tagged title, rules as
   scannable bullets, BAD/GOOD snippets where useful).
2. Add one row to `references/index.md` describing the file, its severity tier,
   the file types/paths that trigger it, and a one-line scope.

The file-type → reference mapping lives **only** in `references/index.md`, so it
stays the single source of truth. The workflow above reads that table at step 4;
it never hard-codes the list of standards.
