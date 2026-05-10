#!/usr/bin/env bash
# Runs the failure-injected Maestro flows that need a pre-set launch argument
# or appearance prelude (dark mode), accessibility flag, or extra value-args.
#
# Maestro 0.15 doesn't support launchArguments inside flows, so we pre-launch
# the app with the right flag(s) via simctl, then let Maestro drive the
# running app (the flows themselves omit launchApp).
#
# Idempotent — re-running produces the same outcome (uninstall + install + relaunch
# every run).

set -euo pipefail

SIMID="${SIMID:-5A559724-3B85-48CD-8369-5769D46E9449}"   # iPhone 17 Pro / iOS 26.4
BUNDLE="com.resortpass.interview.ResortPass"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$HOME/.maestro/bin:$PATH"

# Resolve the maestro wrapper that sets JAVA_HOME (used by the team-audit team).
MAESTRO_BIN="$(cd "$(dirname "$0")/.." && pwd)/team-audit/artifacts/maestro"
if [ ! -x "$MAESTRO_BIN" ]; then
    MAESTRO_BIN="maestro"
fi

# Look for the freshly built app in any of the conventional locations.
build_dir=""
for candidate in \
    "build/Build/Products/Debug-iphonesimulator/ResortPass.app" \
    "/tmp/resortpass-runner-build/Build/Products/Debug-iphonesimulator/ResortPass.app" \
    "/tmp/resortpass-ipad-build/Build/Products/Debug-iphonesimulator/ResortPass.app"; do
    if [ -d "$candidate" ]; then
        build_dir="$candidate"
        break
    fi
done

if [ -z "$build_dir" ]; then
    found=$(find build/Build/Products -name "ResortPass.app" -type d 2>/dev/null | head -1)
    [ -n "$found" ] && build_dir="$found"
fi
[ -z "$build_dir" ] && { echo "App not built. Run: xcodebuild ... build"; exit 1; }
echo "Using build_dir=$build_dir"

# Existing single-flag helper. Pre-launch the app with `-<flag> YES` then run the flow.
run() {
    local flag="$1"
    local flow="$2"
    echo ""
    echo "=== Flow: $flow (-$flag YES) ==="
    xcrun simctl uninstall "$SIMID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl install "$SIMID" "$build_dir"
    xcrun simctl launch "$SIMID" "$BUNDLE" "-$flag" "YES"
    sleep 2
    "$MAESTRO_BIN" test "$flow"
}

# Dark-mode + single-flag helper. Sets simulator appearance to dark before launch.
run_dark() {
    local flag="$1"
    local flow="$2"
    echo ""
    echo "=== Flow: $flow (DARK -$flag YES) ==="
    xcrun simctl ui "$SIMID" appearance dark || true
    xcrun simctl uninstall "$SIMID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl install "$SIMID" "$build_dir"
    xcrun simctl launch "$SIMID" "$BUNDLE" "-$flag" "YES"
    sleep 2
    "$MAESTRO_BIN" test "$flow"
}

# Dark-mode without any failure flag.
run_dark_no_flag() {
    local flow="$1"
    echo ""
    echo "=== Flow: $flow (DARK no-flag) ==="
    xcrun simctl ui "$SIMID" appearance dark || true
    xcrun simctl uninstall "$SIMID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl install "$SIMID" "$build_dir"
    xcrun simctl launch "$SIMID" "$BUNDLE"
    sleep 2
    "$MAESTRO_BIN" test "$flow"
}

# Multi-arg launch helper. First N args are passed verbatim to simctl launch
# (a single string of `-flag value -flag value ...`); last arg is the flow.
run_with_args() {
    local args_str="$1"
    local flow="$2"
    echo ""
    echo "=== Flow: $flow (args: $args_str) ==="
    xcrun simctl uninstall "$SIMID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl install "$SIMID" "$build_dir"
    # Word-split the args string deliberately.
    # shellcheck disable=SC2086
    xcrun simctl launch "$SIMID" "$BUNDLE" $args_str
    sleep 2
    "$MAESTRO_BIN" test "$flow"
}

