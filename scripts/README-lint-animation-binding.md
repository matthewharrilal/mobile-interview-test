# lint-animation-binding

Preventive lint gate for Quality **J** of the cohesion sweep:
**every `View.animation(...)` modifier call must include a `value:` parameter.**

## What this gate enforces

| Form                                                          | Status   |
|---------------------------------------------------------------|----------|
| `.animation(curve, value: someState)`                         | allowed  |
| `.transition(.opacity.animation(curve))`                      | allowed  |
| `.animation(curve)` (top-level view modifier, no `value:`)    | **fails CI** |

## Why this matters

`View.animation(_:)` (no `value:`) was deprecated in iOS 15. The unbound form
re-fires the animation on **every** state change anywhere in the view's
ancestry — animating layout shifts, conditional surfaces, image-load opacity,
and other state the author never meant to animate. It is one of the most
common sources of cohesion bugs (jittery list rows during scroll, content
flashes during navigation, surfaces that "breathe" when nothing meaningful
changed).

The bound form `.animation(_:value:)` ties the animation to a specific
`Equatable` change, which is the only safe usage for a cohesive animation
system.

The `Transition.animation(_:)` API (used as `.transition(.x.animation(...))`)
is a **different SPI** — it parameterizes the transition itself, not a
view-tree-wide implicit animation — and is therefore allowed.

## How detection works

A top-level view modifier `.animation(...)` always begins a line (after
indentation). The transition-chained form is always mid-line
(`.transition(.x.animation(…))`). The script matches `^\s*\.animation\(` and
requires `value:` to appear within the call (current line plus the next two,
to tolerate multi-line argument formatting).

This is a syntactic heuristic, not an AST analysis — false negatives are
possible if someone formats a view modifier on the same line as the preceding
modifier:

```swift
.padding().animation(curve)   // would NOT be caught (mid-line .animation)
```

In practice the project's formatting convention places each modifier on its
own line, so this gap is acceptable for a preventive gate. If the convention
ever changes, upgrade to a SwiftLint custom rule or an AST-based check.

## Running it

```bash
# default scans Sources/
scripts/lint-animation-binding.sh

# scan a different root
scripts/lint-animation-binding.sh path/to/dir

# via Makefile convenience target
make lint-animation
```

Exit codes: `0` clean, `1` violation, `2` invocation error.

## Wiring it into CI

The project does not currently use SwiftLint or GitHub Actions. When CI is
introduced, add a step that invokes this script — for example, in a
`.github/workflows/lint.yml`:

```yaml
- name: Lint animation binding
  run: scripts/lint-animation-binding.sh
```

Until then, the script is invoked manually or via `make lint-animation` and
must be added to any pre-merge check the team adopts.

## Remediation

When this gate flags a call:

```swift
// Before — re-fires on every state change in the ancestry:
.animation(Theme.Animation.morphSpring)

// After — fires only when `viewModel.state.presentation` changes:
.animation(Theme.Animation.morphSpring, value: viewModel.state.presentation)
```

If the animation truly should fire on any state change (rare, and almost
certainly a smell), wrap the relevant change in `withAnimation { … }` at the
mutation site instead. Do not reach for the unbound `.animation(_:)` form —
the deprecation exists for a reason.
