---
name: bugfix-pattern-sweep
description: >
  Use right after a BUG-FIX is written, or while reviewing one (a PR/MR, branch,
  commit, or uncommitted diff), to hunt for the SAME root-cause pattern elsewhere in
  the codebase — a fix usually patches one call site, but the same anti-pattern almost
  always survives in sibling code the author never opened. This skill reads the fix's
  diff, infers what was actually wrong (the idiom, not just the symptom), turns it into
  a search signature, sweeps the whole project, and reports ranked
  same-bug / benign / needs-verification hits with a suggested action. Reach for it
  whenever a bug fix raises "does this exist anywhere else?" — even if the user never
  says the word "sweep". Triggers on: "review this bugfix", "does this bug exist
  elsewhere", "find similar pattern", "sweep for the same bug", "sibling bugs",
  "propagate the fix", "root cause sweep", or as a follow-up after any bug-fix review.
  Read-only by default: it proposes fixes and tracked tasks but applies nothing unless
  you choose to.
license: MIT
metadata:
  version: "1.0.0"
---

# bugfix-pattern-sweep — Find sibling occurrences of a just-fixed bug

A bug fix almost always patches **one** call site. The defect itself is a _pattern_ —
the same wrong idiom typically recurs in sibling code the author never opened. This
skill reads a fix's diff, works out **what was actually wrong**, and sweeps the whole
project for other places that still do it — so the review catches the untouched twins
before they ship as the next ticket.

**Core principle: sweep the ROOT-CAUSE anti-pattern, not the symptom.** The symptom
(the visible misbehavior) is unique to one spot. The root cause (the wrong idiom the
fix removed) is a searchable rule that can hide anywhere. Extract the idiom, then go
find every other place that still uses it.

## When to activate

- Right after confirming a change is a **bug fix** (its title/commit says fix/bug, or
  the diff removes a guard / swaps a data source / adds a missing case). Run this as
  the "does it live elsewhere?" step of the review.
- Standalone, when someone asks whether a fix's problem exists in other places.
- After you fix a bug yourself and want to check for siblings before calling it done.

Skip it for pure feature additions, behavior-preserving refactors, formatting,
dependency bumps, and generated code.

## Phase 0 — Resolve the change and infer what was fixed

1. **Get the diff of the fix.** Use whatever source is available, in this order:
   - An explicit PR/MR reference → fetch its diff via the platform integration if one
     is connected; otherwise fall back to git.
   - The current branch → `git diff <base>...<HEAD>` (three-dot / merge-base diff).
     Infer `<base>` from the repo's default branch (e.g. `main`, `master`, `develop`);
     if ambiguous, ask which target to diff against.
   - Uncommitted work → `git diff` and `git diff --staged`.
     Read the **enclosing function/scope** of each hunk, not just the changed lines.
2. **Confirm it's a bug fix.** Look at commit messages, the PR/branch name, and the
   diff shape (a removed guard, a swapped source, an added case/null-check). If it is
   clearly _not_ a fix, say so and stop — this skill has nothing to sweep.
3. **State the anti-pattern in two lines**, derived from the diff itself:
   - **BEFORE (buggy idiom):** what the code did that was wrong.
   - **AFTER (correct idiom):** what the fix changed it to.
     The difference between these is the signature you will search for. If you cannot
     phrase the anti-pattern as a _rule that could apply to code the author never wrote_,
     you have only understood the symptom — re-read the diff until you can.
4. **Classify the anti-pattern into a family** (this decides how you search):
   - **Wrong data source** — a stale, cached, deferred, or captured copy of state used
     where the live/current source was required (feeding a write, a payload, a
     computed index, a decision).
   - **Dropped / missing guard** — a null-check, early return, validation, error
     handling, permission check, bounds check, or cleanup that this fix ADDED; siblings
     likely still lack it.
   - **Wrong flag or param carried through** — a payload spreads an object and forgets
     to override a field, so a wrong mode/flag/id leaks downstream.
   - **Index / key mismatch** — an index or key computed against one collection but
     applied to another (live vs snapshot, filtered vs unfiltered, sorted vs raw).
   - **Missing propagation** — a rule applied to one branch / case / column / render
     path but not its siblings that should match.
   - **Boundary, ordering, or comparison fault** — off-by-one, async race / stale
     closure, loose vs strict equality, unit or type mismatch, time-zone / date
     handling. Each has its own search shape.

## Phase 1 — Build search signatures

Turn the anti-pattern into 2–4 concrete searches. Optimize for **recall first** (catch
every candidate), then filter in Phase 2. Use what the environment offers:

