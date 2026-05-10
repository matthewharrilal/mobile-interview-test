# T-020 — Spike: Xcode UITest path for sub-frame screenshot precision

**Branch:** `fix/T-020-uitest-spike` (from `audit/baseline @ d20159c`)
**Related:** F-022 (Maestro 0.15 cannot guarantee mid-frame screenshot timing precision); flows 13–21 (combo-matrix §5.1).
**Scope:** Research-only. No source changes. Decision document per T-020 acceptance criterion #2.

---

## 1. What XCUIScreen / XCTest can do that Maestro 0.15 cannot

Maestro is a black-box automation tool that drives the simulator over WDA / `xcrun simctl io` and shells out to `screenshot` once per `takeScreenshot` step. The shortest reliably-spaced screenshot interval is bounded by `wait` granularity, which in 0.15 drifts well above the 60 Hz frame budget (16.67 ms) — empirically often 80–150 ms of jitter. Frames are not synchronized with the app's display link.

`XCUIScreen.takeScreenshot()` (and `XCUIElement.screenshot()`) gives the test process direct access to the same render server hooks Xcode uses for screen recording. Concretely:

| Capability | Maestro 0.15 | XCUITest |
|---|---|---|
| Screenshot at "exactly +50 ms after this tap" | No — `wait 50; screenshot` jitters 50–150 ms | Yes — `XCTWaiter` + `Thread.sleep(forTimeInterval:)` inside the test process is sub-frame; `XCUIScreen.main.screenshot()` is synchronous and returns the most recent committed frame. |
| 5 frames at 50 ms cadence (flow 14) | No — accumulating `wait` drift means by frame 5 you may be at +280 ms instead of +200 ms | Yes — a tight `for` loop with `usleep(50_000)` between `screenshot()` calls is bounded by the shutter time (~5 ms), so total drift is single-digit ms. |
| Per-element accessibility queries (`app.buttons["Try Again"].exists`) | Approximate — `assertVisible: "Try Again"` matches by text scrape | Exact — full `XCUIElementQuery` tree, `.frame`, `.value`, `.isHittable`, `.exists` per element. |
| `XCUIElementSnapshot` (frozen accessibility tree) | No | Yes — atomic snapshot of the entire app's a11y tree at one instant; lets you diff state between frames. |
| Full `XCTestCase` access (XCTAttachment, XCTContext.runActivity, XCTMetric for perf) | No | Yes — attachments embed PNGs into the .xcresult bundle for Xcode-side review. |
| Programmatic launch arguments per case | Yes via `launchApp.arguments` | Yes via `XCUIApplication().launchArguments` — and you can re-launch mid-test, which Maestro cannot. |
| Mid-test simulator state mutation (orientation, appearance, NLC) | Via `runScript: xcrun simctl …` | Native APIs (`XCUIDevice.shared.orientation`) without shelling out. |

For flows 13–21 the load-bearing capability is **deterministic frame timing**. Maestro can't provide it; XCUITest can.

---

## 2. Cost of adding a UITest target to ResortPass

The project today has two PBXNativeTargets in `ResortPass.xcodeproj/project.pbxproj`:

- `ResortPass` (`com.apple.product-type.application`)
- `ResortPassTests` (`com.apple.product-type.bundle.unit-test`, `TEST_HOST = $(BUILT_PRODUCTS_DIR)/ResortPass.app/...`)

There is **no UI-test bundle** (`com.apple.product-type.bundle.ui-testing`). Adding one means:

