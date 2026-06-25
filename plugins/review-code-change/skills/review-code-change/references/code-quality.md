# Code quality — HIGH

Default severity: **HIGH**. Apply to every changed file.

## Structure & cohesion

- Each function does one thing; extract a named function when a fragment can be
  grouped and explained by its own name (Refactoring: Extract Function), or when
  a function mixes unrelated concerns or exceeds a reasonable length for the
  codebase.
- New code follows existing module boundaries and layering — no business logic
  leaking into controllers/views, no DB calls from the UI layer. Reviewers
  check that the pieces of the change interact sensibly and belong in the
  codebase (Google: design).
- No duplicated logic that an existing utility already covers (DRY — every
  piece of knowledge has one authoritative representation); `grep` before
  adding a helper.

## Error handling

- Errors are handled the way the surrounding code handles them (same pattern:
  thrown, returned, Result type) — not silently swallowed.
- No empty `catch {}` that hides failures; at minimum log or rethrow with
  context.
- Failures of I/O, network, and parsing are accounted for, not assumed to
  succeed.

```js
// BAD
try { await save(x); } catch {}
// GOOD
try { await save(x); } catch (err) { logger.error("save failed", { err }); throw err; }
```

## Dead code & leftovers

- No commented-out code blocks left behind (Refactoring: Remove Dead Code).
- No unreachable branches or unused variables/imports/parameters introduced by
  the change.
- No debug artifacts shipped: `console.log`, `debugger`, scratch endpoints.

## Naming & readability

- Names communicate what a thing is or does without being so long they are hard
  to read (Google: naming). They match codebase conventions (case style, domain
  terms).
- Booleans read as predicates (`isReady`, `hasAccess`); avoid negated names
  (`notDisabled`).
- Magic relationships are named — no opaque single-letter vars outside tight
  loops.
- Comments explain *why* the code exists, not *what* it does; the code itself
  should show the what (Google: comments).

## Complexity

- Code that can't be understood quickly by readers, or that is likely to cause
  bugs, is "too complex" — flag it (Google: complexity).
- Deep nesting is flattened with early returns where the codebase does so
  (Refactoring: Replace Nested Conditional with Guard Clauses).
- A change that sharply raises a function's cyclomatic complexity — McCabe's
  count of linearly independent paths, which grows with each decision point and
  drives the number of test cases needed — is flagged.
- No premature abstraction or over-engineering for needs that don't exist yet;
  solve the known problem now (Google: over-engineering; matches "do the
  minimum").

## Elegance

Correct is the floor, not the bar. There is no perfect code, only better code,
and review exists to improve overall code health (Google: standard of code
review) — code that works but is clumsy still earns a finding when the move
clearly improves clarity. The goal is the clearest expression of the intent.

- **Says what it means:** the shape of the code mirrors the shape of the
  problem; a reader grasps intent without tracing every line.
- **No needless ceremony:** redundant temporaries, double negations, manual
  loops where a single map/filter/reduce reads cleaner, reinventing a stdlib or
  existing-util one-liner.
- **Right tool:** uses the language's idiom and the codebase's existing
  abstraction instead of a verbose hand-rolled equivalent.
- **Symmetry:** parallel cases are written in parallel form; similar things look
  similar, different things look different.
- **Minimal surface:** the simplest signature that does the job — fewest
  parameters, narrowest types, no flags that fork the function into two.

```js
// BAD — works, but clumsy and over-built
let result = [];
for (let i = 0; i < users.length; i++) {
  if (users[i].active === true) { result.push(users[i].name); }
}
// GOOD — intent is the code
const result = users.filter((u) => u.active).map((u) => u.name);
```

Hold elegance findings to the same >80% confidence bar; when "clumsy" is merely
a personal style preference and the code is already clear, leave it out (that is
a style nit per the skill's confidence rules).

## Propose the move, not just the problem

Every structural finding states the concrete remedy in its `Fix:`, not only the
complaint. Name the move; where one applies, use Fowler's refactoring name so
the author can look it up. Common moves:

- Replace type-based conditional sprawl with a typed model / dispatch
  (Refactoring: Replace Conditional with Polymorphism), or break a tangled
  condition into named parts (Refactoring: Decompose Conditional).
- Collapse duplicate branches into one clear path (Refactoring: Consolidate
  Duplicate Conditional Fragments).
- Separate orchestration from business logic.
- Move feature-specific logic out of a shared module (and vice versa).
- Reuse the canonical helper instead of a near-duplicate.
- Delete a pass-through wrapper that adds only indirection (Refactoring: Inline
  Function / Remove Middle Man).
- Extract a helper or split an over-large file into focused units (Refactoring:
  Extract Function).

A refactor that only relocates code without reducing the conceptual load is not
an improvement — say so rather than rubber-stamping it.

## Test coverage of the change

- New behavior or a bug fix has unit, integration, or end-to-end tests as
  appropriate for the change, when the project has a test suite (Google: tests).
- Tests assert real outcomes, not tautologies; a correct test fails when the
  code under test is broken (Google: tests).
- Changed public functions keep their existing tests passing (behavior
  preserved unless intentionally changed).

## Sources

- [Google Eng Practices — What to look for in a code review](https://google.github.io/eng-practices/review/reviewer/looking-for.html) — design, functionality, complexity, tests, naming, comments, consistency, over-engineering.
- [Google Eng Practices — The Standard of Code Review](https://google.github.io/eng-practices/review/reviewer/standard.html) — approve once the change improves overall code health; no "perfect" code.
- [Refactoring catalog (Martin Fowler)](https://refactoring.com/catalog/) — index of named refactorings and their summaries.
- [Refactoring — Extract Function](https://refactoring.com/catalog/extractFunction.html) — group a fragment into a function named for its intent.
- [Refactoring — Replace Conditional with Polymorphism](https://refactoring.com/catalog/replaceConditionalWithPolymorphism.html) — turn type-based conditionals into polymorphic dispatch.
- [Refactoring — Replace Nested Conditional with Guard Clauses](https://refactoring.com/catalog/replaceNestedConditionalWithGuardClauses.html) — flatten nesting with early returns.
- [Cyclomatic complexity (Wikipedia)](https://en.wikipedia.org/wiki/Cyclomatic_complexity) — McCabe's measure of linearly independent paths; grows per decision point, drives test-case count.
