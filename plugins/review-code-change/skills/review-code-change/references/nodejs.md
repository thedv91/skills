# Node.js — HIGH

Default severity: **HIGH**. Apply to server-side JavaScript/TypeScript (API
routes, services, scripts, CLIs). Not for browser-only React code.

## Async / await correctness

- Every promise is awaited or explicitly handled — no floating promises that
  drop errors.
- No `await` inside a loop where the work is independent and could run with
  `Promise.all` (and no unbounded `Promise.all` over a huge array — batch it).
- `async` callbacks passed to APIs expecting sync callbacks (`array.forEach`,
  some event emitters) don't silently swallow rejections.

```js
// BAD — rejection is lost
items.forEach(async (i) => await save(i));
// GOOD
await Promise.all(items.map((i) => save(i)));
```

## Unhandled rejections & error propagation

- Errors in async route/handler code are caught and forwarded to the framework's
  error path (e.g. `next(err)`), not left to crash the process. Route all errors
  from entry points through one centralized handler, not scattered middleware
  (Node Best Practices).
- A `process.on('unhandledRejection', …)` handler exists; an unhandled rejection
  is raised as an uncaught exception and, by default, terminates the process
  (Node `process` docs).
- `uncaughtException` / `unhandledRejection` are for logging and **synchronous**
  cleanup then exit — not for resuming. After an uncaught exception the process
  is in an undefined state; let a process manager (PM2, systemd, Kubernetes)
  restart it. Don't use it as "On Error Resume Next" (Node `process` docs).
- Operational errors (bad input, missing resource) are handled; programmer
  errors are allowed to crash and restart — fail fast (Node Best Practices).
- Event emitters that can emit `error` have an `error` listener (streams,
  sockets, child processes); an emitted `error` with no listener throws.
- No swallowing errors to "keep the server up" without logging.

```js
// BAD — process keeps running in an unknown state
process.on('uncaughtException', (err) => log(err)); // then resumes
// GOOD — log, synchronous cleanup, exit; let the supervisor restart
process.on('uncaughtException', (err) => { log(err); cleanup(); process.exit(1); });
```

## Event-loop blocking

- No synchronous, CPU-heavy work on the request path: large `JSON.parse` /
  `JSON.stringify` of untrusted size, sync crypto, big loops — offload to a
  worker pool or stream (Node "Don't Block the Event Loop").
- No `fs.*Sync` / `execSync` / `crypto.*Sync` / `zlib.*Sync` in hot request
  handlers — use the async variants (Node "Don't Block the Event Loop").
- No regexes vulnerable to catastrophic backtracking (ReDoS) on user input:
  watch for nested quantifiers `(a+)*`, overlapping alternations `(a|a)*`, and
  backreferences. Prefer `indexOf` for simple matches; vet patterns with
  `safe-regex` or use `node-re2` (Node "Don't Block the Event Loop", OWASP).
- Bound input size for any callback whose cost grows with input length; reject
  oversized inputs rather than processing them. Partition long work with
  `setImmediate` or offload to a worker pool (Node "Don't Block the Event Loop").

## Streams & buffers

- Large payloads are streamed, not buffered fully into memory.
- Use `stream.pipeline` (or `pipe`) rather than manual `data` handlers — it
  respects backpressure and, on error, destroys every stream in the chain;
  `pipe` does **not** close the destination on a source error, leaking memory
  and file descriptors (Node `stream` docs).
- When writing manually, honor the `writable.write()` return value — `false`
  means stop and wait for the `'drain'` event before writing more (Node `stream`
  docs).
- Request payload size is capped per content type (e.g. `express.json({ limit })`)
  so a large body can't exhaust memory (OWASP).
- Buffer allocations from user-supplied lengths are bounded; no `Buffer.alloc`
  on attacker-controlled size.

```js
// BAD — ignores backpressure and leaks on error
readable.on('data', (c) => writable.write(c));
// GOOD — backpressure handled, all streams destroyed on failure
const { pipeline } = require('node:stream/promises');
await pipeline(readable, transform, writable);
```

## Environment & configuration

- Config comes from environment/secret store and is validated at startup; fail
  fast on missing required vars (validate with a schema lib like zod/ajv —
  Node Best Practices).
- `NODE_ENV=production` is set in production so frameworks enable their
  optimizations (Node Best Practices).
- Logging uses a mature logger (Pino/Winston) writing structured output to
  stdout, not `console.log` (Node Best Practices).
- CPU-bound infra work (gzip, TLS termination) is delegated to a reverse proxy
  rather than run on the Node thread (Node Best Practices).
- No secrets logged or committed (see `security.md`).
- Resource handles (DB connections, file descriptors, timers) are closed/cleared
  on shutdown and on error paths.

## Process & concurrency

- No reliance on a single in-process value for state that must survive across
  workers/instances.
- Graceful shutdown handles `SIGTERM`/`SIGINT` where the surrounding service
  does.

## Sources

- [Node.js — Don't Block the Event Loop](https://nodejs.org/en/learn/asynchronous-work/dont-block-the-event-loop) — blocking vs non-blocking work, sync core APIs to avoid, ReDoS, bounding input, partitioning vs worker pool.
- [Node.js API — `process` events](https://nodejs.org/api/process.html) — `unhandledRejection`/`uncaughtException` semantics, default termination, why resuming after an uncaught exception is unsafe.
- [Node.js API — Stream](https://nodejs.org/api/stream.html) — `stream.pipeline` error forwarding and cleanup, `pipe` not closing destination on error, `write()` return value and `'drain'` backpressure.
- [OWASP Node.js Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Nodejs_Security_Cheat_Sheet.html) — request size limits, ReDoS, event-loop overload handling, EventEmitter error listeners, input validation.
- [Node.js Best Practices (goldbergyoni)](https://github.com/goldbergyoni/nodebestpractices) — centralized error handling, operational vs programmer errors, fail-fast validation, graceful exit on catastrophic errors, NODE_ENV, mature logging, reverse-proxy delegation.
