#!/usr/bin/env bash
# Runs the failure-injected Maestro flows that need a pre-set launch argument.
# Maestro 0.15 doesn't support launchArguments inside flows, so we pre-launch
# the app with the right flag via simctl, then let Maestro drive the running app
# (the flows themselves omit launchApp).

set -euo pipefail

SIMID="${SIMID:-5A559724-3B85-48CD-8369-5769D46E9449}"   # iPhone 17 Pro / iOS 26.4
BUNDLE="com.resortpass.interview.ResortPass"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$HOME/.maestro/bin:$PATH"

build_dir=$(find build/Build/Products -name "ResortPass.app" -type d | head -1)
[ -z "$build_dir" ] && { echo "App not built. Run: xcodebuild ... build"; exit 1; }

run() {
    local flag="$1"
    local flow="$2"
    echo ""
    echo "=== Flow: $flow ($flag) ==="
    xcrun simctl uninstall "$SIMID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl install "$SIMID" "$build_dir"
    xcrun simctl launch "$SIMID" "$BUNDLE" "-$flag" "YES"
    sleep 2
    maestro test "$flow"
}

run ui-test-fail-search   .maestro/07-search-failed-retry.yaml
run ui-test-fail-hotels   .maestro/08-hotels-failed-retry.yaml
run ui-test-empty-hotels  .maestro/09-hotels-empty.yaml

echo ""
echo "All failure-state flows complete."
