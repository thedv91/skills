# Performance — MEDIUM

Default severity: **MEDIUM**; escalate to **HIGH** when the hot path or a
user-facing latency/cost is clearly affected. Apply to every changed file.
Performance is one of the core review axes — flag structural problems, not
micro-optimizations the runtime already handles.

## Data access (the usual culprit)

- **No N+1 queries:** a query inside a loop over rows → batch it. Collect the keys
  and issue one query (`IN` filter / `findMany`), use a DB join, or route loads
  through a per-request **DataLoader** that coalesces individual `load(key)` calls
  in one tick into a single batch call (GraphQL DataLoader, Prisma's `findUnique`
  batching).
- **DataLoader cache scope:** DataLoader instances are per-request, not global —
  its memoization cache must not leak one user's data into another's response.
- **Use eager relation loading, not manual fan-out:** prefer the ORM's relation
  loader (Prisma `include`/`select` → two queries with an `IN`, or
  `relationLoadStrategy: "join"` → a single round trip) over hand-written loops.
- **Unbounded result sets:** list/scan endpoints paginate or cap; no "fetch all
  rows then filter in app".
- **Prefer keyset over offset pagination** for deep/large lists: `OFFSET` still
  fetches and discards every skipped row (slows down as the page number grows) and
  drifts when rows are inserted between pages. A `WHERE (sort_col) < ?last_seen`
  seek stays fast at any depth and is drift-free (use-the-index-luke).
- **Missing indexes / full scans** on the filtered/sorted columns the change
  introduces (flag the access pattern; defer to a DBA where unsure). A
  multi-column index must lead with the columns used for equality/range. Consider
  a **covering index** (Postgres `INCLUDE`) so a hot query is answered index-only
  without heap access — but stay conservative: payload columns bloat the index
  (Postgres docs).
- **Over-fetching:** select only the columns/fields used, not `SELECT *` feeding
  a single field.

```js
// BAD — N+1
for (const o of orders) o.user = await db.user.find(o.userId);
// GOOD — one round trip
const users = await db.user.findMany({ where: { id: { in: orders.map(o => o.userId) } } });
```

## Loops & algorithms

- No accidental quadratic work: nested loops, `array.includes`/`indexOf` inside a
  loop where a `Set`/`Map` is O(1).
- Work done once is hoisted out of loops; no recomputation per iteration.
- Large transforms stream or chunk rather than building giant intermediates.

## I/O & concurrency

- Independent async calls run concurrently (`Promise.all`) instead of awaited
  serially — but bound the fan-out so a huge array doesn't open thousands of
  connections at once.
- No blocking work on the critical path (see `nodejs.md` for event-loop
  specifics).
- Network/DB calls are batched and not repeated for data already in hand.

## Caching & memoization

- Repeated expensive pure computation with stable inputs is cached where the
  codebase already caches; cache keys are correct and invalidation is sound.
- No caching of user-specific data in a shared/global cache (correctness >
  speed).

## Resource footprint

- No reading an entire large file/response into memory when streaming works —
  consume the body chunk by chunk (e.g. a `ReadableStream` reader / `for await`)
  instead of buffering the whole thing (MDN Streams).
- Resources (connections, file handles, timers) are released; no leak that grows
  under load.
- Payload sizes returned to clients are reasonable; avoid shipping fields the
  client never uses.

## Sources

- [Prisma — Query optimization & performance](https://www.prisma.io/docs/orm/prisma-client/queries/query-optimization-performance) — solving N+1 with `include`/`select`, `relationLoadStrategy: "join"`, and the built-in `findUnique` dataloader.
- [GraphQL DataLoader](https://github.com/graphql/dataloader) — per-request batching (coalesce loads in one tick) and caching to collapse N+1 fan-out.
- [PostgreSQL — Index-Only Scans and Covering Indexes](https://www.postgresql.org/docs/current/indexes-index-only-scans.html) — covering indexes via `INCLUDE`, when index-only scans apply, and payload-column cautions.
- [Use The Index, Luke! — We need tool support for keyset pagination](https://use-the-index-luke.com/no-offset) — why `OFFSET` is slow and drifts, and why keyset/seek pagination is preferred.
- [MDN — Using readable streams](https://developer.mozilla.org/en-US/docs/Web/API/Streams_API/Using_readable_streams) — streaming a response body chunk by chunk to avoid buffering large payloads in memory.
