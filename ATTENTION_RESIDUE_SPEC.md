# Attention Residue - Mac Application

## Project Overview

A macOS application that analyzes video input for phone usage and downward gaze. This is **v0.1** - display and analysis only. CV output will be added later.

**Artist:** Kazys Varnelis  
**Context:** This is part of a video art installation exploring device addiction and attention. The piece is self-undermining: people photographing the work for Instagram cause the video to degrade.

## Conceptual Background

This project extends the artist's previous work "Perkūnas" (2016), which used WiFi client sniffing to generate control voltage for sound synthesis. Where Perkūnas made the invisible electromagnetic environment audible, Attention Residue makes phone-attention visible through video degradation.

The work should feel responsive but not precisely legible—viewers should sense the system is reacting to something without immediately understanding the exact mechanism.

## Hardware Setup

### Video Input
- **Camera:** Panasonic WV-BL200 CCTV (monochrome, composite video out, BNC connector)
- **Capture:** Legato USB composite capture adapter
- **Alternative:** Built-in webcam or any other video input device

The app should allow selection of any available video input device.

### Future (not v0.1)
- CV output via audio interface
- Connection to LZX video synthesis system

## v0.1 Scope

This version focuses on:
1. Video capture from selectable input device
2. Display video on screen
3. Run detection analysis
4. Display analysis results (face count, gaze detection, attention ratio)

**Not in v0.1:** Audio/CV output, menu bar mode, recording, preferences persistence.

## Functional Requirements

### Core Detection
1. **Capture video** from selected input device (webcam, capture card, etc.)
2. **Detect faces** in frame and count them
3. **Analyze gaze direction** - detect when heads are tilted downward (phone-looking posture)
4. **Detect phones** in frame (optional, adds accuracy but costs performance)
5. **Calculate attention ratio:** (people looking at phones) / (total people)
6. **Smooth the ratio** over ~1 second to avoid jitter

### User Interface (v0.1)
- **Single window** showing:
  - Dropdown to select video input device
  - Live video preview with detection overlay
  - Current stats displayed:
    - Number of faces detected
    - Number looking down
    - Number of phones detected (if using phone detection)
    - Attention ratio (0.0 - 1.0)
  - Simple bar graph showing attention ratio
- **Toggle** to show/hide detection overlay (bounding boxes, etc.)

### Performance
- Target 15-30 fps analysis on M1/M2 Mac
- Should not spin fans excessively during normal operation
- Graceful degradation if system is under load

## Technical Approach

### Recommended Stack
- **Swift** with SwiftUI for the app
- **AVFoundation** for video capture
- **Vision framework** for face detection and head pose estimation (Apple's built-in ML)
- **Core ML** with a YOLO model for phone detection (optional, can add later)

### Why Vision Framework
Apple's Vision framework includes:
- `VNDetectFaceRectanglesRequest` - fast face detection
- `VNDetectFaceLandmarksRequest` - facial landmarks for pose estimation
- Built-in, optimized for Apple Silicon, no external dependencies

This avoids needing MediaPipe or other external ML frameworks, keeping the app lightweight and native.

### Detection Logic

```
For each frame:
  1. Detect faces using Vision
  2. For each face:
     a. Get facial landmarks
     b. Estimate head pitch from landmark geometry
     c. If pitch indicates looking down → increment phone_attention_count
  3. (Future: run YOLO to detect phone objects)
  4. Calculate ratio = phone_attention_count / face_count
  5. Apply exponential smoothing
  6. Display ratio and update UI
```

### Head Pitch Estimation
Using facial landmarks (nose, eyes, mouth corners), estimate head tilt:
- When looking down, the nose-to-chin distance appears compressed
- The nose position moves up relative to face center
- Eye positions shift relative to face bounding box

Threshold for "looking down" should be adjustable—default around 15-20 degrees below horizontal.

### Video Input Selection
Use `AVCaptureDevice.DiscoverySession` to enumerate available video devices:
- Built-in webcam
- USB capture devices (like the Legato adapter)
- Any other connected cameras

Display device names in a dropdown, let user select, and switch capture source accordingly.

## File Structure (v0.1 - simplified)

```
AttentionResidue/
├── AttentionResidue.xcodeproj
├── AttentionResidue/
│   ├── AttentionResidueApp.swift      # App entry point
│   ├── ContentView.swift              # Main UI
│   ├── VideoCapture.swift             # AVFoundation video capture
│   ├── FaceDetector.swift             # Vision framework detection
│   ├── DetectionState.swift           # Data model
│   └── Info.plist
└── README.md
```

## Privacy & Permissions

The app needs:
- **Camera access** - for video input

Add appropriate `NSCameraUsageDescription` to Info.plist:
```
"This app uses the camera to analyze attention patterns in the video feed."
```

## Future Versions

**v0.2:**
- Audio CV output
- Sensitivity/threshold controls

**v0.3:**
- Phone detection via YOLO
- Settings persistence
- Menu bar mode

**v0.4:**
- Raspberry Pi port (separate project)

## Testing

1. Test with built-in webcam first
2. Test with Legato USB adapter + Panasonic camera
3. Verify detection works with black and white input
4. Test with 1, 2, 5+ people in frame
5. Check performance (should be smooth, not spinning fans)

## References

- Kazys Varnelis, "Perkūnas" (2016) - WiFi sniffing → CV for sound
- Kazys Varnelis, "Detachment" exhibition (2016) - broader context
- Apple Vision documentation: https://developer.apple.com/documentation/vision
- Apple AVFoundation: https://developer.apple.com/documentation/avfoundation

## Notes for Implementation

The key insight from Perkūnas was that people refused to turn off their WiFi even when told the piece would respond. This piece should have a similar quality—the mechanism should be discoverable but not obvious.

The black and white security camera aesthetic is intentional—it distances the work from the slick iPhone imagery that's part of what the piece critiques, and creates a surveillance-of-surveillance loop.
