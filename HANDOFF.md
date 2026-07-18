# Handoff — Attention Residue

_Last updated: 2026-07-18_

Working notes for picking this project back up. For usage/build instructions see `AttentionResidue/README.md`; for the original brief see `ATTENTION_RESIDUE_SPEC.md`.

## Where things stand

The macOS app (SwiftUI + AVFoundation + Vision) is functional:

- Video capture from a selectable input device (built-in webcam, or USB capture such as the Legato adapter feeding the Panasonic CCTV camera).
- Face detection + bounding-box overlay via Vision (`VNDetectFaceLandmarksRequest`).
- Gaze / "looking down" analysis from head pitch.
- Attention ratio (0–100%) with exponential smoothing.
- **MIDI output** (virtual source "Attention Residue") for driving external video/audio synthesis.
- App icon (green square outline on dark background).

Branch: `claude/plan-mac-art-app-0162iomaZJqZpp2XHJxq7SHk`
Remote: GitHub — `networkarchitecturelab/attention-residue`.

## MIDI output — current implementation

File: `AttentionResidue/AttentionResidue/MIDI/MIDIOutput.swift`

- Creates a CoreMIDI **virtual source** named **"Attention Residue"**.
- Sends on **MIDI channel 1**, throttled to ~30 Hz:
  - **CC 1** — attention ratio, mapped 0–127
  - **CC 2** — face count (0–127)
  - **CC 3** — number of faces looking down (0–127)
- Toggle + live CC1 value shown in the toolbar (`ContentView.swift`).
- Driven from `DetectionState.updateDetection(...)` using the smoothed ratio.

## OPEN THREAD — wire MIDI out to the video synth ("rasterlab")

This is the next thing to do and where we stopped.

Goal: map the app's MIDI output to the video synth we're building (referred to as **"rasterlab"** — name unconfirmed).

Blockers / what's needed before implementing:

1. **Repo access.** Could not pull `rasterlab` into the session:
   - The MCP "add repo" tool was unavailable that turn.
   - The git proxy only serves repos provisioned to the session; `rasterlab` was rejected.
   - Owner/name unconfirmed (guessed `networkarchitecturelab/rasterlab`).
   - **Action:** add the repo to the Claude Code session (repo picker), or confirm exact `owner/repo`.

2. **Control surface.** Regardless of repo access, we need rasterlab's input map:
   - MIDI CC? → which channel + which CC numbers map to which parameters.
   - OSC? → address pattern + port.
   - Other (Syphon/NDI/config file)?

Once the CC→parameter map (or OSC scheme) is known, align `MIDIOutput.swift` to it. If rasterlab already speaks MIDI CC on channel 1, we may only need to renumber CCs / rescale ranges.

Also relevant: the spec mentions connection to an **LZX** hardware video synth (line 27). If that's the target instead of/alongside rasterlab, MIDI reaches it via a MIDI→CV interface — need to know which one to shape CC ranges.

## OPEN THREAD — refine gaze detection

File: `AttentionResidue/AttentionResidue/Detection/FaceDetector.swift`

Current logic (commit `ede75c0`): flags "looking down" when head pitch deviates from a **neutral of 3°** by more than **8°** in *either* direction (Vision's pitch sign flips depending on head posture — chin-down reads positive, head-tilted-back-eyes-down reads negative).

Tunables: `neutralPitch` (3.0), `pitchDeviationThreshold` (8.0). Needs on-device testing (⌘R) to confirm thresholds; adjust based on observed false positives/negatives. Note Vision stops detecting faces once the head tilts far enough that features are occluded.

## Housekeeping

- README is slightly stale — does not yet mention the MIDI feature or the app icon. Update when convenient.

## Build / run

```bash
git pull origin claude/plan-mac-art-app-0162iomaZJqZpp2XHJxq7SHk
open AttentionResidue/AttentionResidue.xcodeproj   # then ⌘R
```
