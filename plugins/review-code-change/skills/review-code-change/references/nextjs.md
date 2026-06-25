# Next.js — HIGH

Default severity: **HIGH**. Apply to Next.js projects — files under `app/**` or
`pages/**`, route handlers, server actions, `proxy.ts`/`middleware.ts`, and
`next.config.*`. This sits **on top of** `react.md` (component rules) and
`typescript.md`; load those too for `.tsx` files, and `nodejs.md` for
server-side route/handler logic.

> Version note: rules below target the current stable App Router (Next.js 16).
> Several defaults changed across versions — flagged inline. If the project pins
> an older Next.js, verify the rule against that version before raising it.

## Server vs Client Components (App Router)

- Layouts and pages are **Server Components by default**; `'use client'` is only
  needed for state, event handlers, lifecycle/effects, or browser-only APIs
  (`window`, `localStorage`) (Server and Client Components docs).
- `'use client'` declares a **boundary**: once a file is marked, all of its
  imports and the components it directly renders are pulled into the client
  bundle. Put it at the real interactivity boundary (a leaf like `<Search />`),
  not high in the tree — keep client bundles small.
- A Server Component passed as `children`/props to a Client Component is **not**
  pulled into the client bundle — it renders on the server and is passed as
  rendered output. Prefer this "slot" pattern over converting parents to
  client.
- Server-only code (DB clients, secrets, server SDKs, internal business logic)
  is never imported into a Client Component; mark such modules with
  `import 'server-only'` so misuse is a build error.
- Async Server Components don't introduce request **waterfalls** — independent
  fetches run concurrently (`Promise.all` or a `preload()` helper), not awaited
  one after another.
- React Context providers are Client Components — render them as deep as
  possible (wrap `{children}`), not around the whole `<html>` (Server/Client
  Components docs).

```tsx
// BAD — leaks a server secret into the client bundle
'use client';
const key = process.env.STRIPE_SECRET_KEY; // undefined in browser unless NEXT_PUBLIC_, then exposed
```

## Server Actions (`'use server'`)

- Treat every server action as a **public POST endpoint**: even an unused
  exported action is reachable by direct POST, so it must do its own
  authn **and** authz inside the action — a page-level auth check does **not**
  protect the action (Data Security docs).
- Authorization, not just authentication: verify the user owns/may act on the
  specific resource (guards against IDOR), don't just check "logged in".
- Validate/parse every input at the boundary (form data, args, `searchParams`,
  headers are all untrusted) — e.g. with zod; don't pass raw form data to the
  DB.
- Don't return raw DB records — return only the fields the UI needs; return
  values are serialized to the client.
- After a mutation, revalidate affected paths/tags (`revalidatePath` /
  `revalidateTag`, or `updateTag` with Cache Components).
- Keep mutations out of render — never set cookies / revalidate / write as a
  side effect during rendering; do it in an action (Data Security docs).
- Prefer a `server-only` Data Access Layer (DAL) that centralizes auth + queries
  and returns minimal DTOs; keep `'use server'` actions thin and delegating.

```ts
// BAD — trusts the page guard, no check inside the action
'use server';
export async function deletePost(id: string) {
  await db.post.delete({ where: { id } }); // no auth, no ownership check
}
// GOOD — re-auth + ownership inside the action
export async function deletePost(id: string) {
  const s = await auth();
  if (!s?.user) throw new Error('Unauthorized');
  const post = await db.post.findUnique({ where: { id } });
  if (post.authorId !== s.user.id) throw new Error('Forbidden');
  await db.post.delete({ where: { id } });
}
```

## Data fetching & caching