# Restore light appearance — call after the dark batch, or as teardown.
restore_light() {
    echo ""
    echo "=== Restoring simulator appearance to light ==="
    xcrun simctl ui "$SIMID" appearance light || true
}

# Trap to ensure light mode restored even on script abort.
trap restore_light EXIT

# ====================================================================
# EXISTING ENTRIES — must not be removed or altered.
# ====================================================================
run ui-test-fail-search   .maestro/07-search-failed-retry.yaml
run ui-test-fail-hotels   .maestro/08-hotels-failed-retry.yaml
run ui-test-empty-hotels  .maestro/09-hotels-empty.yaml
# Flows 28/29 use the toggle-recovery modifier so retry-success is testable.
run_with_args "-ui-test-fail-search YES -ui-test-toggle-recovery-on-retry YES" .maestro/28-search-retry-failed.yaml
run_with_args "-ui-test-fail-hotels YES -ui-test-toggle-recovery-on-retry YES" .maestro/29-hotels-retry-failed.yaml

# ====================================================================
# DARK-MODE BATCH (10 flows: 32-41) — appearance prelude required.
# ====================================================================
run_dark_no_flag .maestro/32-dark-search-idle.yaml
run_dark_no_flag .maestro/33-dark-search-loaded.yaml
run_dark_no_flag .maestro/34-dark-search-empty.yaml
run_dark         ui-test-fail-search   .maestro/35-dark-search-failed.yaml
run_dark_no_flag .maestro/36-dark-null-coords-failed.yaml
run_dark_no_flag .maestro/37-dark-hotels-loaded.yaml
run_dark         ui-test-empty-hotels  .maestro/38-dark-hotels-empty.yaml
run_dark         ui-test-fail-hotels   .maestro/39-dark-hotels-failed.yaml
run_dark_no_flag .maestro/40-dark-detail-expanded.yaml
run_dark_no_flag .maestro/41-dark-empty-filter.yaml

# Restore light before continuing to non-dark flows.
restore_light

# ====================================================================
# DT + FAIL combo (1 flow: 46)
# ====================================================================
run_with_args "-ui-test-fail-search YES -UIPreferredContentSizeCategoryName UICTContentSizeCategoryXXL" .maestro/46-xxlarge-failed-state.yaml

# ====================================================================
# LANDSCAPE failure-flag flows (3 flows: 48, 50, 51)
# ====================================================================
run ui-test-fail-search   .maestro/48-landscape-search-failed.yaml
run ui-test-empty-hotels  .maestro/50-landscape-hotels-empty.yaml
run ui-test-fail-hotels   .maestro/51-landscape-hotels-failed.yaml

# ====================================================================
# LOCALE + FAIL combo (1 flow: 55)
# ====================================================================
run_with_args "-ui-test-fail-search YES -AppleLanguages (de-DE) -AppleLocale de_DE" .maestro/55-de-DE-failed-truncation.yaml

# ====================================================================
# P2 a11y flows (10 flows: 68-77) — single accessibility flag each.
# ====================================================================
run UIAccessibilityVoiceOverEnabled         .maestro/68-voiceover-search-idle.yaml
run UIAccessibilityVoiceOverEnabled         .maestro/69-voiceover-hotel-row.yaml
run UIAccessibilityVoiceOverEnabled         .maestro/70-voiceover-detail-close.yaml
run UIAccessibilityReduceMotionEnabled      .maestro/71-reduce-motion-card-tap.yaml
run UIAccessibilityReduceMotionEnabled      .maestro/72-reduce-motion-parallax-hero.yaml
run UIAccessibilityReduceMotionEnabled      .maestro/73-reduce-motion-filter-chip.yaml
run UIAccessibilityBoldTextEnabled          .maestro/74-bold-text-eyebrow-truncation.yaml
run UIAccessibilityIncreaseContrastEnabled  .maestro/75-increase-contrast-place-row.yaml
# AX5 flows take a value-arg, not a -flag YES pair, so use run_with_args.
run_with_args "-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL" .maestro/76-AX5-search-idle.yaml
run_with_args "-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL" .maestro/77-AX5-hotels-loaded.yaml

echo ""
echo "All failure-state / dark / DT / locale / a11y flows complete."
