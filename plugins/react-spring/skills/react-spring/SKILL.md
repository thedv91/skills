---
name: react-spring
description: >
  Expert guidance for the react-spring animation library (v9+, @react-spring/web),
  focused on its full hooks API. Apply whenever the user works with react-spring or
  mentions useSpring, useSprings, useTrail, useTransition, useChain, useSpringRef, the
  `animated` component, `to()` interpolation, or spring `config` — and more broadly for
  any spring-physics / mount-unmount / staggered / sequenced animation task in React,
  even when react-spring is not named explicitly. Covers each hook's signature, when to
  reach for it, the object-vs-function config forms, the imperative `api.start`/`api.stop`
  pattern, and common mistakes. Stack: React 16.8+, @react-spring/web v9+.
license: MIT
metadata:
  version: "1.0.0"
---

# react-spring (v9+, @react-spring/web)

react-spring animates with **spring physics** rather than fixed-duration easing: you
declare a target and the library computes a natural, interruptible motion toward it.
The v9 API is **hooks-first** and every hook shares the same mental model — a *config*
(where to animate from/to and how) produces *animated values* you spread onto an
`animated` element.

> Import everything from `@react-spring/web` (the DOM target). Native/three/konva
> targets exist but share the same hook signatures.

## The two config forms — learn this once, it applies to every hook

Every animation hook accepts its config in one of two shapes. The shape you pick
decides what the hook returns and how you drive the animation.

- **Object form** — `useSpring({ ... })`. Declarative. The animation runs on mount and
  re-runs whenever the passed values change. Returns **only the animated values**.