- **Text search** (`grep` / `git grep` / ripgrep) for the literal idiom, built from the
  code the fix _removed_: the stale identifier that fed a write, the API the missing
  guard protected, the mutation/endpoint whose payload dropped a field, the
  index-derivation call, etc. Search for the buggy shape, not the fixed one.
- **A code-intelligence / semantic index**, if one is available, for "who else reads X
  and writes it" or "callers of the changed symbol" — more precise than text for
  data-flow questions.
- **Parallel sub-agents**, when the idiom is semantic rather than textual (e.g. "any
  handler that derives a write target from a stale snapshot"). Give each agent the
  BEFORE/AFTER statement and the fixed location as the reference example, scope it to a
  slice of the tree, and require every hit as `{file, line, snippet, why_it_matches}`
  grounded in the real file.

Scope sensibly: start in the same module/area as the fix, then widen to the whole repo
if the idiom is generic. **Always exclude** generated code, vendored/third-party
directories, build output, snapshots, and lockfiles.

## Phase 2 — Classify every hit (don't dump raw search results)

For each candidate, read enough surrounding code to decide, and assign a verdict plus a
confidence score:

- **Same bug (confirmed)** — does exactly the anti-pattern on a live path. Trace one
  input through it to prove it can misbehave.
- **Benign / correct-by-context** — matches the text but the surrounding code makes it
  safe. Say _why_ it is safe; this is coverage, not noise.
- **Needs verification** — plausibly the same bug but depends on runtime/external
  behavior you cannot confirm statically. Flag it; do not assert it.
- **Intentional** — a deliberate use of the "risky" idiom (debounced/optimistic/cached
  by design). If the code or a comment documents the intent, respect it.

For the "wrong data source" family, the single most useful distinction:
**read-only / display uses are correct; only reads that feed a write or a decision are
bugs.** State which side each hit is on.

## Phase 3 — Report and offer action (ask; never auto-apply)

Print a ranked table: `# | verdict | confidence | file:line | one-line why`. Lead with
confirmed same-bugs, then needs-verification, then a short "checked & safe" list so the
reviewer sees the sweep was exhaustive, not just the hits. Note the search scope and
any angle you skipped.

Then ask how to proceed — do not edit or post anything unprompted:

- **Fix the confirmed siblings** — apply the same fix in a _separate_ branch/commit from
  the PR under review, each change traceable to the anti-pattern, minimal diff, matching
  the surrounding code.
- **Spawn tracked tasks** — one per sibling or one grouped, each carrying the file:line,
  the anti-pattern statement, and the reference fix, so they are not lost.
- **Comment on the PR/MR** — if a platform integration is connected and the reviewer
  wants it, attach the hits as review comments (respect the platform's posting flow).
- **Report only** — leave the findings in chat.

## Guardrails

- **Read-only by default.** This skill finds and ranks; it applies changes only on an
  explicit choice in Phase 3.
- **Never widen the PR under review** with unrelated sibling fixes — those belong in
  their own branch/commit/task unless the reviewer says otherwise.
- **A match is a candidate, not a verdict.** Always verify against the current code; the
  same idiom can be correct in a read-only context and buggy in a write context.
- **Infer the anti-pattern from the diff, not from assumptions.** If the fix is unclear
  or looks like more than a bug fix, ask before sweeping.
- Persisted artifacts (task text, PR comments, commit messages) in **English**;
  converse in the user's language.

## How to phrase the anti-pattern (illustrative — not tied to any codebase)

The whole sweep hinges on turning a one-off fix into a searchable rule. Examples of the
BEFORE → AFTER → signature move, across families:

- _Wrong data source_: BEFORE a handler builds a save payload from a stale/cached copy
  of state; AFTER it reads the live state. → Search every write/payload that is built
  from that cached identifier, and keep only the ones that feed a write.
- _Dropped guard_: BEFORE a function calls an API without a null/permission/bounds check;
  AFTER the fix adds it. → Search all callers of that API and check which still lack the
  guard.
- _Carried flag_: BEFORE a payload spreads an object and forgets to override one field;
  AFTER it sets the field explicitly. → Search every spread of that object into the same
  kind of payload and check the field.
- _Index mismatch_: BEFORE an index is computed against one collection and applied to a
  different one; AFTER both use the same source. → Search index-derivation calls near
  writes and confirm the source collection matches the applied one.

The point every time: the fix touched one place, but the rule behind it reaches many.
That is what this skill exists to surface.
