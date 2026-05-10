#!/usr/bin/env bash
# scripts/audit.sh
# Continuous code-quality audit for ResortPassApp.
#
# Mechanical checks for the four dimensions defined in
# ux-research/team/12-continuous-audit.json:
#   D1 Code hygiene
#   D2 Architecture & abstraction smells
#   D3 Senior judgment & technical debt
#   D4 System-as-a-whole
#
# Usage:
#   scripts/audit.sh [DIMENSION] [TARGET]
#
# DIMENSION: hygiene | architecture | judgment | system | all (default: all)
# TARGET:    path to inspect (default: Sources/)
#
# Exit code: 0 if no MECHANICAL failures detected; non-zero otherwise.
# Judgment-dimension findings are surfaced by agent dispatch separately.

set -u
set -o pipefail

DIM="${1:-all}"
TARGET="${2:-Sources/}"
FAIL=0

cd "$(dirname "$0")/.."

bold()  { printf '\n\033[1m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }

flag() {
    red "  ✗ $1"
    FAIL=$((FAIL + 1))
}
ok() { green "  ✓ $1"; }

# ---------- D1: Code hygiene ----------
audit_hygiene() {
    bold "=== D1: Code hygiene ==="

    # 1. DRY — duplicated function signatures (heuristic; ast-grep would be tighter)
    bold "DRY (duplicated function signatures):"
    dupes=$(grep -rEh '^[[:space:]]*func [a-zA-Z]+\([^)]*\)' "$TARGET" 2>/dev/null \
            | sed -E 's/[[:space:]]+/ /g' | sort | uniq -c | awk '$1 > 1' | head -10)
    if [ -n "$dupes" ]; then
        echo "$dupes"
        flag "Duplicate function signatures across files — judgment review needed"
    else
        ok "No duplicate function signatures"
    fi

    # 2. Singletons
    bold "Singletons (static let shared):"
    if grep -rn 'static let shared' "$TARGET" 2>/dev/null; then
        flag "Singleton(s) detected — justify or refactor to DI"
    else
        ok "No singletons"
    fi

    # 3. Dead code — flagged by Xcode warnings; here we grep for trivially-unused privates
    bold "Dead code (private symbols never referenced):"
    # Heuristic: private funcs whose name appears only once in the file (the def itself)
    while IFS= read -r match; do
        file=$(echo "$match" | cut -d: -f1)
        name=$(echo "$match" | sed -E 's/.*func ([a-zA-Z_][a-zA-Z0-9_]*).*/\1/')
        [ -z "$name" ] && continue
        count=$(grep -c "\\b${name}\\b" "$file" 2>/dev/null || echo 0)
        if [ "${count:-0}" -eq 1 ]; then
            echo "  $file: private func ${name} — only definition site found"
            FAIL=$((FAIL + 1))
        fi
    done < <(grep -rEn '^[[:space:]]*private func ' "$TARGET" 2>/dev/null | head -100)

    # 4. Magic numbers (in view-layer layout)
    bold "Magic numbers in view layout (frame/padding/spacing not using Theme):"
    mn=$(grep -rEn '(\.frame\(|\.padding\(|spacing:)[^)]*[0-9]{2,}' "$TARGET" 2>/dev/null \
            | grep -v 'Theme\.' | grep -v Tests/ | grep -v '#Preview' | head -20)
    if [ -n "$mn" ]; then
        echo "$mn"
        flag "Magic numbers in view code — use Theme.Spacing tokens"
    else
        ok "No magic numbers in view layout"
    fi

    # 5. Commented-out code (heuristic — // followed by Swift-like punctuation)
    bold "Commented-out code (heuristic):"
    cc=$(grep -rEn '^[[:space:]]*//[[:space:]]*[a-z].*[\(\)\{\};\=]' "$TARGET" 2>/dev/null \
            | grep -v 'MARK:' | grep -v 'TODO:' | grep -v 'FIXME:' \
            | grep -v 'NOTE:' | grep -v 'http' | head -20)
    if [ -n "$cc" ]; then
        echo "$cc"
        flag "Possible commented-out code — remove or convert to TODO/MARK"
    else
        ok "No obvious commented-out code"
    fi

    # 6. Naming consistency — non-camelCase top-level decls
    bold "Naming consistency (non-camelCase top-level let/var/func):"
    nm=$(grep -rEn '^[[:space:]]*(let|var|func) [A-Z_]' "$TARGET" 2>/dev/null \
            | grep -v 'static' | grep -v 'class' | grep -v Tests/ | head -10)
    if [ -n "$nm" ]; then
        echo "$nm"
        flag "Non-camelCase identifier(s) — review naming"
    else
        ok "Naming convention consistent"
    fi
}

# ---------- D2: Architecture & abstraction ----------
audit_architecture() {
    bold "=== D2: Architecture & abstraction ==="

    # 1. Cohesion — measured indirectly via file size; deeper review by agent
    bold "Cohesion (file size signal — files > 500 lines may lack cohesion):"
    big=$(find "$TARGET" -name '*.swift' -exec wc -l {} + 2>/dev/null \
            | awk '$1 > 500 && $2 != "total" {print "  " $1 " lines  " $2}')
    if [ -n "$big" ]; then
        echo "$big"
        flag "Large file(s) — agent should review for cohesion"
    else
        ok "All files under 500 lines (cohesion likely OK; agent verifies)"
    fi

    # 2. Premature abstraction — protocols with ≤1 conformer
    bold "Premature abstraction (protocols with ≤1 conformer):"
    while IFS= read -r line; do
        proto=$(echo "$line" | sed -nE 's/.*protocol +([A-Z][a-zA-Z0-9]+).*/\1/p')
        [ -z "$proto" ] && continue
        # Count conformers: ": Proto" or "extension Proto"
        count=$(grep -rE ":\s*${proto}\b|extension\s+${proto}\b" "$TARGET" 2>/dev/null \
                | grep -v "protocol ${proto}" | wc -l | tr -d ' ')
        if [ "${count:-0}" -le 1 ]; then
            echo "  protocol ${proto} (${count} conformer)"
            FAIL=$((FAIL + 1))
        fi
    done < <(grep -rEh '^[[:space:]]*protocol +[A-Z][a-zA-Z0-9]+' "$TARGET" 2>/dev/null)

    # 3. Missing abstraction — flagged by agent (no clean mechanical check)
    bold "Missing abstraction (agent-only check; mechanical N/A):"
    ok "Deferred to agent dispatch"

    # 4. Module boundaries — Models/Networking should not import higher layers
    bold "Module boundaries (lower layers must not import higher):"
    bad=""
    if grep -rE '^import (DesignSystem|Features)' "$TARGET/Models/" 2>/dev/null; then
        bad="${bad} Models→higher"
    fi
    if grep -rE '^import (DesignSystem|Features)' "$TARGET/Networking/" 2>/dev/null; then
        bad="${bad} Networking→higher"
    fi
    if grep -rE '^import (Features)' "$TARGET/DesignSystem/" 2>/dev/null; then
        bad="${bad} DesignSystem→Features"
    fi
    if [ -n "$bad" ]; then
        flag "Layer-direction violation:$bad"
    else
        ok "Layer dependencies are downward-only"
    fi

    # 5. Dependency direction — cross-feature imports
    bold "Cross-feature imports (Features must not import each other):"
    cf=$(grep -rE '^import' "$TARGET/Features/" 2>/dev/null \
            | grep -v 'import Foundation\|import SwiftUI\|import Combine\|import Kingfisher\|import Observation' || true)
    if [ -n "$cf" ]; then
        echo "$cf"
        # Note: Features importing the app namespace is OK — judgment review
        flag "Non-system imports inside Features/ — agent should verify direction"
    else
        ok "No cross-feature imports"
    fi
}

# ---------- D3: Senior judgment & technical debt ----------
audit_judgment() {
    bold "=== D3: Senior judgment & technical debt ==="

    # 1. Anti-patterns — force unwraps, force casts, fatalError in production
    bold "Anti-patterns (try!, as!, fatalError, force unwraps in production):"
    ap=$(grep -rn 'try!\|as!\|fatalError(' "$TARGET" 2>/dev/null \
            | grep -v Tests/ | grep -v '#Preview\|preview\|.preview')
    if [ -n "$ap" ]; then
        echo "$ap"
        flag "Anti-pattern in production code"
    else
        ok "No production anti-patterns"
    fi

    # 2. Code smells — long parameter lists
    bold "Code smells (functions with > 5 parameters):"
    pl=$(grep -rEn 'func [a-zA-Z]+\([^)]*,[^)]*,[^)]*,[^)]*,[^)]*,[^)]*\)' "$TARGET" 2>/dev/null | head -10)
    if [ -n "$pl" ]; then
        echo "$pl"
        flag "Long parameter list — consider parameter object"
    else
        ok "No functions with > 5 parameters"
    fi

    # 3. Complexity — heuristic via function body length (files broken into funcs)
    bold "Complexity (functions whose body likely exceeds 50 LOC — heuristic):"
    # Match func signature, then check brace span — heuristic
    # Use awk to scan for func openings and following braces
    awk_script='
        /^[[:space:]]*(public |private |internal |fileprivate )?(static )?func / {
            start = NR; name = $0; depth = 0; in_func = 1
        }
        in_func {
            for (i = 1; i <= length($0); i++) {
                c = substr($0, i, 1)
                if (c == "{") depth++
                else if (c == "}") {
                    depth--
                    if (depth == 0) {
                        len = NR - start + 1
                        if (len > 50) printf "  %s:%d  (%d LOC)  %s\n", FILENAME, start, len, name
                        in_func = 0
                        break
                    }
                }
            }
        }
    '
    cx=$(find "$TARGET" -name '*.swift' -exec awk "$awk_script" {} \; 2>/dev/null | head -10)
    if [ -n "$cx" ]; then
        echo "$cx"
        flag "Long function(s) — agent reviews for complexity"
    else
        ok "No functions over 50 LOC"
    fi

    # 4. File / function size
    bold "File size (files > 400 LOC):"
    bf=$(find "$TARGET" -name '*.swift' -exec wc -l {} + 2>/dev/null \
            | awk '$1 > 400 && $2 != "total" {print "  " $1 " " $2}')
    if [ -n "$bf" ]; then
        echo "$bf"
        flag "Large file(s) — split candidates"
    else
        ok "No files over 400 lines"
    fi

    # 5. Hidden state — mutable globals
    bold "Hidden state (static var — mutable global state):"
    hs=$(grep -rn 'static var' "$TARGET" 2>/dev/null | grep -v Tests/)
    if [ -n "$hs" ]; then
        echo "$hs"
        flag "Mutable global state — use DI or @Observable"
    else
        ok "No mutable global state"
    fi

    # 5b. Hidden state — @State in Features that should be in ViewModel (advisory)
    bold "@State in Features (advisory — gesture/focus/animation @State is OK):"
    grep -rn '@State' "$TARGET/Features/" 2>/dev/null | head -20 || true
    echo "  (agent reviews each occurrence: per-frame intermediate is OK; commit-state is NOT)"
}

# ---------- D4: System-as-a-whole ----------
audit_system() {
    bold "=== D4: System-as-a-whole ==="

    # 1. Regression risk — clean build
    bold "Regression risk (xcodegen + xcodebuild):"
    if command -v xcodegen >/dev/null 2>&1; then
        xcodegen generate >/dev/null 2>&1 && ok "xcodegen succeeded" || flag "xcodegen failed"
    else
        flag "xcodegen not installed (brew install xcodegen)"
    fi

    if command -v xcodebuild >/dev/null 2>&1; then
        if xcodebuild -scheme ResortPass \
                -destination 'platform=iOS Simulator,name=iPhone 15' \
                -quiet build >/dev/null 2>&1; then
            ok "xcodebuild succeeded"
        else
            flag "xcodebuild failed — run manually for output"
        fi
    else
        flag "xcodebuild not available"
    fi

    # 2. Cross-criterion consistency (judgment-only — agent dispatch)
    bold "Cross-criterion consistency (judgment-only):"
    ok "Deferred to agent dispatch (Theme usage, namespace pattern, MVI invariants)"

    # 3. Integration smells (judgment-only)
    bold "Integration smells (judgment-only):"
    ok "Deferred to agent dispatch (HotelDetailScene ↔ HotelListingsView coupling)"

    # 4. Holistic flow — Maestro presence
    bold "Holistic flow (Maestro flows registered):"
    mf=$(ls .maestro/*.yaml 2>/dev/null)
    if [ -n "$mf" ]; then
        echo "$mf"
        ok "Maestro flows present — run via 'maestro test .maestro/<flow>.yaml'"
    else
        flag "No Maestro flows found"
    fi
}

case "$DIM" in
    hygiene)      audit_hygiene ;;
    architecture) audit_architecture ;;
    judgment)     audit_judgment ;;
    system)       audit_system ;;
    all)
        audit_hygiene
        audit_architecture
        audit_judgment
        audit_system
        ;;
    *)
        echo "Unknown dimension: $DIM"
        echo "Usage: scripts/audit.sh [hygiene|architecture|judgment|system|all] [target]"
        exit 2
        ;;
esac

echo
if [ "$FAIL" -gt 0 ]; then
    red "Audit: $FAIL mechanical failure(s) — file remediation tasks via TaskCreate"
    exit 1
else
    green "Audit: 0 mechanical failures (judgment dimensions still require agent dispatch)"
    exit 0
fi
