---
name: react-compiler
description: >
  Write React components and hooks that are fully compatible with React Compiler's
  automatic memoization. Apply when writing any new component or hook, or when
  reviewing existing code before enabling the compiler: ensures components are pure,
  props/state are never mutated, side effects stay outside render, and manual
  useMemo/useCallback/React.memo are removed in favor of compiler-handled optimization.
  Stack: React 17+, React 18+, React 19+.
license: MIT
metadata:
  version: "1.0.0"
---

# react-compiler

React Compiler is a **build-time tool** that automatically memoizes your components
and hooks — it replaces manual `useMemo`, `useCallback`, and `React.memo`. For it to
work safely, your code must follow the **Rules of React** exactly. Violating them
causes the compiler to silently skip optimization or produce incorrect behavior.

## What the compiler does (and does not do)

- **Does**: memoizes React components and hooks automatically, skips unnecessary
  re-renders, caches expensive calculations inside render.
- **Does not**: memoize arbitrary helper functions called from components; memoization
  is per-component, not shared across the tree.
- **Result**: remove manual memoization — the compiler is as precise or more precise
  than hand-written `useMemo`/`useCallback`.

## Rules of React — the compiler enforces all of these

Break any rule and the compiler will either bail out of optimizing that component or
produce a bug.

### 1. Components and hooks must be pure

Every component must return the same output given the same inputs (props, state,
context). React may call your component multiple times.

```tsx
// ❌ impure — side effect during render
function Counter({ id }: { id: string }) {
  fetch(`/api/log?id=${id}`); // fires on every render
  return <div>{id}</div>;
}

// ✅ pure render, side effect moved to useEffect
function Counter({ id }: { id: string }) {
  useEffect(() => { fetch(`/api/log?id=${id}`); }, [id]);
  return <div>{id}</div>;
}
```

### 2. Props and state are immutable — never mutate them

```tsx
// ❌ mutating props
function TagList({ tags }: { tags: string[] }) {
  tags.push("extra"); // corrupts the caller's array
  return <ul>{tags.map(t => <li key={t}>{t}</li>)}</ul>;
}

// ✅ derive a new value
function TagList({ tags }: { tags: string[] }) {
  const all = [...tags, "extra"];
  return <ul>{all.map(t => <li key={t}>{t}</li>)}</ul>;
}
```

```tsx
// ❌ mutating state directly
function Form() {
  const [user, setUser] = useState({ name: "", age: 0 });
  const handleChange = () => {
    user.name = "Alice"; // mutation — React won't see this
    setUser(user);
  };
}

// ✅ create a new object
const handleChange = () => setUser({ ...user, name: "Alice" });
```

### 3. Hook return values and arguments are immutable

Values returned from or passed into hooks must not be mutated after the call.

```tsx
// ❌ mutating a value passed to a hook
const [items, setItems] = useState<string[]>([]);
items.push("new"); // mutates state — invisible to React

// ✅
setItems(prev => [...prev, "new"]);
```

### 4. JSX values are immutable after use

Once a value appears in JSX, don't mutate it.

```tsx
// ❌
const config = { label: "Submit" };
const btn = <Button config={config} />;
config.label = "Loading"; // too late — config is already in JSX

// ✅
const btn = <Button config={{ label: "Submit" }} />;
// or mutate before the JSX line
config.label = "Loading";
const btn = <Button config={config} />;
```

### 5. Call hooks only at the top level

Never inside conditions, loops, or nested functions.

```tsx
// ❌
function Profile({ isAdmin }: { isAdmin: boolean }) {
  if (isAdmin) {
    const [role, setRole] = useState("admin"); // conditional hook
  }
}

// ✅
function Profile({ isAdmin }: { isAdmin: boolean }) {
  const [role, setRole] = useState(isAdmin ? "admin" : "viewer");
}
```

### 6. Never call component functions directly

Always render via JSX, never as a plain function call.

```tsx
// ❌ — bypasses all of React's rendering rules
const content = MyComponent({ title });

// ✅
const content = <MyComponent title={title} />;
```

## Manual memoization: remove it, let the compiler work

With React Compiler enabled, hand-written memoization becomes **noise** — it makes
code harder to read and can actually interfere with the compiler's analysis.

```tsx
// ❌ Before — verbose and subtly broken
// (arrow function inside map creates a new ref every render,
// defeating the useCallback even though it looks correct)
const ExpensiveList = memo(function ExpensiveList({ data, onClick }) {
  const processed = useMemo(() => expensiveSort(data), [data]);
  const handleClick = useCallback((item) => onClick(item.id), [onClick]);
  return processed.map(item => (
    <Item key={item.id} onClick={() => handleClick(item)} />
  ));
});

// ✅ After — compiler handles memoization correctly
function ExpensiveList({ data, onClick }) {
  const processed = expensiveSort(data);
  const handleClick = (item) => onClick(item.id);
  return processed.map(item => (
    <Item key={item.id} onClick={() => handleClick(item)} />
  ));
}
```

**Keep** `useMemo`/`useCallback` only when you need the value as a stable reference
for Effect dependencies (not for performance).

## Opt-out: "use no memo"

Add the directive at the top of a component or hook to tell the compiler to skip it.
Use this as a **temporary escape hatch** while fixing violations, not permanently.

```tsx
function BrokenComponent() {
  "use no memo"; // compiler skips this component entirely
  // ... fix Rules of React violations here, then remove the directive
}
```

For gradual rollout, `compilationMode: 'annotation'` in the compiler config means
only functions with `"use memo"` are compiled — the inverse of opt-out.

## ESLint

Install `eslint-plugin-react-compiler` to catch Rules of React violations before
they reach the compiler. It reports mutations, conditional hooks, and other
violations that would cause the compiler to bail out silently.

## What the compiler cannot optimize

- **Arbitrary helper functions** that are not components or hooks.
- **Expensive computations shared across components** — memoization is not shared;
  move those outside React (module-level cache, server-side, etc.).

## Checklist when writing a component

1. Does every render path return the same output for the same inputs?
2. Are props, state, and hook return values treated as read-only?
3. Are all mutations done on locally created values, not on inputs?
4. Are hooks called unconditionally at the top level?
5. Are all side effects inside `useEffect`, event handlers, or async functions —
   not during render?
6. Is there any `useMemo`/`useCallback`/`React.memo` added purely for performance?
   Remove it — the compiler handles it.
7. Any `"use no memo"` left in place? Remove once violations are fixed.

## Reference

- React Compiler overview: https://react.dev/learn/react-compiler
- Rules of React: https://react.dev/reference/rules
- Incremental adoption: https://react.dev/learn/react-compiler/incremental-adoption
