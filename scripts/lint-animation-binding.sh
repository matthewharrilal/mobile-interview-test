#!/usr/bin/env bash
# scripts/lint-animation-binding.sh
#
# Preventive grep-gate for Quality J of the cohesion sweep:
# fails CI if any SwiftUI `.animation(...)` view-modifier call omits the
# `value:` parameter.
#
# Usage:
#   scripts/lint-animation-binding.sh [ROOT_DIR]
#
# ROOT_DIR defaults to Sources/. Exit 0 = clean, 1 = violation found,
# 2 = invocation error.
#
# ─── Why this rule exists ────────────────────────────────────────────────
# `View.animation(_:)` (no `value:`) was deprecated in iOS 15 because it
# re-fires the animation on EVERY state change anywhere in the view's
# ancestry — animating layout shifts, conditional surfaces, image-load
# opacity, and other state the author never meant to animate. The bound
# form `.animation(_:value:)` ties the animation to a specific Equatable
# change, which is the only safe usage for a cohesive animation system.
#
# ─── What is blocked ─────────────────────────────────────────────────────
#   .animation(Theme.Animation.foo)                       ← FAIL
#
# ─── What is allowed ─────────────────────────────────────────────────────
#   .animation(Theme.Animation.foo, value: someState)     ← bound modifier
#   .transition(.opacity.animation(Theme.Animation.foo))  ← Transition API
#                                                           (different SPI;
#                                                           parameterizes
#                                                           the transition,
#                                                           not the view)
#
# ─── Detection heuristic ─────────────────────────────────────────────────
# A top-level view modifier `.animation(...)` always begins a line (after
# indentation). The transition-chained form is always mid-line
# (`.transition(.x.animation(…))`). So we match `^\s*\.animation\(` and
# require `value:` to appear within the call (this line + the next two,
# to tolerate multi-line argument formatting).

set -u
set -o pipefail

ROOT_DIR="${1:-Sources}"

if [ ! -d "$ROOT_DIR" ]; then
    echo "lint-animation-binding: directory not found: $ROOT_DIR" >&2
    exit 2
fi

violations=0
violations_text=""

# Collect candidate lines (top-of-line `.animation(` calls) across all .swift files.
# `mapfile -t` keeps each grep hit as one array element. `|| true` swallows
# grep's exit-1 when there are zero matches (which is the success case).
mapfile -t candidates < <(grep -rEn '^[[:space:]]*\.animation\(' "$ROOT_DIR" --include='*.swift' || true)

for hit in "${candidates[@]}"; do
    file="${hit%%:*}"
    rest="${hit#*:}"
    lineno="${rest%%:*}"
    content="${rest#*:}"

    # Look at this line + the next two for `value:` (tolerates multi-line args).
    end=$((lineno + 2))
    chunk=$(sed -n "${lineno},${end}p" "$file")

    if ! printf '%s' "$chunk" | grep -q 'value:'; then
        violations=$((violations + 1))
        violations_text+="  $file:$lineno: ${content}"$'\n'
    fi
done

if [ "$violations" -gt 0 ]; then
    echo "FAIL: $violations unbound .animation(...) view-modifier call(s) found:"
    echo ""
    printf '%s' "$violations_text"
    echo ""
    echo "Every View .animation(...) call must include a 'value:' parameter."
    echo "Use .animation(curve, value: someEquatableState) instead of .animation(curve)."
    echo "See scripts/README-lint-animation-binding.md for rationale."
    exit 1
fi

echo "OK: No unbound .animation(...) calls found in $ROOT_DIR/"
exit 0
