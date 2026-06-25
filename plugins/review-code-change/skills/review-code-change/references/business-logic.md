# Business logic — HIGH

Default severity: **HIGH**. Apply to every changed file. These are correctness
bugs, not style — judge the change against what it is clearly meant to do.
Business logic flaws use syntactically valid input and the application's
legitimate flow, so scanners and type-checkers miss them — only a reviewer who
understands the intended behavior can catch them (OWASP WSTG Business Logic
Testing; CWE-840).

## Understand the function before judging it

You cannot review business logic you have not understood. For each changed
function, first answer — then review against the answers:

- **What does it do?** State its job in one sentence from the code, not the name
  alone.
- **Who depends on it?** Follow the call sites; know what each caller expects
  back and on failure.
- **What business capability does it serve?** Which user-facing feature, flow,
  or rule does this code make happen (e.g. checkout, access control, billing,
  search ranking)?

If you cannot answer these from the diff plus surrounding code, say so in the
report rather than guessing.

## Business impact

Judge the change by its effect on the project's business, not only its local
correctness. A function can be locally correct yet harmful to the product.

- **Good or bad for the business?** Name the concrete effect of this change on
  the served capability — does it improve, preserve, or degrade the user/business
  outcome?
- **Regression risk:** does it weaken or remove an existing rule that protects
  the business (a usage/rate limit, a validation, an authorization, a fraud/abuse
  guard, a reconciliation step)? These are exactly the controls business-logic
  attacks target — discounts, refunds, ownership checks, usage caps (OWASP WSTG).
- **Blast radius:** how many users/flows does the served capability touch, and
  how visible/costly is a failure here (revenue, data loss, trust, compliance)?
  Raise severity for high-blast-radius logic.
- **Intent alignment:** does the behavior match the business intent implied by
  the surrounding code and call sites — not just compile and run? A plausible
  but wrong rule (wrong fee, wrong eligibility, wrong tier) is a HIGH/CRITICAL
  finding even when the code is clean.
- **Silent semantic change:** flag changes that quietly alter an externally
  observed contract (response shape, status meaning, default, ordering) that
  downstream consumers rely on.

## Correctness vs intent

- The code does what the surrounding names, comments, types, and call sites say
  it should do.
- Conditionals encode the intended rule — check boolean operators (`&&` vs
  `||`), comparison direction, and negation.
- Return values and error paths match what callers expect (verify the call
  sites, not just the function).
- Multi-step workflows enforce order and completion of prior steps — a caller
  cannot skip from step 1 to step 3 or replay a step out of sequence (CWE-841
  improper enforcement of behavioral workflow).

## Edge cases

- **Empty:** empty array/string/map/collection handled (no assumption of at
  least one element).
- **Null/undefined:** optional inputs and "not found" results handled before
  use.
- **Zero / negative:** zero, negative, and boundary numbers don't break math or
  cause division-by-zero.
- **Large:** large inputs don't overflow, truncate, or blow memory/time limits.

```js
// BAD — crashes on empty input
const avg = nums.reduce((a, b) => a + b) / nums.length;
// GOOD
const avg = nums.length ? nums.reduce((a, b) => a + b, 0) / nums.length : 0;
```

## Off-by-one & ranges

- Loop bounds and slice/substring indices include/exclude the right endpoints.
- Pagination, ranges, and counters are inclusive/exclusive as intended.

## State & transaction integrity

- Multi-step mutations that must all succeed are wrapped in a single
  transaction (all-or-nothing atomicity) or compensated on failure — no partial
  writes left behind (PostgreSQL transactions: a transaction either happens
  completely or not at all).
- Shared/concurrent state is guarded against races and lost updates; remember
  intermediate writes inside an open transaction are invisible to other
  transactions until commit, so don't rely on uncommitted state across requests.
- Invariants hold after the change (totals reconcile, status transitions are
  legal).

## Idempotency & retries

- Operations that can be retried (webhooks, jobs, payments) are idempotent or
  deduplicated — no double-charge / double-send. State-changing requests should
  carry a client-supplied idempotency key so a retry returns the original
  result instead of repeating the side effect (Stripe idempotency).
- The dedup key is stable across retries and stored durably (e.g. a unique
  constraint) so concurrent retries can't both execute; reads (GET/DELETE) are
  already idempotent and need no key.
- Side effects are not duplicated when a handler runs more than once.

## Time, money & units

- Money uses integer minor units (e.g. cents as `long`) or a fixed-decimal
  type — never binary floats; `0.10` summed ten times is not `1.00`, and
  rounding silently loses pennies (Fowler, Money pattern).
- Amounts carry their currency and are never mixed across currencies without an
  explicit conversion (Fowler, Money pattern).
- Time zones, DST, and date boundaries are handled; no naive local-time math.
- Units are consistent across the boundary (ms vs s, bytes vs KB).

## Sources

- [OWASP WSTG — Business Logic Testing](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/10-Business_Logic_Testing/README) — why logic flaws evade scanners and the categories to test (data validation, workflow circumvention, usage limits, integrity, timing).
- [CWE-840: Business Logic Errors](https://cwe.mitre.org/data/definitions/840.html) — category of weaknesses where legitimate functionality is abused; lists members like CWE-841 (behavioral workflow), ownership, and unique-action enforcement.
- [Stripe API — Idempotent requests](https://docs.stripe.com/api/idempotent_requests) — idempotency keys on POST requests so retries return the saved first response instead of repeating a charge.
- [Martin Fowler — Money](https://martinfowler.com/eaaCatalog/money.html) — represent money as an amount (integral minor units / fixed decimal) plus currency; avoid floats and rounding loss.
- [PostgreSQL — Transactions](https://www.postgresql.org/docs/current/tutorial-transactions.html) — all-or-nothing atomicity, COMMIT/ROLLBACK, and isolation of uncommitted intermediate state from concurrent transactions.
