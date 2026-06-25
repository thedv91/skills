# Best practices — LOW

Default severity: **LOW**. General engineering hygiene. Report only when it
meaningfully helps; do not pad the review with these.

## TODOs & temporary code

- TODO/FIXME/HACK left in the change has an owner or a tracking reference, not a
  bare note.
- No temporary scaffolding, mock data, or feature toggles left enabled by
  accident.

## Magic values

- Repeated literals (limits, keys, status strings, timeouts) are named constants
  rather than inline magic numbers/strings.
- Deploy-varying config — credentials, hostnames, backing-service URLs — lives in
  the environment, not hardcoded in business logic (12-Factor: Config). Litmus
  test: the repo could be open-sourced without leaking secrets.

```js
// BAD
if (retries > 3) ...
// GOOD
const MAX_RETRIES = 3;
if (retries > MAX_RETRIES) ...
```

## Imports & formatting

- Imports follow the project's ordering/grouping convention; no unused imports.
- No reformatting of untouched lines that bloats the diff.
- Follows the project's linter/formatter rather than a personal style.

## Logging & observability

- Log levels are appropriate (no `error` for normal flow, no noisy `info` in hot
  paths).
- Logs carry enough context to debug but no sensitive data (see `security.md`).

## Documentation

- Public APIs, exported functions, and non-obvious decisions have a short
  comment explaining the **why**, kept in sync with the code.
- README / docs updated when the change alters usage or configuration.
- User-facing changes have a changelog entry under the right category — Added,
  Changed, Deprecated, Removed, Fixed, Security (Keep a Changelog). Changelogs
  are for humans: note what changed and why, not every commit.

## PR hygiene

- The change is scoped to its stated purpose — unrelated refactors are split
  out. A CL should be one self-contained change (Google: small CLs).
- Large mechanical changes are separated from logic changes so each is
  reviewable on its own.
- **Size signals** (judgment calls, not hard limits — Google: small CLs):
  ~100 lines is usually a reasonable size; ~1000 lines is usually too large and
  signals splitting the PR or extracting modules. File spread counts too: a
  200-line change in one file may be fine, but the same spread across 50 files
  is usually too large. When in doubt, err smaller — reviewers rarely complain
  that a CL is too small.
- Commit/PR titles follow Conventional Commits — `type(scope): description`,
  with `feat`/`fix` mapping to MINOR/PATCH and `!` or a `BREAKING CHANGE:`
  footer flagging incompatible changes (Conventional Commits).
- Generated files, build output, and lockfiles are intentional, not accidental.

## Sources

- [Google Engineering Practices — Small CLs](https://google.github.io/eng-practices/review/developer/small-cls.html) — CL size guidance: ~100 lines reasonable, ~1000 too large, file spread matters
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) — commit message format, types, scope, breaking changes, SemVer mapping
- [The Twelve-Factor App — Config](https://12factor.net/config) — store deploy-varying config in the environment; strict separation of config from code
- [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) — changelog principles and the Added/Changed/Deprecated/Removed/Fixed/Security categories
