# React — HIGH

Default severity: **HIGH**. Apply to `.jsx` / `.tsx` React components and hooks.

`eslint-plugin-react-hooks` (`rules-of-hooks`, `exhaustive-deps`) already catches
the mechanical cases — hooks under a condition, a missing dep — and the build
should fail on them. So flag any code that disables those rules with an inline
`// eslint-disable`, but **don't spend a review re-deriving what the linter
prints.** This file targets the bugs the linter *can't* see: a dependency array
that's complete yet still wrong, an Effect that shouldn't exist, a key that
silently swaps component state, a memo that never fires. Review the **intent and
the mechanism**, not the call site.

## Stale closures & dependency intent

The lint passing means the deps are *complete*, not that they're *right*. Every
function created during a render closes over that render's props and state; an
Effect/callback that outlives the render (a timer, a subscription, an async
`.then`) sees frozen values unless the dep array tells React to recreate it.
Three failure shapes hide behind a green lint:

- **A non-primitive dep recreated every render** (object, array, inline
  function) makes the Effect re-run every render — the array is "exhaustive" but
  useless. Move the value inside the Effect, wrap it in `useMemo`/`useCallback`,
  or depend on the primitive field instead of the object.
- **An Effect that re-runs when you only wanted the latest value.** A value read
  inside the Effect but not meant to *trigger* it (the current `theme` when a
  socket connects, a callback prop) still has to be listed — and listing it
  re-runs the Effect. Don't drop it from the array (that's the stale-closure
  bug); move that read into a `useEffectEvent`, which always sees the latest
  value without being reactive.
- **`useRef` is not reactive.** Reading `ref.current` during render or expecting
  a ref change to re-run an Effect is a bug — refs intentionally don't trigger
  renders or re-fire Effects. They're the right tool *only* for values that must
  not cause a render (a DOM node, a mutable id, the previous value).

```jsx
// BAD — `options` is a fresh object each render → reconnects every render,
// yet exhaustive-deps is satisfied. The fix is not to delete the dep.
const options = { serverUrl, roomId };
useEffect(() => connect(options), [options]);

// GOOD — depend on the primitives; build the object inside.
useEffect(() => connect({ serverUrl, roomId }), [serverUrl, roomId]);

// GOOD — `onMessage`/`theme` should be read fresh but must NOT reconnect.
const onMessage = useEffectEvent(msg => showToast(theme, msg));
useEffect(() => {
  const c = connect(roomId);
  c.on('message', onMessage);
  return () => c.disconnect();
}, [roomId]); // theme intentionally absent — it lives in the Effect Event
```

## You might not need an Effect

An Effect runs *after* paint, so anything done in one to compute render output
costs an extra render pass and a flash of stale UI. Most Effects in review are
the wrong tool:

- **Derived data is computed during render**, not mirrored into `useState` and
  synced by an Effect. The mirror is always one render stale and can desync.
  Memoize with `useMemo` only if the computation is genuinely expensive.
- **A response to a user action belongs in the event handler**, not in an Effect
  watching the state the handler changed. "Submit happened" is known at the
  click — you don't need to observe a state change to find out.
- **Reset state on prop change with a `key`**, not an Effect that clears state.
  Changing a component's `key` remounts it with fresh state in one pass; an
  Effect does it in two and risks a visible stale frame.
- **No Effect chains** — `setState` in an Effect that triggers another Effect's
  `setState`. Each link is a full render + paint. Compute the whole next state
  together in the one event that started it.

```jsx
// BAD — derived state mirrored via Effect: extra render, can go stale.
const [fullName, setFullName] = useState('');
useEffect(() => setFullName(first + ' ' + last), [first, last]);

// GOOD — compute during render.
const fullName = first + ' ' + last;
```

## Effects: synchronization, cleanup, races

Model an Effect as *synchronizing* the component with an external system for as
long as it's needed — **not** as "run on mount." That mental shift is what makes
cleanup and re-syncing obvious:

- Any Effect that subscribes, connects, sets a timer, or adds a listener
  **returns a cleanup** that tears down exactly what it set up. Missing cleanup
  leaks listeners/sockets and double-fires after every dependency change.
- **Trust StrictMode's double-invoke.** In dev, React mounts → unmounts →
  remounts every component to surface missing cleanup. If a feature breaks only
  under StrictMode (doubled requests, two sockets, a counter off by one), the
  Effect is missing cleanup or isn't idempotent — fix the Effect, don't remove
  StrictMode.
- **Async work guards against a superseded run.** Without an `ignore` flag, a
  slow earlier request can resolve *after* a newer one and overwrite fresh state
  with stale data (last-to-resolve wins instead of last-to-fire). The cleanup
  flips the flag so the stale `.then` is a no-op.
- Fetching directly in an Effect is acceptable for simple cases but invites
  waterfalls (child fetches only after parent renders) and has no caching/dedup
  — prefer the framework's data layer or a query library where one exists.

