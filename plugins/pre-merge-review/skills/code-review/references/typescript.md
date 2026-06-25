# TypeScript — HIGH

Default severity: **HIGH**. Apply to `.ts`, `.tsx`, `.mts`, `.cts` changes.

Assume `strict` is on (`noImplicitAny`, `strictNullChecks`, `useUnknownInCatchVariables`).
A change that only type-checks because strictness is off is a finding.

## Strict typing

- No explicit `any`, especially on the public surface (return types, exported
  signatures, props). `any` disables type checking on everything it touches —
  prefer `unknown` + narrowing at boundaries (typescript-eslint:
  no-explicit-any).
- No implicit `any`: parameters/variables the compiler can't infer must be typed
  (tsconfig: noImplicitAny). A new `function fn(s) {…}` is a finding.
- No `as` assertion that lies about the runtime shape; assertions have no runtime
  effect, so cast only after a real check. `unknown` → narrow, don't `as`.
- No `@ts-ignore`; if a suppression is truly needed use `@ts-expect-error` with a
  justification comment (typescript-eslint: ban-ts-comment). `@ts-expect-error`
  also fails to compile once the underlying error is gone.

```ts
// BAD
function parse(input: any): User { return input; }
// GOOD
function parse(input: unknown): User { return UserSchema.parse(input); }
```

## Null & undefined

- Optional values are checked before use; no non-null assertion `!` to silence
  the compiler — it asserts new information the type system can't verify and is a
  sign the code isn't fully type-safe (typescript-eslint: no-non-null-assertion).
- Optional chaining `?.` and nullish coalescing `??` replace `!` and truthy
  checks: `x?.foo() ?? fallback`, not `x!.foo()`.
- Distinguish "absent" (`undefined`) from "empty"/`null` consistently with the
  codebase.
- Truthy checks mishandle valid falsy values — `if (x)` skips `0`, `""`, `0n`,
  `NaN`. Use explicit `!== null` / `!= null` / `=== ""` when those are real data.
- Conditions that strict null types prove are always-true or always-false are a
  finding — usually a dead branch or a missing case (typescript-eslint:
  no-unnecessary-condition).
- Caught errors are `unknown`; narrow with `instanceof Error` before using
  `.message` (tsconfig: useUnknownInCatchVariables).

## Discriminated unions & exhaustiveness

- Variant types share a literal discriminant field and are narrowed by it
  (`switch (s.kind)`), not by guessing or `in`-sniffing optional fields.
- `switch`/`if` over a union handles every case; add a `never` exhaustiveness
  check so adding a new variant fails to compile (typescript-eslint:
  switch-exhaustiveness-check).

```ts
// GOOD — compile error if a new shape is added
function area(s: Shape): number {
  switch (s.kind) {
    case "circle": return Math.PI * s.r ** 2;
    case "square": return s.side ** 2;
    default: { const _exhaustive: never = s; throw new Error(`unhandled: ${_exhaustive}`); }
  }
}
```

## Type design

- Public types model the domain precisely — prefer a union of string literals
  over bare `string`, a known object shape over a wide record.
- Reuse shared/generated types instead of re-declaring drifting duplicates.
- Function signatures don't over-widen (`object`, `Function`, `{}`, `any[]`).
- Prefer custom type guards (`x is T` predicates) for reusable narrowing over
  scattered inline checks.

## Async typing

- `Promise`-returning calls are awaited, returned, or explicitly handled —
  floating promises drop rejections and crash or misorder (typescript-eslint:
  no-floating-promises; see `nodejs.md`). Mark deliberate fire-and-forget with
  `void`.
- Arrays of promises go through `Promise.all` / `allSettled` / `race` / `any`,
  not a loose loop of unawaited calls.
- No `await` on a non-thenable, and no `async` function whose body never awaits.

## Sources

- [TypeScript Handbook — Narrowing](https://www.typescriptlang.org/docs/handbook/2/narrowing.html) — typeof/truthiness/equality/`in`/`instanceof` guards, type predicates, discriminated unions, and the `never` exhaustiveness pattern
- [TypeScript Handbook — Everyday Types](https://www.typescriptlang.org/docs/handbook/2/everyday-types.html) — union & literal types, the `any` warning, and `as` assertions having no runtime effect
- [TSConfig Reference](https://www.typescriptlang.org/tsconfig/) — `strict` family: `noImplicitAny`, `strictNullChecks`, `useUnknownInCatchVariables`
- [typescript-eslint: no-explicit-any](https://typescript-eslint.io/rules/no-explicit-any/) — why `any` is unsafe and `unknown` is the alternative
- [typescript-eslint: no-non-null-assertion](https://typescript-eslint.io/rules/no-non-null-assertion/) — `!` asserts unverifiable info; prefer `?.` + `??`
- [typescript-eslint: ban-ts-comment](https://typescript-eslint.io/rules/ban-ts-comment/) — ban `@ts-ignore`, require a description on `@ts-expect-error`
- [typescript-eslint: no-floating-promises](https://typescript-eslint.io/rules/no-floating-promises/) — handle promises via await/return/`.catch`/`void`