- **`fetch` is NOT cached by default** (changed in Next.js 15 — older "cached by
  default" assumptions are wrong). Opt in deliberately:
  `fetch(url, { cache: 'force-cache' })` for static, `next: { revalidate: N }`
  for time-based, `next: { tags: [...] }` for on-demand invalidation
  (Caching previous-model docs).
- Per-user / auth-dependent data is **not** statically cached. Reading
  `cookies()`/`headers()`/`searchParams`/`params` opts a segment into dynamic
  rendering (or, with Cache Components, must sit under `<Suspense>` or be passed
  into a `use cache` function) — confirm that's intended.
- Don't cache user-specific responses by mistake (`force-cache`/`use cache`
  without a per-user cache key leaks one user's data to another).
- Cache Components (Next.js 16, `cacheComponents: true`): caching is opt-in via
  the `use cache` directive (`cacheLife`, `cacheTag`); uncached dynamic work
  must be wrapped in `<Suspense>` or you get a build error. Non-`fetch` data
  without Cache Components is cached via `unstable_cache` or deduped with React
  `cache()`.
- After mutations, `revalidatePath`/`revalidateTag` (`updateTag` under Cache
  Components) keep the UI consistent; `router.refresh()` for client-driven
  refresh.
- `generateStaticParams` covers the params it claims to; `dynamicParams` and
  the `dynamic`/`revalidate`/`fetchCache` route segment config match the data's
  volatility (segment config is the previous-model API; not used with Cache
  Components).

## Environment & secrets

- Only truly public values use the `NEXT_PUBLIC_` prefix — prefixed vars are
  **inlined into the browser bundle at build time** (Environment Variables
  docs).
- Server secrets have **no** `NEXT_PUBLIC_` prefix and are read only in server
  code; non-prefixed vars are replaced with an empty string on the client.
- `NEXT_PUBLIC_` values are frozen at `next build` — they don't react to runtime
  env changes; runtime server values must be read in dynamic server code (after
  `connection()`/a Request-time API), not via `NEXT_PUBLIC_`.
- `.env*` files stay out of git (templates `.gitignore` them); don't commit
  secrets.

## Route handlers (`app/**/route.ts`)

- Correct HTTP methods exported (`GET`/`POST`/`PUT`/`PATCH`/`DELETE`/`HEAD`/
  `OPTIONS`); an unsupported method returns `405`. No `route.ts` at the same
  segment level as `page.tsx`/`page.js`.
- **Route Handlers are NOT cached by default** (changed in Next.js 15 — GET was
  cached by default in 13/14). Opt a `GET` into caching with
  `export const dynamic = 'force-static'`; other methods are never cached
  (Route Handlers docs).
- Responses use `Response`/`NextResponse` (or `Response.json`) with proper
  status and headers; type the context via `RouteContext<'/path/[id]'>` if used.
- Auth and validation present, same as any API endpoint — these are public
  entry points (`security.md`, `nodejs.md`).

## Built-in components & assets

- Images use `next/image` with `width`/`height` (or `fill`) to reserve space and
  avoid layout shift (CLS); static/dynamic-imported images get intrinsic
  dimensions automatically (Image Optimization docs).
- `sizes` is set for responsive/`fill` images — a missing `sizes` makes the
  browser download a far larger image than needed.
- `priority` only on the LCP / above-the-fold image (it disables lazy loading);
  don't sprinkle it everywhere.
- Remote images require explicit `images.remotePatterns` in `next.config` —
  scope `hostname`/`pathname` tightly to prevent abuse of the optimizer.
- Internal navigation uses `next/link`, not a raw `<a>` that triggers a full
  reload. Fonts via `next/font` (build-time self-hosting, no render-blocking
  external font links). `<head>`/SEO via the Metadata API, not ad-hoc tags.

## Rendering correctness

- No hydration mismatches: server and client render the same markup — guard
  browser-only values (`window`, `localStorage`, `Date.now()`, random) behind
  `useEffect` (or, under Cache Components, `connection()` before
  non-deterministic ops).
- `loading.tsx` / `error.tsx` / Suspense boundaries exist where streaming or slow
  data warrants; `error.tsx` is a Client Component with `reset`.
- Don't pass non-serializable props (functions, class instances) from Server to
  Client Components — React blocks them.

## Proxy / Middleware (`proxy.ts`)

- Next.js 16 renamed `middleware.ts` to **`proxy.ts`** (same routing role; edge
  runtime dropped — keep `middleware.ts` if you need edge); export a `proxy`
  function (named or default). One file per project (Proxy docs).
- Proxy now **defaults to the Node.js runtime** (was Edge before 16) and the
  `runtime` config option is not available in proxy files — don't assume edge
  constraints, but still keep it light: it runs before every matched request.
- Scope with `config.matcher` so it doesn't run on every asset request
  (`_next/static`, `_next/image`, `public/`) — without a matcher it runs on
  everything.
- Proxy is for fast checks (header tweaks, optimistic redirects), **not** slow
  data fetching or full session/authorization (do real authz in the
  action/handler/DAL); `fetch` cache options have no effect here.
- Redirects/rewrites validate their targets (no open redirect — `security.md`).

## Sources
- [Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components) — `'use client'` boundary, bundle size, server-only package, interleaving/slots, environment poisoning
- [How to think about data security in Next.js](https://nextjs.org/docs/app/guides/data-security) — Server Actions as public POST endpoints, authn vs authz/IDOR, input validation, DTOs, DAL, return-value filtering, taint APIs
- [Caching and Revalidating (Previous Model)](https://nextjs.org/docs/app/guides/caching-without-cache-components) — fetch uncached by default, `force-cache`/`revalidate`/`tags`, route segment config, `unstable_cache`, `revalidatePath`/`revalidateTag`
- [Caching (Cache Components)](https://nextjs.org/docs/app/getting-started/caching) — Next.js 16 `cacheComponents`/`use cache`, `cacheLife`/`cacheTag`, Suspense for uncached data, PPR
- [Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers) — supported methods/405, not cached by default, `force-static` opt-in, `NextRequest`/`NextResponse`
- [Environment Variables](https://nextjs.org/docs/app/guides/environment-variables) — `NEXT_PUBLIC_` build-time inlining, server-only by default, runtime caveat
- [Image Optimization](https://nextjs.org/docs/app/getting-started/images) — `width`/`height`/`fill`, `sizes`, `priority` for LCP, `remotePatterns`
- [Proxy](https://nextjs.org/docs/app/getting-started/proxy) — middleware→proxy rename (Next 16), Node.js runtime default, `matcher` scoping, not for heavy fetching/authz