```jsx
// GOOD — race-safe fetch: the latest request's result is the one that lands.
useEffect(() => {
  let ignore = false;
  fetchResults(query).then(json => { if (!ignore) setResults(json); });
  return () => { ignore = true; };
}, [query]);
```

## Lists & keys

A `key` is how reconciliation matches an element to its **identity** across
renders — which DOM node and which hook state belongs to which item. Get it
wrong and React silently attaches the wrong state to the wrong row:

- **Index-as-key is a bug whenever the list can reorder, insert, delete, or
  filter.** The key then encodes *position*, not identity, so when items shift,
  React keeps the old node and only swaps props — component state, uncontrolled
  input values, focus, and animations bleed from the item that *was* at that
  position into the one that *now* is. Use a stable id from the data. Index is
  fine only for a static, append-only, never-reordered list.
- **Keys must be stable across renders** — never `Math.random()` or a fresh UUID
  generated in render. A new key every render = remount every render: lost
  state, lost focus, killed animation, wasted DOM work.
- **`key` is consumed by React, not passed as a prop.** If the child needs the
  id, pass it again explicitly: `<Row key={id} id={id} />`.
- **A changing `key` is a deliberate state-reset tool**, not only a list
  concern: put `key={userId}` on a profile form to wipe all its internal state
  when the selected user changes — cleaner and faster than an Effect that resets
  each field.

## State: initialization, updates, identity

- **Pass a function to `useState` for expensive initial state.**
  `useState(buildInitial())` *calls* `buildInitial()` on every render and throws
  the result away after the first; `useState(() => buildInitial())` calls it
  once. Same trap with `useReducer`'s init.
- **Use the updater form when the next state depends on the previous one** —
  `setCount(c => c + 1)`, not `setCount(count + 1)`. Multiple updates in one
  event, or updates from an async callback / closure, read a stale `count`
  otherwise; the updater always gets the latest queued value.
- **Don't store in state what you can derive**, and don't duplicate one source
  of truth across two state variables that must agree — they will drift. Keep
  one canonical value; compute the rest.
- **Never mutate state or props in place** (`arr.push`, `obj.x = …`,
  `state.items[0] = …`). React compares by reference; an in-place change keeps
  the same reference, so the component won't re-render — or re-renders with
  values that already leaked into a previous snapshot. Produce a new object/array
  (spread, `map`, `filter`) or use Immer.
- **`useRef` for values that must not trigger a render** (a DOM node, a timer id,
  a "has this fired" flag, the latest value for an event handler). If changing it
  should update the UI, it's state, not a ref.

```jsx
// BAD — buildRows() runs on every render; '+1' reads a stale count in a batch.
const [rows, setRows] = useState(buildRows(data));
onClick = () => { setCount(count + 1); setCount(count + 1); }; // ends at +1

// GOOD — lazy init runs once; updater form composes correctly.
const [rows, setRows] = useState(() => buildRows(data));
onClick = () => { setCount(c => c + 1); setCount(c => c + 1); }; // ends at +2
```

## Re-render cost & memoization

- **If the React Compiler is enabled in this project, manual `useMemo` /
  `useCallback` / `memo` are mostly dead weight** — the compiler memoizes
  automatically and hand-memoization adds noise (and can mask a Rules-of-React
  violation the compiler would otherwise flag). Check the build setup before
  recommending either direction; don't add manual memo to a compiled codebase or
  strip it from one without the compiler.
- **`React.memo` is defeated by an unstable prop.** An inline object, array,
  arrow function, or `children` element passed to a memoized child is a new
  reference every render, so the child re-renders anyway. Either stabilize those
  props (`useMemo`/`useCallback`) or the `memo` is theater — flag memo + inline
  prop together.
- **A context value object must be stabilized** (`useMemo`) — otherwise every
  consumer re-renders on every provider-parent render, regardless of `memo`.
  Over-broad context (many unrelated values in one provider) re-renders every
  consumer when any field changes; split it.
- **Never define a component inside another component's render.** It's a new
  function identity each render, so React unmounts and remounts the entire
  subtree every time — state lost, Effects re-run, DOM thrashed. Hoist it out or
  pass it as a prop / `children`.
- Memoize for measured cost, not reflexively; but `useMemo`/`useCallback` also
  exist to **stabilize identity** for the cases above — that's a correctness use,
  not premature optimization.

## External stores & render purity

- **Subscribe to an external mutable store with `useSyncExternalStore`**, not an
  ad-hoc `useEffect` + `useState`. Under concurrent rendering, reading a mutable
  external value during render and separately in an Effect can *tear* — different
  parts of one render see different versions of the store.
- **Render must be pure.** Same props/state → same JSX, no side effects, no
  mutation of anything that existed before this render (props, state, context,
  module-level variables). Reading or writing a module global, a ref, or the DOM
  *during render* is the violation — that work belongs in an event handler or an
  Effect. Mutating an object you created locally in this render is fine.

