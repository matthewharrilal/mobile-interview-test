# Recorded demos

This directory is reserved for slow-motion animated GIFs of the signature interactions:

- `hero-morph.gif` — search → tap card → morph to detail
- `drag-throw-dismiss.gif` — pull-down rubber-band → snap back
- `dark-mode-hotels.gif` — appearance transition

## Why these aren't here yet

`xcrun simctl io booted recordVideo` returns `SimRenderServer.SimulatorError code=2` against this Xcode 26 / iOS 26 toolchain, even with the iOS 18 simulator booted and the Simulator app in the foreground. This is a known regression in the new sim render pipeline.

Workarounds for a follow-up pass:
1. **QuickTime Player → File → New Screen Recording**, manual region select over the Simulator window. Reliable; not scriptable.
2. **`screencapture -V <seconds> -t mov`** — requires Screen Recording permission for the parent terminal/IDE, which isn't granted on this machine.
3. **Maestro `takeScreenshot:` series at tight intervals + `ffmpeg`** to stitch into a GIF. Approximates animation at ~5–10 fps; legible for state transitions but not for the morph spring.

For now, the static light/dark gallery in [`/snapshots/`](../../snapshots/) and the Maestro flows themselves (run locally for the full motion) carry the visual story.
