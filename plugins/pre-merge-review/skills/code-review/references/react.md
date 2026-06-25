# React — HIGH

Default severity: **HIGH**. Apply to `.jsx` / `.tsx` React components and hooks.

## Rules of Hooks (call site)

- Hooks are called only at the **top level** of a function component or custom
  hook — never inside conditions, loops, early-`return` branches, event
  handlers, `try`/`catch`/`finally`, or nested/callback functions (Rules of
  Hooks).
- Hooks are called only from React function components or custom hooks (named
  `useX`), not from plain JS functions.
- Rely on `eslint-plugin-react-hooks` (`rules-of-hooks`, `exhaustive-deps`) to
  catch these; flag code that disables it.

```jsx
// BAD — hook after a conditional return
if (!user) return null;
const [open, setOpen] = useState(false);
// GOOD — all hooks before any return
const [open, setOpen] = useState(false);
if (!user) return null;
```

## Hook dependency arrays

- `useEffect` / `useMemo` / `useCallback` list every reactive value they read;
  no missing deps that cause stale closures (`exhaustive-deps`).
- Don't suppress `exhaustive-deps` to hide a real missing dep — restructure
  instead (functional updates, refs, or `useEffectEvent` for latest-value
  reads). A ref used only to silence the lint masks the bug rather than fixing
  it.
- Effects with no real reactive input aren't re-running every render due to
  unstable object/array/function deps created inline.

```jsx
// BAD — new object each render, effect runs every time
useEffect(() => subscribe(opts), [{ id }]);
// GOOD
useEffect(() => subscribe({ id }), [id]);
```

## You might not need an Effect

- Data **derived** from props/state is computed during render (or cached with
  `useMemo`), not mirrored into `useState` and synced via `useEffect`.
- Logic that should run in response to a user action lives in the event
  handler, not an Effect watching the resulting state.
- Reset-all-state-on-prop-change uses a `key` on the component, not an Effect
  that clears state.
- No chains of Effects where each `setState` triggers the next — compute the
  next state together in one event handler.

```jsx
// BAD — derived state mirrored via effect (extra render, can go stale)
const [fullName, setFullName] = useState('');
useEffect(() => setFullName(first + ' ' + last), [first, last]);
// GOOD — compute during render
const fullName = first + ' ' + last;
```

## Lists & keys

- List items use a stable, unique `key` tied to identity — not the array index
  when items can reorder/insert/delete/filter (index keys cause subtle bugs).
- Keys are not generated during render (`Math.random()`, fresh UUID per render);
  they must stay stable across renders.
- Keys are unique among siblings and are not read as a prop — pass the id
  separately if the component needs it (`<Row key={id} id={id} />`).

## Effects & cleanup

- Effects that subscribe, open sockets/connections, set timers, or add
  listeners return a cleanup that tears them down (unsubscribe, `clearInterval`,
  `removeEventListener`, disconnect).
- Async work in effects guards against a superseded request: use an `ignore`
  flag set in cleanup so a stale response can't call `setState`.

```jsx
// GOOD — race-safe fetch (latest request wins)
useEffect(() => {
  let ignore = false;
  fetchTodos(userId).then(json => { if (!ignore) setTodos(json); });
  return () => { ignore = true; };
}, [userId]);
```

## Purity & state mutation

- Rendering is a pure calculation: same props → same JSX, with no side effects
  and no mutation of objects/variables that existed before the render
  (props, state, context, module globals). Mutating data created locally during
  render is fine.
- No direct mutation of state or props (`state.push(...)`, `obj.x = ...`) —
  produce new references so React detects the change.

## Re-render cost

- Expensive computations are memoized only where measured/needed; no blanket
  `useMemo`/`useCallback` noise.
- Context value objects are stabilized so consumers don't re-render on every
  parent render.
- Components aren't defined inside another component's render (a new function
  identity each render remounts the subtree and drops its state).

## Controlled vs uncontrolled

- An input is consistently controlled (`value` + `onChange`) or uncontrolled
  (`defaultValue`) — React errors when one switches to the other mid-life.
- A controlled `value` is never `undefined`/`null`; default it (`value={x ?? ''}`)
  so it doesn't flip from uncontrolled to controlled when data loads.
- A `value` without `onChange` makes the field read-only — add the handler (or
  `defaultValue` / `readOnly`).
- Form state has a single source of truth.

## State colocation & data flow

- State lives at the lowest common owner; not lifted higher than needed.

## Accessibility basics

- Prefer native semantic elements (`<button>`, `<a>`, `<input>`) over a `<div>`
  with `role` — native elements ship built-in roles, states, and keyboard
  behavior (first rule of ARIA). If a non-semantic element is unavoidable, it
  needs the matching `role` plus keyboard handlers.
- Images have `alt`; form controls have associated labels.
- No keyboard trap; focus is managed for dialogs/menus.

## Sources

- [Rules of Hooks](https://react.dev/reference/rules/rules-of-hooks) — hooks only at top level, only from React functions
- [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect) — derived state, event handlers, key-based reset, avoiding effect chains
- [Synchronizing with Effects](https://react.dev/learn/synchronizing-with-effects) — cleanup for subscriptions/timers/listeners and the `ignore`-flag fetch race pattern
- [Keeping Components Pure](https://react.dev/learn/keeping-components-pure) — pure render, no mutation of pre-existing data, local mutation OK
- [Rendering Lists](https://react.dev/learn/rendering-lists) — stable unique keys, index-as-key pitfalls, keys aren't props
- [input (React DOM)](https://react.dev/reference/react-dom/components/input) — controlled vs uncontrolled, switching error, `value` needs `onChange`
- [eslint-plugin-react-hooks](https://react.dev/reference/eslint-plugin-react-hooks) — `rules-of-hooks` and `exhaustive-deps` lint rules
- [ARIA (MDN)](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA) — first rule of ARIA: prefer native HTML over re-purposed roles
