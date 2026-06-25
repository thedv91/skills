# End-user perspective — HIGH

Default severity: **HIGH**. Apply to every changed file that sits on a path a
real person reaches — through a UI, an API, or a CLI. Stop reading the diff as
the developer who wrote it and reason as the person who will *use* it: they do
not see your code, only what it does to them. A change can be locally correct
and still strand, confuse, or mislead that person — judge the change by what
they experience, not by whether it compiles and returns. If a changed path has
no user-facing surface (pure internal plumbing), this standard yields no
findings; say so rather than inventing one.

Every finding under this standard **must state the concrete user impact** — the
actual symptom the person sees or the loss they suffer — not an abstract code
smell. "Returns undefined on the empty branch" is not a finding here; "the
user's saved draft silently disappears and they see a blank page with no error"
is.

The prompts below are starting points, not a closed checklist. Surface
user-facing risks they do not list when the change warrants it.

## Trace the user journey

For each changed path, walk it as the user, end to end — then review against
what you walked:

- **What action triggers it?** The tap, the form submit, the request, the
  command they actually run.
- **What is the happy path?** Step by step, what the user does and what the
  system does back at each step.
- **What do they actually receive?** The rendered screen, the response body, the
  printed output, the redirect — and is it the thing they were trying to get?

If you cannot reconstruct the journey from the diff plus surrounding code, say
so in the report rather than guessing at the experience.

## User-driven edge cases

Real people do not behave like a test harness. Reason about what *they* do, not
only what is technically malformed:

- **Repeat & retry:** double-submit a button, refresh mid-flight, hit retry
  after a spinner hangs — does the action fire twice, or recover cleanly?
- **Abandon & resume:** leave a multi-step flow halfway and come back later — is
  partial state sane, or is the user wedged?
- **Back button after a state change:** press Back once the server state already
  moved — does the screen lie about the current state?
- **Concurrent sessions:** the same user on two devices/tabs acting at once —
  does one clobber the other, or show stale data as if it were live?
- **Surprising input:** leading/trailing whitespace, unicode/emoji/RTL, pasted
  HTML, a blank optional field, boundary values (0, max length, the limit ±1),
  fields submitted out of the expected order.
- **Network reality:** a slow request, a dropped connection mid-action, a 500
  from a dependency — what does the user see, and is their data safe?
- **Session expiry mid-flow:** the token dies between opening a form and
  submitting it — are they told, and can they recover their input?

## Map each failure to the user-visible symptom

For every way the changed code can fail, name the symptom the user actually
hits, then judge whether that symptom is acceptable for this flow:

- White screen / crash with no message.
- Silent data loss — their input vanishes with no error.
- Wrong, stale, or **another user's** data shown as theirs (a trust and privacy
  failure, not just a bug).
- A misleading or generic error ("Something went wrong") that gives no path
  forward.
- A slow response that prompts them to retry — and thereby duplicates a side
  effect (double order, double charge).
- A dead end: blocked with no way to undo, go back, or recover.

A failure mode is only acceptable if the user can tell what happened and what to
do next. "It throws" is not an answer — *what do they see, and are they stuck?*

## User feedback on every async action

Anything that takes time or can fail must communicate its state in plain
language the user understands:

- **Loading:** the user knows the system received their action and is working
  (visibility of system status), not staring at a frozen control.
- **Success:** they get unambiguous confirmation the thing happened.
- **Error:** the message says what went wrong in human terms and offers a way
  forward — not an error code, a stack trace, or silence.

```jsx
// BAD — no loading or error state; on failure the user sees nothing change
// and re-clicks, firing a second submit.
<button onClick={() => saveOrder()}>Place order</button>

// GOOD — the user always knows where they stand, and the control is guarded
// against the double-submit their uncertainty would otherwise cause.
<button onClick={placeOrder} disabled={status === "saving"}>
  {status === "saving" ? "Placing order…" : "Place order"}
</button>
{status === "error" && <p role="alert">Couldn't place your order — your cart is saved. Try again.</p>}
```

## Sources

- [NN/g — 10 Usability Heuristics for User Interface Design](https://www.nngroup.com/articles/ten-usability-heuristics/) — visibility of system status, error prevention, help users recognize/recover from errors; the basis for the feedback and failure-symptom prompts.
- [NN/g — Error-Message Guidelines](https://www.nngroup.com/articles/error-message-guidelines/) — errors must be expressed in plain language, say what happened, and offer a constructive way forward.
- [NN/g — Response Times: The 3 Important Limits](https://www.nngroup.com/articles/response-times-3-important-limits/) — why slow actions need explicit progress feedback, and the thresholds at which users lose confidence and retry.