**One-time cost (target setup):**
- New `ResortPassUITests` target in `ResortPass.xcodeproj` (or in `project.yml` if XcodeGen is canonical — `project.yml` is present, so the change is one block in YAML, not a manual pbxproj edit).
- Build settings: `TEST_TARGET_NAME = ResortPass`, `TARGETED_DEVICE_FAMILY = 1,2`, `BUNDLE_LOADER` not set (UI tests don't link the host).
- A new scheme entry to make the bundle runnable from `xcodebuild test -only-testing:ResortPassUITests/...`.
- Estimate: 30–60 minutes of plumbing.

**Per-flow cost (test code):**
Each Maestro flow becomes an `XCTestCase` method. A Maestro flow today is ~10–20 lines of declarative YAML; the equivalent UITest is ~40–80 lines of Swift:

```
class MorphPrecisionTests: XCTestCase {
  var app: XCUIApplication!
  override func setUp() { continueAfterFailure = false; app = XCUIApplication(); app.launch() }

  func test_14_cardDetailMorphSpringEnvelope() throws {
    app.searchFields.firstMatch.tap()
    app.searchFields.firstMatch.typeText("newport")
    app.staticTexts["Newport Beach, California"].tap()
    XCTAssertTrue(app.staticTexts["Top picks"].waitForExistence(timeout: 5))
    let card = app.collectionViews.cells.element(boundBy: 0)
    card.tap()
    for (i, _) in (0..<5).enumerated() {
      let shot = XCUIScreen.main.screenshot()
      add(XCTAttachment(screenshot: shot, name: "14-morph-frame-\(i*50)ms"))
      Thread.sleep(forTimeInterval: 0.050)
    }
  }
}
```

That's ~3–5x the line count of the YAML, plus the engineer must recognize SwiftUI accessibility identifier mismatches (e.g. `app.collectionViews.cells` vs the actual scrollview hierarchy) — a category of bug that doesn't exist in Maestro's text-scrape model.

**CI cost:**
The project already has a `Makefile` and `scripts/` with `audit.sh` / `run-failure-flows.sh`. CI (whatever drives those scripts) presumably has Xcode + a simulator available. Adding `xcodebuild test -scheme ResortPass -only-testing:ResortPassUITests` is one new line in CI config. Cold-start cost on CI is +60–90 s (UI test bundle install + first launch) over the existing Maestro run.

**Maintenance cost:**
- Maestro flows are platform-agnostic YAML — anyone can author/modify them.
- UITests are Swift-only, must compile, must track Sources/ refactors (e.g. if `Strings.Search.navTitle` changes, both have to be updated; but UITest also breaks if a SwiftUI view's accessibility identifier or hierarchy shifts).
- Empirically: **~3–5x more code to write and maintain per flow, plus a Swift refactor blast-radius that YAML doesn't have.**

---

## 3. Which flows would benefit (combo-matrix §5.1)

Per F-022 and §5.1, the morph-precision flows are 13–21:

| Flow | Title | Why sub-frame matters |
|---|---|---|
| 13 | `transitions-audit` | Six screenshots at +0/+75/+150/+250 ms relative to a tap; F-022 names this directly. |
| 14 | `card-detail-morph-spring-envelope` | 5 frames at exactly 50 ms intervals — captures `spring(0.25, 0.95)` envelope. **Single most precision-sensitive flow.** |
| 15 | `swipe-down-dismiss-rubber-band` | Mid-rubber-band screenshot under the 100pt commit threshold. |
| 16 | `swipe-down-dismiss-commit-200pt` | "screenshot every 100ms during throw" — drift makes the 4 frames non-comparable across runs. |
| 17 | `search-pill-blur-crossfade` | +0/+100/+200 ms within a 200 ms `easeInOut` window — Maestro jitter is the same magnitude as the entire animation. |
| 18 | `peek-carousel-mid-snap` | +100/+250/+500 ms — slightly more forgiving (500 ms total) but still benefits. |
| 19 | `filter-chip-mid-transition` | +0/+125/+250 ms in a 250 ms `snappy(0.25)` window — marginal precision case. |
| 20 | `hero-stretch-pulldown` | +100/+250/+500 ms — peak-stretch frame drifts under jitter. |
| 21 | `content-fade-in-detail` | +160/+200/+410 ms anchored on the `Task.sleep(160ms)` in `HotelDetailScene.swift:60` — needs absolute timing. |

That's **9 flows out of 68** (13% of the suite). Everything else (filters, dark mode, dynamic type, landscape, locale, retry, network, a11y, iPad) is text-scrape / static-screenshot work where Maestro's tradeoffs are correct.

---

## 4. Recommendation

**Option B — add a UITest target ONLY for flows 13–21; keep everything else in Maestro.**

Rationale:

- **Precision is load-bearing for exactly these 9 flows and nothing else.** F-022 names them; combo-matrix §5.1 segregates them; their entire purpose is animation-envelope verification. The other 59 flows are state-assertion screenshots where Maestro's text scrape and ±100 ms tolerance are fine.
- **Option A (status quo)** lets F-022 stand: morph flows produce non-reproducible screenshots, and visual regression on `spring(0.25, 0.95)` becomes "trust the eyeball." That's an acceptable answer for a side project but not for a product that's audit-tracking 22 findings against animation polish — the whole point of T-009 (extract `Theme.Animation.morphSpring`) and T-002 (wire `dismissProgress`) is to make these animations regression-proof. Without sub-frame screenshots, those tasks have no ratchet.
- **Option C (full migration)** pays a 3–5x maintenance tax across 68 flows to solve a problem that exists on 9. Bad ROI. Maestro's declarative model is genuinely better for the 59 non-precision flows.
- **Option B** confines the Swift-tax to the flows that need it. The two harnesses run side-by-side — Maestro for the breadth, XCUITest for the depth. CI invokes both; the .xcresult bundle holds the morph attachments alongside the Maestro screenshot dirs.

Risk: a small ongoing duplication where some flows could in principle be expressed in either harness. Mitigation: a one-line rule in `.maestro/README.md` and `Tests/UI/README.md` — "if your flow asserts a specific frame at a specific ms offset, it belongs in XCUITest; everything else belongs in Maestro."

---

## 5. Option B — implementation plan

**Files to add:**

```
Tests/UI/ResortPassUITests/
  ResortPassUITests.swift              # base XCTestCase, helpers (navigate to S8, navigate to S12)
  MorphPrecisionTests.swift            # tests 13–21, one func per flow
  TestHelpers/
    XCTestCase+Screenshot.swift        # frame-cadence helper: captureFrames(count:intervalMs:prefix:)
    XCUIApplication+Navigation.swift   # navigateToHotelsLoaded(), navigateToDetailExpanded()
  README.md                            # "this bundle exists for sub-frame timing only; everything else lives in .maestro/"
```

**`project.yml` change (single block):**

```yaml
targets:
  ResortPassUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [Tests/UI/ResortPassUITests]
    dependencies:
      - target: ResortPass
    settings:
      base:
        TEST_TARGET_NAME: ResortPass
        TARGETED_DEVICE_FAMILY: "1,2"
```

Run `xcodegen generate` to regenerate `ResortPass.xcodeproj/project.pbxproj`.

**Scheme:** add `ResortPassUITests` to the existing `ResortPass` scheme's Test action so `xcodebuild test -scheme ResortPass` runs both unit tests and UI tests.

**CI integration:** in whatever script wraps `xcodebuild` today (the project has `Makefile` + `scripts/audit.sh`; CI specifics not visible from this worktree — the Maestro side is invoked from `scripts/run-failure-flows.sh`), add:

```bash
xcodebuild test \
  -scheme ResortPass \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -only-testing:ResortPassUITests/MorphPrecisionTests \
  -resultBundlePath team-audit/results/uitest.xcresult
```

Then extract attachments from the `.xcresult` into `team-audit/screenshots/uitest/` so the existing review pipeline (combo-matrix §5.1 expects `13-morph-t0.png`, `14-morph-frame-0.png`, etc.) still finds them at predictable paths.

**Migration order (one PR per flow, smallest first):**
1. Spike on flow 14 (`card-detail-morph-spring-envelope`) — exactly the spike T-020 acceptance criterion #1 names. Validates target + helper plumbing.
2. Once 14 is green, port 13 (transitions-audit) — same NAV path, more frames.
3. Then 17, 19, 21 (single-tap, fixed-window animations — easy ports).
4. Then 15, 16, 18, 20 (gesture-driven — needs `XCUIElement.swipeDown(velocity:)` calibration and might surface its own jitter; tackle last).

**Acceptance per flow:** screenshot timestamps in the .xcresult attachment metadata are within ±5 ms of target, across 3 consecutive runs. This is the regression-ratchet that justifies the whole exercise.

**Follow-up tasks to file:**
- T-020-followup-A: implement spike on flow 14 (exits this spike).
- T-020-followup-B: port flows 13, 17, 19, 21 (fixed-window batch).
- T-020-followup-C: port flows 15, 16, 18, 20 (gesture-driven batch).
- T-020-followup-D: delete the corresponding `.maestro/13-21*.yaml` flows once the UITest equivalents are green for two consecutive audit cycles, OR keep both as belt-and-braces (decide at follow-up-C close).

---

*End of T-020 spike.*
