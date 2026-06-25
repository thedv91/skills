# Standards index

Single source of truth for the rule set. The skill workflow reads this table to
decide which reference files to load for a given diff (progressive disclosure —
load only the rows whose triggers match a changed file).

To add a standard: create `references/<name>.md`, then append one row here. No
other file needs to change.

| Reference            | Severity tier | Triggers (file types / paths)                                   | Scope (one line)                                                        |
| -------------------- | ------------- | --------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `security.md`        | CRITICAL      | Always                                                          | Secrets/env exposure, injection/XSS, authn/authz, redirects, data leaks, deps. |
| `code-quality.md`    | HIGH          | Always                                                          | Structure, error handling, dead code, naming, complexity, test coverage. |
| `business-logic.md`  | HIGH          | Always                                                          | Correctness vs intent, edge cases, state/transaction integrity, idempotency. |
| `user-perspective.md`| HIGH          | Always                                                          | User journey, user-driven edge cases, failure-to-symptom mapping, async feedback. |
| `performance.md`     | MEDIUM        | Always                                                          | N+1/unbounded queries, quadratic loops, serial I/O, caching, memory footprint. |
| `best-practices.md`  | LOW           | Always                                                          | Engineering hygiene, TODOs, magic values, imports/format, PR hygiene.   |
| `typescript.md`      | HIGH          | `*.ts`, `*.tsx`, `*.mts`, `*.cts`                              | Strict typing, no `any` leak, discriminated unions, null handling, exhaustiveness. |
| `nodejs.md`          | HIGH          | Server/backend `*.js`, `*.mjs`, `*.cjs`, `*.ts` (non-React)    | Async/await misuse, unhandled rejections, event-loop blocking, streams, env/config. |
| `react.md`           | HIGH          | `*.jsx`, `*.tsx` (React components/hooks)                      | Hook deps, keys, re-render cost, effect cleanup, controlled inputs, a11y basics. |
| `nextjs.md`          | HIGH          | Next.js projects: `app/**`, `pages/**`, route handlers, `proxy.ts`/`middleware.ts`, `next.config.*` | Server/Client boundary, server actions, caching/revalidate, `NEXT_PUBLIC_` env, next/image/link. |

## Selection notes

- **Always** rows load on every review regardless of file type.
- A `.tsx` file is a React component **and** TypeScript — load both `react.md`
  and `typescript.md`.
- A `.tsx` file inside a Next.js project also loads `nextjs.md` (it layers on top
  of the React/TypeScript rules); server route handlers additionally load
  `nodejs.md`.
- `nodejs.md` applies to server-side JavaScript/TypeScript (API routes,
  services, scripts, CLIs). It does not apply to browser-only React code; use
  the path/context of the change to decide.
- A finding's severity defaults to the reference's tier but may be adjusted up
  or down for the specific case.
