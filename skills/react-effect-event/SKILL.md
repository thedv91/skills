---
name: react-effect-event
description: >
  Use React's useEffectEvent to separate reactive dependencies from non-reactive
  "latest value" reads inside Effects. Apply when writing or reviewing any useEffect
  whose dependency array is fighting you: stale closures, an effect that re-runs
  (re-subscribes / reconnects / restarts a timer) more than it should, an
  eslint-disable-next-line react-hooks/exhaustive-deps, a value read inside an event
  callback or interval that you do NOT want to trigger re-synchronization, or a ref
  used purely to dodge a dependency. Stack: React 19.2+ (useEffectEvent is stable,
  imported from 'react'), React Native / Expo.
license: MIT
metadata:
  version: "1.0.0"
---

# react-effect-event

`useEffectEvent` lets an Effect read the **latest** props/state without listing them
as dependencies, so the Effect re-runs only when its _truly reactive_ inputs change.
It is the correct tool for the recurring tension in this codebase: an Effect that
sets up a subscription / listener / interval, but whose callback also reads values
that should NOT cause it to tear down and re-set-up.

## When to apply

Reach for this skill when you see — or are about to write — any of these:

- An Effect re-runs too often: a connection reconnects, a `addEventListener` is
  removed and re-added, a `setInterval` restarts, an audio/video subscription is
  torn down, just because a value read _inside the callback_ changed.
- A `// eslint-disable-next-line react-hooks/exhaustive-deps` used to silence a
  warning about a value the author deliberately wants to read fresh but not react to.
- A `useRef` whose only job is to smuggle the latest prop/state into an Effect or
  listener so it doesn't appear in the dependency array (`fooRef.current = foo`).
- A stale-closure bug: a callback inside an Effect captured an old value because the
  Effect intentionally has an empty/narrow dependency array.

If none of these apply — if the Effect simply needs to re-synchronize when a value
changes — do **not** introduce `useEffectEvent`. Plain dependencies are correct.

## The core distinction: reactive vs. non-reactive

Inside an Effect, split every value you read into two buckets:

- **Reactive** — the Effect _must_ re-run when it changes (e.g. `roomId` for a
  connection, `url` for a subscription, `delay` for an interval). → keep in deps.
- **Non-reactive** — you want the _latest_ value at call time, but a change to it
  should **not** restart the Effect (e.g. `theme`, `muted`, the current `volume`,
  an `onChange` handler from props, the latest `position`). → move the logic that
  reads it into an Effect Event.

> Decision rule: "If this value changes, should the subscription / listener / timer
> be torn down and recreated?" **Yes → dependency. No → Effect Event.**

## Canonical pattern

```tsx
import { useEffect, useEffectEvent } from "react";

function ChatRoom({ roomId, theme }: { roomId: string; theme: Theme }) {
  // Non-reactive logic: reads latest `theme`, but theme changes must NOT reconnect.
  const onConnected = useEffectEvent(() => {
    showNotification("Connected!", theme);
  });

  useEffect(() => {
    const connection = createConnection(roomId);
    connection.on("connected", () => onConnected());
    connection.connect();
    return () => connection.disconnect();
  }, [roomId]); // ✅ only roomId. No theme. No eslint-disable. No lint warning.
}
```

The lint rule (`eslint-plugin-react-hooks`) understands `useEffectEvent` and will
**not** demand the Effect Event or the values it reads in the dependency array.

## Hard rules — the linter enforces these; violating them is a bug

- **Declare at the top level** of the component or custom Hook. Never inside loops,
  conditions, or nested functions.
- **Call only from inside Effects or other Effect Events.** Never during render,
  never from a plain event handler (`onPress`), never pass it as a prop to a child
  component or into another Hook. For those cases use a normal function or
  `useCallback`.
- **Never put an Effect Event in a dependency array.** Its identity intentionally
  changes every render — listing it makes the Effect re-run constantly. That
  instability is a deliberate runtime tripwire, not a thing to "fix."
- **Keep reactive values in deps.** `useEffectEvent` is NOT a tool to empty the
  dependency array or silence `exhaustive-deps` wholesale. Only the genuinely
  non-reactive _event-like_ logic moves into it; reactive deps stay listed. Misusing
  it this way hides real bugs.

## When NOT to use it

- The value should re-synchronize the Effect → just list it as a dependency.
- You need a stable callback to pass to a child or memoized component → `useCallback`.
- The logic runs during render or in a UI event handler (not from an Effect) → it is
  not an Effect Event; write a normal function.
- Reaching for it purely to make a lint warning disappear → stop; fix the dependency
  honestly instead.

## Refactor recipes for patterns common in this codebase

**Replace a "latest value" ref smuggled into a listener**

```tsx
// ❌ Before: ref exists only to dodge the dependency array
const volumeRef = useRef(volume);
volumeRef.current = volume;
useEffect(() => {
  const sub = player.addListener("tick", () => applyVolume(volumeRef.current));
  return () => sub.remove();
}, []); // lint: silenced or lying

// ✅ After
const onTick = useEffectEvent(() => applyVolume(volume));
useEffect(() => {
  const sub = player.addListener("tick", () => onTick());
  return () => sub.remove();
}, [player]); // honest deps; no ref, no disable
```

**Interval that reads latest state without restarting**

```tsx
const onTick = useEffectEvent(() => setCount(count + increment));
useEffect(() => {
  const id = setInterval(() => onTick(), 1000);
  return () => clearInterval(id);
}, []); // ✅ timer is NOT recreated when count/increment change
```

**Effect that reconnects on `roomId` but notifies using non-reactive `muted`/`theme`**

```tsx
const onConnected = useEffectEvent((id: string) => {
  if (!muted) showNotification("Connected to " + id, theme);
});
useEffect(() => {
  const connection = createConnection(roomId);
  connection.on("connected", () => onConnected(roomId));
  connection.connect();
  return () => connection.disconnect();
}, [roomId]); // ✅ reconnect on roomId only — not on muted or theme
```

## Review checklist

When writing or reviewing an Effect, confirm:

1. Every value in the dependency array genuinely _should_ re-run the Effect.
2. Any `exhaustive-deps` disable or dependency-dodging ref is reconsidered — could an
   Effect Event remove the need for it?
3. Each `useEffectEvent` is declared at top level and called only from Effects.
4. No Effect Event appears in a dependency array.
5. Reactive values were NOT hidden inside an Effect Event to shrink the deps.

## Reference

Official docs: https://react.dev/reference/react/useEffectEvent
Background — "Separating Events from Effects":
https://react.dev/learn/separating-events-from-effects
