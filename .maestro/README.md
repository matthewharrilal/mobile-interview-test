# .maestro/

Maestro flow YAMLs for the ResortPass iOS app.

## Maestro version

This project uses **Maestro 0.15.x**. Some quirks in this README are specific to that minor version (most notably the `launchApp.arguments` shape — see below). Before debugging an authoring issue, double-check `maestro --version` matches.

## Running flows

The repo ships a wrapper at `team-audit/artifacts/maestro` that pre-sets `JAVA_HOME` (Maestro's JVM dependency) and forwards all arguments to the real CLI. Prefer it over the bare `maestro` binary:

```bash
team-audit/artifacts/maestro test .maestro/01-happy-path.yaml
```

Special cases:

- **Failure-flag flows** (anything that toggles `-FailHotels`, `-FailSearch`, `-EmptyHotels`, etc.) — drive them through the batch runner so the relaunch + flag wiring is consistent:
  ```bash
  bash scripts/run-failure-flows.sh
  ```
- **NLC (Network Link Conditioner) flows** — flows 65–67 require a configured network profile on the host before the run. See `team-audit/artifacts/NLC-RUNBOOK.md` for the exact profile names and setup steps.

## Authoring conventions

### `launchApp.arguments` MUST be a YAML map, not a sequence

Maestro 0.15 parses `arguments:` as a map of `"-Key": "Value"` pairs. The sequence form (`["-Key", "Value"]` or a YAML list of strings) silently fails `check-syntax` with:

> The format for arguments is incorrect

**Wrong** — fails check-syntax:

```yaml
- launchApp:
    appId: com.resortpass.app
    arguments: ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
```

```yaml
- launchApp:
    appId: com.resortpass.app
    arguments:
      - "-AppleLanguages"
      - "(de)"
```

**Correct** — passes:

```yaml
- launchApp:
    appId: com.resortpass.app
    arguments:
      "-AppleLanguages": "(de)"
      "-AppleLocale": "de_DE"
      "-FailHotels": "1"
```

This affects every flow that wires `AppleLanguages`, `AppleLocale`, content-size-category, or any custom failure flag.

### Default device

Flows assume the simulator is **iPhone 17 Pro**. Coordinate-tap calibration in `80-coordinate-tap-regression.yaml` and any other coord-based gestures are tuned to that device's screen geometry. If a flow targets a different device (e.g. the iPad flows `78-79`), document the device explicitly at the top of that flow.

### Async waits

Prefer `extendedWaitUntil` over `waitForAnimationToEnd` when waiting on async API responses. `waitForAnimationToEnd` is for animation settle; using it as a network wait produces flaky timing because the animation completes before the data arrives.

```yaml
- extendedWaitUntil:
    visible: "Casa Madrona Hotel & Spa"
    timeout: 10000
```

### Screenshots

`takeScreenshot` writes to the **current working directory** unless an explicit path is provided. The runner (`team-audit/artifacts/maestro` and the batch scripts) moves any screenshots produced during a run into `team-audit/screenshots/`. If you invoke Maestro directly from another cwd, expect screenshots to land there — move them by hand or use the wrapper.

## Flow numbering

| Range  | Purpose                                                |
|--------|--------------------------------------------------------|
| 01–12  | Existing baseline flows (happy path, search, retry, hero, comprehensive audit) |
| 13–21  | Animation-midpoint / transition coverage               |
| 22–27  | Filter coverage (spa, adults, pets, wellness, empty result, reset) |
| 28–29  | Retry-failure flows                                    |
| 30–31  | Loading-state / skeleton                               |
| 32–41  | Dark mode                                              |
| 42–46  | Dynamic Type                                           |
| 47–53  | Landscape orientation                                  |
| 54–56  | Locale (de-DE)                                         |
| 57–61  | Pokédex / orphan-code reachability                     |
| 62–64  | Pull-to-refresh / rapid input                          |
| 65–67  | Network conditions (NLC required — see runbook)        |
| 68–77  | Accessibility (VoiceOver, Reduce Motion, Bold Text, AX5) — P2, deprioritized per audit-lead |
| 78–79  | iPad                                                   |
| 80     | Coordinate-tap regression                              |

When adding a new flow, slot it into the matching range and use the next available number; don't renumber existing flows.