- **Function form** — `useSpring(() => ({ ... }), deps?)`. Returns a tuple
  `[values, api]` where `api` is a [`SpringRef`](#imperative-control-usespringref--apistart--apistop)
  for firing updates imperatively (in event handlers, effects, etc.). The optional
  `deps` array re-creates the config when a dependency changes, like `useMemo` deps.

Rule of thumb: reach for the **function form whenever a user interaction or external
event should trigger the animation**; use the **object form for animations that simply
follow render state**.

## `animated` — the component that receives spring values

Spring values are not plain numbers; they are live animated objects. Only an
`animated` element can read them without re-rendering React on every frame. Animating
a plain `<div>` with them silently does nothing.

```tsx
import { animated } from '@react-spring/web'

<animated.div style={styles} />        // built-in DOM elements: animated.<tag>
```

Wrap a custom component so it can forward the animated `style`/props:

```tsx
const AnimatedCard = animated(Card)    // Card must forward the props it receives
```

---

## useSpring — one set of animated values

Animate a single spring (which may hold many keys: `opacity`, `x`, `scale`, …). This is
the flagship hook; use it for the common "animate this element" case.

**Signatures**

```tsx
// Object form → returns the animated values
function useSpring(config: ConfigObject): SpringValues

// Function form → returns [values, api]
function useSpring(
  configFn: () => ConfigObject,
  deps?: any[]
): [values: SpringValues, api: SpringRef]
```

**Object form** — animates on mount / when values change:

```tsx
import { useSpring, animated } from '@react-spring/web'

function FadeIn() {
  const styles = useSpring({ from: { opacity: 0 }, to: { opacity: 1 } })
  return <animated.div style={styles}>Hello World</animated.div>
}
```

**Function form** — drive it imperatively from an event:

```tsx
import { useSpring, animated } from '@react-spring/web'

function Toggle() {
  const [styles, api] = useSpring(() => ({ x: 0 }))

  return (
    <animated.div
      onClick={() => api.start({ x: 100 })}
      style={{ width: 80, height: 80, background: '#ff6d6d', ...styles }}
    />
  )
}
```

**Common config keys** (shared by all the hooks below): `from`, `to`, `loop`, `delay`,
`immediate`, `config`, `reset`, `reverse`, `pause`, `cancel`, `ref`, and the lifecycle
callbacks `onStart`, `onChange`, `onRest`, `onResolve`, `onPause`, `onResume`. See
[Spring config](#spring-config--presets--physics) for the physics of `config`.

---

## useSprings — many independent springs

Use when you need **N springs that can each hold different values** — e.g. a list where
every row animates to its own target. It has the same config forms as `useSpring` but
takes a `count` first.

**Signatures**

```tsx
// Static: one shared config, or an array of per-index configs
function useSprings(count: number, config: ConfigObject | ConfigObject[]): SpringValues[]

// Function: config computed per index → returns [springs, api]
function useSprings(
  count: number,
  configFn: (index: number) => ConfigObject,
  deps?: any[]
): [springs: SpringValues[], api: SpringRef]
```

```tsx
import { useSprings, animated } from '@react-spring/web'

function Rows({ items }: { items: string[] }) {
  const [springs, api] = useSprings(items.length, index => ({
    from: { opacity: 0, x: -40 },
    to: { opacity: 1, x: 0 },
  }))

  return (
    <div>
      {springs.map((styles, i) => (
        <animated.div key={i} style={styles}>{items[i]}</animated.div>
      ))}
    </div>
  )
}
```

Prefer `useSprings` over calling `useSpring` in a loop — hooks can't be called inside
`.map()`, and one `api` controlling all springs is far easier to orchestrate.

---

## useTrail — a staggered chain of springs

`useTrail` has the **same signature as `useSprings`**; the only difference is it
automatically staggers the springs so each one trails (follows) the previous. Reach for
it when you want a cascade — a menu whose items fade in one after another.

**Signatures**

```tsx
function useTrail(count: number, config: ConfigObject): SpringValues[]

function useTrail(
  count: number,
  configFn: (index: number) => ConfigObject,
  deps?: any[]
): [trails: SpringValues[], api: SpringRef]
```

```tsx
import { useTrail, animated } from '@react-spring/web'

function Menu({ items }: { items: string[] }) {
  const trail = useTrail(items.length, {
    from: { opacity: 0, y: 20 },
    to: { opacity: 1, y: 0 },
  })

  return (
    <div>
      {trail.map((styles, i) => (
        <animated.div key={i} style={styles}>{items[i]}</animated.div>
      ))}
    </div>
  )
}
```

`useSprings` vs `useTrail`: use `useSprings` when the springs are independent; use
`useTrail` when they should ripple in order. (For finer control over the delay between
list items you can also use `useTransition`'s `trail` option.)

---

## useTransition — mount / unmount animations

The others animate elements that stay mounted. `useTransition` is the one that animates
elements **entering, leaving, and updating** as a list or a conditional changes — it
keeps leaving items in the DOM long enough to animate them out. Use it for lists that
add/remove items, route changes, modals, toasts.

**Signatures**

```tsx
// Static form → returns the transition render function
function useTransition<Item>(data: Item[] | Item, config: ConfigObject): TransitionFn<Item>

// Function form → returns [transitionFn, api]
function useTransition<Item>(
  data: Item[] | Item,
  configFn: () => ConfigObject,
  deps?: any[]
): [transition: TransitionFn<Item>, api: SpringRef]
```

**Config keys specific to transitions**: `from`, `enter`, `leave`, `update`, `keys`,
`initial`, `expires`, `trail`, `exitBeforeEnter`, plus the shared `config`, `onRest`,
`ref`. `enter`/`leave`/`update` are the phase targets; `keys` gives each item a stable
identity (see the mistake note below).

```tsx
import { useTransition, animated } from '@react-spring/web'

function List({ items }: { items: { id: number; text: string }[] }) {
  const transitions = useTransition(items, {
    keys: item => item.id,          // stable identity per item
    from: { opacity: 0, height: 0 },
    enter: { opacity: 1, height: 40 },
    leave: { opacity: 0, height: 0 },
  })

  // The returned function takes a render callback (style, item) => JSX.
  return transitions((style, item) => (
    <animated.div style={style}>{item.text}</animated.div>
  ))
}
```

For a single conditional element, pass a boolean-driven value and render inside the
callback only when the item is truthy:

```tsx
const transitions = useTransition(show, {
  from: { opacity: 0 }, enter: { opacity: 1 }, leave: { opacity: 0 },
})
return transitions((style, visible) => visible && <animated.div style={style} />)
```

---

## useChain — sequence multiple refs

`useChain` orchestrates **several already-defined animations** (each attached to its own
`useSpringRef`) so they run in sequence instead of all at once. Reach for it when you
have two or more separate hooks — e.g. a container that scales open, *then* its contents
transition in.

**Signature**

```tsx
function useChain(
  refs: ReadonlyArray<SpringRef>,
  timeSteps?: number[],   // fractions 0–1, one per ref, marking each start point
  timeFrame?: number      // total window the fractions map onto, default 1000 (ms)
): void
```

Each ref must be wired into its hook via the `ref` config key, and those hooks must
**not** self-start (`useChain` becomes their trigger). `timeSteps` places each ref on
the timeline: `timeStep * timeFrame` is that animation's delay.

```tsx
import {
  useSpring, useTransition, useSpringRef, useChain, animated,
} from '@react-spring/web'

function ExpandThenList({ items }: { items: string[] }) {
  const boxRef = useSpringRef()
  const box = useSpring({
    ref: boxRef,
    from: { size: '20%' },
    to: { size: '100%' },
  })

  const listRef = useSpringRef()
  const transitions = useTransition(items, {
    ref: listRef,
    trail: 400 / items.length,
    from: { opacity: 0, scale: 0 },
    enter: { opacity: 1, scale: 1 },
  })

  // box runs first; the list starts at 0.5 * 1000ms = 500ms in.
  useChain([boxRef, listRef], [0, 0.5])

  return (
    <animated.div style={{ width: box.size, height: box.size }}>
      {transitions((style, item) => <animated.div style={style}>{item}</animated.div>)}
    </animated.div>
  )
}
```

---

## Imperative control: useSpringRef + api.start / api.stop

`useSpringRef()` creates a `SpringRef` you attach with the `ref` config key. It gives you
an imperative handle to start, stop, and mutate animations outside the render flow —
and it is what `useChain` sequences. The function form of a hook returns this same
`api` as its second tuple element, so you often don't need `useSpringRef` unless you're
chaining or sharing one ref across hooks.

```tsx
const api = useSpringRef()
const styles = useSpring({ ref: api, from: { opacity: 0 }, to: { opacity: 1 } })
```

**Methods on the ref** (`api.` / the tuple's second element):

| Method | Purpose |
| --- | --- |
| `api.start(props?)` | Start (or restart) the animation; pass an update object to change targets first. |
| `api.stop(keys?)` | Stop some or all animated keys where they are. |
| `api.set(values)` | Jump to values immediately, without animating. |
| `api.pause(keys?)` / `api.resume(keys?)` | Pause / resume some or all keys. |
| `api.update(props)` | Queue props on each controller (call `api.start()` to flush). |

```tsx
const [styles, api] = useSpring(() => ({ x: 0, opacity: 1 }))

api.start({ x: 100 })   // animate to x:100
api.set({ opacity: 0 }) // instantly hide, no animation
api.stop()              // freeze wherever it is
```

---

## `to()` — interpolation

Derive a new animated value from an existing one without triggering a React re-render —
map a raw spring number into a color, a `transform` string, a clamped range, etc. Use
the **method form** for a single value and the **imported `to()`** to combine several.

```tsx
import { useSpring, animated, to } from '@react-spring/web'

const { x } = useSpring({ from: { x: 0 }, to: { x: 1 } })

// Method form — map one value:
<animated.div style={{ transform: x.to(v => `rotateZ(${v * 360}deg)`) }} />

// Range → output mapping (chainable):
<animated.div style={{ transform: x.to([0, 1], [0, 360]).to(deg => `rotateZ(${deg}deg)`) }} />

// Imported form — combine multiple values:
const { y } = useSpring({ from: { y: 0 }, to: { y: 1 } })
<animated.div style={{ transform: to([x, y], (x, y) => `translate(${x}px, ${y}px)`) }} />
```

Range/output mapping takes an optional `extrapolate`: `'extend'` (default, keeps
extrapolating), `'clamp'` (stops at range ends), or `'identity'` (returns the input
unchanged outside the range).

---

## Spring config — presets + physics

`config` tunes the spring's motion. Import named **presets** or pass raw physics
properties. Presets are the fast path; hand-tune only when a preset doesn't fit.

```tsx
import { useSpring, config } from '@react-spring/web'

useSpring({ to: { x: 100 }, config: config.wobbly })          // preset
useSpring({ to: { x: 100 }, config: { tension: 210, friction: 20 } }) // custom
```

**Presets** (`config.<name>`):

| Preset | tension | friction |
| --- | --- | --- |
| `default` | 170 | 26 |
| `gentle` | 120 | 14 |
| `wobbly` | 180 | 12 |
| `stiff` | 210 | 20 |
| `slow` | 280 | 60 |
| `molasses` | 280 | 120 |

**Custom physics properties**: `mass`, `tension`, `friction`, `clamp`, `precision`,
`velocity`, plus duration-based alternatives (`duration`, `easing`), decay (`decay`),
and `bounce`, `frequency`, `damping`, `round`, `progress`, `restVelocity`. Intuition:
higher `tension` = snappier, higher `friction` = more damping/slower settle, higher
`mass` = more inertia. Set `clamp: true` to forbid overshoot.

Per-key configs: `config` may also be a function `key => configForThatKey` to give each
animated key its own physics.

---

## Common mistakes

- **Animating a plain element.** Spring values must land on `animated.div` (or
  `animated(Component)`). A normal `<div style={styles}>` won't animate — nothing errors,
  it just sits still.
- **Mutating spring values or calling `.start()` on the values object.** Never reassign
  a spring value or push updates onto the returned values. Drive changes through the
  `api` from the function form (`api.start(...)`), or by changing the object-form config.
- **Missing `keys` in `useTransition`.** Without a stable `keys`, react-spring can't tell
  which items are the same across renders, so enter/leave animations misfire on reorder.
  Pass `keys: item => item.id` (or rely on stable primitives).
- **Calling a hook inside `.map()` for a list.** Hooks must run at the top level. Use
  `useSprings`/`useTrail`/`useTransition` with a `count` or data array instead of looping.
- **Expecting `useChain` to fire hooks that already ran.** Chained hooks must be wired
  with `ref` so they don't self-start; otherwise they animate immediately and `useChain`
  has nothing to sequence.
- **Reading a spring value as a number.** `styles.x` is an animated object, not a number.
  To compute from it, go through `.to(...)` / `to(...)`, not arithmetic.

## Reference

- useSpring: https://www.react-spring.dev/docs/components/use-spring
- useSprings: https://www.react-spring.dev/docs/components/use-springs
- useTrail: https://www.react-spring.dev/docs/components/use-trail
- useTransition: https://www.react-spring.dev/docs/components/use-transition
- useChain: https://www.react-spring.dev/docs/components/use-chain
- SpringRef / imperative api: https://www.react-spring.dev/docs/advanced/spring-ref
- Interpolation `to()`: https://www.react-spring.dev/docs/advanced/interpolation
- Config & presets: https://www.react-spring.dev/docs/advanced/config
