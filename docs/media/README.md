# Recorded demos

| File | What it shows | How |
|---|---|---|
| `hero-flow.gif` | Search → type "newport" → loaded → tap → hotels | 7-frame Maestro screenshot sequence, light appearance, stitched at 1.25 fps with `ffmpeg` |
| `hero-flow-dark.gif` | Same flow in dark appearance | Same approach with `xcrun simctl ui booted appearance dark` set beforehand |

## Re-recording locally

Each GIF is regenerated from a Maestro flow + `ffmpeg` stitch. From the repo root:

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"

# Light variant
xcrun simctl ui booted appearance light
maestro test .maestro/recordings/capture-sequence.yaml
ffmpeg -y -framerate 1.25 -pattern_type glob -i 'seq-*.png' \
  -vf "fps=10,scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" \
  -loop 0 docs/media/hero-flow.gif
rm seq-*.png

# Dark variant
xcrun simctl ui booted appearance dark
maestro test .maestro/recordings/capture-sequence.yaml
ffmpeg ...                                       # same command, different output filename
xcrun simctl ui booted appearance light
```

## What's not here yet

- **`morph-spring.gif`** — the matched-transition zoom from card → detail. Capturing this faithfully needs frame-by-frame video, not screenshot stitches.
- **`drag-throw-dismiss.gif`** — same problem: the rubber-band + snap-back spring runs at 120 Hz on ProMotion; stills can't represent it.

`xcrun simctl io booted recordVideo` returns `SimRenderServer.SimulatorError code=2` on this Xcode 26 / iOS 26 toolchain (known regression in the new sim render pipeline). Workarounds for a follow-up pass:

1. **QuickTime Player → File → New Screen Recording**, manual region select over the Simulator window. Reliable; not scriptable.
2. **macOS `screencapture`** — the `-V` video flag exists in newer macOS releases but isn't in 26.x.
3. **`ffmpeg -f avfoundation -i "1"`** — works if the parent terminal has Screen Recording permission granted; this machine doesn't have that set up.

Run the Maestro flows themselves (`maestro test .maestro/`) on a local sim for the full motion.
