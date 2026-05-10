# NLC Runbook — Manual Setup for Maestro Flows 65, 66, 67

Network Link Conditioner (NLC) cannot be driven by Maestro 0.15. Flows 65–67
require an operator to pre-configure NLC on the host Mac before running the
flow, and to restore network state after. This runbook documents the procedure.

Related: F-021 (network-conditioner flows cannot be Maestro-controlled),
T-019 (this runbook).

---

## 1. Prerequisites

NLC ships as a System Preference pane inside Apple's "Additional Tools for
Xcode" download. Install once per workstation.

1. Open Xcode → **Settings** → **Components** and locate
   **Additional Tools for Xcode** (Xcode 15+), or download manually from
   <https://developer.apple.com/download/all/?q=Additional%20Tools>.
2. Mount the resulting `.dmg` and double-click
   **Hardware/Network Link Conditioner.prefPane** to install.
3. Verify install path:
   `/System/Library/PreferencePanes/Network Link Conditioner.prefPane`
   (older macOS) or
   `/Library/PreferencePanes/Network Link Conditioner.prefPane` (current).
4. NLC affects **all network traffic on the host Mac**, including the iOS
   Simulator (which uses the host network stack). No simulator-side flag is
   required.

## 2. Enabling NLC

1. Open **System Settings** (macOS 13+) or **System Preferences** (macOS 12-).
2. Scroll to the bottom of the sidebar — **Network Link Conditioner** appears
   under third-party panes.
3. Click it; the pane shows a master toggle (**ON / OFF**) and a profile
   dropdown.
4. To activate: pick a profile from the dropdown, then flip the toggle to
   **ON**. The status indicator turns green.

## 3. Profiles Used by This Audit

| Audit need     | Built-in profile | Custom equivalent                       |
| -------------- | ---------------- | --------------------------------------- |
| Offline        | **100% Loss**    | 100% packet loss, in + out              |
| Slow 3G        | **3G**           | 1 Mbps down, 256 kbps up, 200 ms delay  |
| High latency   | **High Latency DNS** or **Edge** | n/a                     |

If a built-in profile is missing, click **Manage Profiles…** → **+** and enter
the values from the right column. Save with the profile name above so the
flow-specific instructions below match.

## 4. Per-Flow Setup

### Flow 65 — `65-offline-search.yaml` (offline before run)

1. Open NLC pane, select **100% Loss**, toggle **ON**.
2. Run `maestro test .maestro/65-offline-search.yaml`.
3. After the flow completes, toggle NLC **OFF** (see §5).

### Flow 66 — `66-offline-hotels.yaml` (online → offline mid-flow)

This flow requires a network state change **between two Maestro steps**. The
flow itself loads search results online, screenshots `66-offline-hotels-pre-tap`,
then taps the result expecting a network failure.

1. Start with NLC **OFF** (or pane closed).
2. Run `maestro test .maestro/66-offline-hotels.yaml`.
3. **Watch the simulator.** As soon as "Newport Beach, California" appears in
   the search list (the step right before `takeScreenshot: 66-offline-hotels-pre-tap`),
   open the NLC pane and toggle **100% Loss** **ON**.
4. Maestro will then tap the row; the offline failure should render.
5. Restore NLC **OFF** (see §5).

> **Caveat — timing is hard.** The window between "list visible" and "tap
> issued" is roughly 1–2 seconds. If you toggle too early, the search list
> never loads; if too late, the hotels list loads online and the flow fails its
> "Couldn't load hotels" assertion. If you miss the window, abort the run, set
> NLC **OFF**, and retry from step 1. A future enhancement (out of scope for
> T-019) would be a runner-level pause hook between the screenshot and the
> tap; for now, manual operator timing is required.

### Flow 67 — `67-slow-3G-image-loading.yaml` (slow throughput before run)

1. Open NLC pane, select **3G**, toggle **ON**.
2. Run `maestro test .maestro/67-slow-3G-image-loading.yaml`.
3. The flow takes longer than usual — placeholder→image fades are the point.
4. Restore NLC **OFF** (see §5).

## 5. Restoring Normal Network

1. Open the NLC pane.
2. Toggle the master switch to **OFF**. The indicator returns to gray.
3. (Optional) Quit System Settings to avoid leaving the pane visible.

If you forget step 2, **all subsequent network activity on the Mac stays
degraded** until reboot or manual toggle. Always confirm the indicator is gray
before moving on to other flows.

---

## Quick Reference

```
Flow 65  →  NLC: 100% Loss ON   →  run  →  OFF
Flow 66  →  NLC: OFF             →  run, toggle 100% Loss ON mid-flow  →  OFF
Flow 67  →  NLC: 3G ON           →  run  →  OFF
```