## Controlled vs uncontrolled inputs

- An input is consistently **controlled** (`value` + `onChange`) or
  **uncontrolled** (`defaultValue`) — React errors when one flips to the other
  mid-life.
- A controlled `value` is never `undefined`/`null`; default it (`value={x ?? ''}`)
  so it doesn't silently switch from uncontrolled to controlled when async data
  arrives — the most common version of the flip above.
- A `value` without `onChange` is a read-only field (usually a mistake) — add
  the handler, or use `defaultValue` / `readOnly` to say so on purpose.
- One source of truth for form state.

## Data flow & composition

- State lives at its **lowest common owner** — not lifted higher than the set of
  components that actually read it. Lifting too high re-renders unrelated
  subtrees on every keystroke.
- Before drilling a prop through many layers, consider `children`/composition
  (pass the element down) over reaching for context — context is for genuinely
  cross-cutting values (theme, auth, locale), not a fix for one level of drilling.

## React 19 APIs (flag misuse, don't flag adoption)

- **`use()` is the one hook exempt from the Rules of Hooks** — it *may* be called
  in conditions and loops. It reads a promise (suspends until it resolves) or a
  context. A `use(promise)` needs a `<Suspense>` boundary above it and an error
  boundary for rejection; an unhandled rejected promise has no other catch.
- **`forwardRef` is no longer needed** — `ref` is a regular prop in function
  components. New code wrapping a component in `forwardRef` just to pass a ref is
  outdated; flag it as removable, not wrong.
- **Form/async state has dedicated hooks**: `useActionState` for an action's
  pending/result/error, `useFormStatus` for a child's view of the enclosing
  form's pending state, `useOptimistic` for optimistic UI. Hand-rolled
  `isPending`/`error` `useState` around an async submit is the pattern these
  replace.
- Server Components and `'use server'` actions have their own boundary rules —
  see `nextjs.md` when the project is Next.js.

## Accessibility

- **Prefer native semantic elements** (`<button>`, `<a>`, `<input>`,
  `<label>`) — they ship the role, focus behavior, and keyboard handling for
  free (first rule of ARIA). A `<div onClick>` acting as a button is invisible to
  keyboard and screen-reader users; if a non-semantic element is truly
  unavoidable it needs the matching `role`, `tabIndex`, **and** key handlers
  (Enter/Space), which is strictly more code than using `<button>`.
- An `onClick` with no keyboard path (no `onKeyDown`, not a native control) is a
  keyboard trap for anyone not using a mouse — the most common a11y regression in
  a React diff.
- Images have meaningful `alt` (empty `alt=""` for decorative); form controls
  have associated `<label>`s.
- Focus is managed for dialogs, menus, and route changes (move focus in, restore
  it on close); no focus trap.

## Sources

- [Rules of Hooks](https://react.dev/reference/rules/rules-of-hooks) — hooks only at the top level and only from React functions; the call-site rules the linter enforces.
- [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect) — derived state in render, event-handler vs Effect, key-based reset, no Effect chains.
- [Synchronizing with Effects](https://react.dev/learn/synchronizing-with-effects) — Effects as synchronization, cleanup, StrictMode double-invoke, the `ignore`-flag fetch race.
- [Separating Events from Effects](https://react.dev/learn/separating-events-from-effects) / [`useEffectEvent`](https://react.dev/reference/react/useEffectEvent) — reading the latest value without making it a reactive dependency.
- [Removing Effect Dependencies](https://react.dev/learn/removing-effect-dependencies) — why a complete dep array can still be wrong; object/function deps and how to fix them without suppressing the lint.
- [Rendering Lists](https://react.dev/learn/rendering-lists) / [Preserving and Resetting State](https://react.dev/learn/preserving-and-resetting-state) — keys as identity, index-as-key pitfalls, `key` as a deliberate state-reset.
- [`useState`](https://react.dev/reference/react/useState) — lazy initializer, updater function, why mutation doesn't re-render.
- [Keeping Components Pure](https://react.dev/learn/keeping-components-pure) — pure render, no mutation of pre-existing data, no side effects during render.
- [`useSyncExternalStore`](https://react.dev/reference/react/useSyncExternalStore) — subscribing to external stores, tearing under concurrent rendering.
- [`memo`](https://react.dev/reference/react/memo) / [React Compiler](https://react.dev/learn/react-compiler) — when memoization fires, when it's defeated by unstable props, when the compiler makes it redundant.
- [`use`](https://react.dev/reference/react/use) / [`useActionState`](https://react.dev/reference/react/useActionState) / [`useOptimistic`](https://react.dev/reference/react/useOptimistic) — React 19 reading-resources and Actions APIs.
- [input (React DOM)](https://react.dev/reference/react-dom/components/input) — controlled vs uncontrolled, the switching error, `value` needs `onChange`.
- [ARIA (MDN)](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA) — first rule of ARIA: prefer native HTML over re-purposed roles.
