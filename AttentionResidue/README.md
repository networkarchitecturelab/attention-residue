# Attention Residue

A macOS application for Kazys Varnelis's video art installation exploring device addiction and attention.

## Overview

This app analyzes video input for phone usage and downward gaze, calculating an "attention ratio" that measures how many people in frame are looking at their phones versus engaging with the artwork.

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Camera access (built-in webcam or USB capture device)

## Building

1. Open `AttentionResidue.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run (⌘R)

## Usage

1. Launch the app
2. Grant camera permission when prompted
3. Select your video input device from the dropdown:
   - Built-in webcam (for testing)
   - USB capture device (Legato adapter for CCTV camera)
4. The app will display:
   - Live video preview with optional detection overlay
   - Face count
   - Number of faces looking down (phone posture)
   - Smoothed attention ratio (0-100%)

## Controls

- **Camera dropdown**: Select video input device
- **Show Overlay**: Toggle bounding boxes on detected faces

## Technical Details

### Detection Pipeline

1. Video captured via AVFoundation
2. Frames processed using Apple's Vision framework
3. Face detection with `VNDetectFaceLandmarksRequest`
4. Head pitch estimated from facial landmarks
5. Attention ratio calculated and smoothed over ~1 second

### File Structure

```
AttentionResidue/
├── AttentionResidueApp.swift      # App entry point
├── ContentView.swift              # Main UI
├── Models/
│   └── DetectionState.swift       # Observable state
├── Views/
│   ├── VideoPreviewView.swift     # Video preview layer
│   └── StatsOverlayView.swift     # Statistics display
├── Capture/
│   └── VideoCapture.swift         # AVFoundation capture
└── Detection/
    └── FaceDetector.swift         # Vision framework detection
```

## Version History

### v0.1.0 (Current)
- Video capture from selectable input device
- Face detection and count
- Gaze direction analysis (looking down detection)
- Attention ratio calculation with smoothing
- Live preview with detection overlay

### Future (v0.2+)
- Audio CV output for video synthesis control
- Phone detection via YOLO model
- Sensitivity/threshold controls
- Settings persistence

## Artist

Kazys Varnelis

## Context

This work extends "Perkūnas" (2016), which used WiFi client sniffing to generate control voltage for sound synthesis. Where Perkūnas made the invisible electromagnetic environment audible, Attention Residue makes phone-attention visible through video degradation.

The work should feel responsive but not precisely legible—viewers should sense the system is reacting to something without immediately understanding the exact mechanism.
