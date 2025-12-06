//
//  DetectionState.swift
//  AttentionResidue
//
//  Observable state model for detection results
//

import Foundation
import SwiftUI
import Vision

/// Represents a single detected face with its analysis
struct DetectedFace: Identifiable {
    let id = UUID()
    let boundingBox: CGRect  // Normalized coordinates (0-1)
    let isLookingDown: Bool
    let pitchAngle: Double?  // Estimated head pitch in degrees
}

/// Main observable state for the detection system
@MainActor
class DetectionState: ObservableObject {
    // MARK: - Detection Results

    /// Currently detected faces
    @Published var detectedFaces: [DetectedFace] = []

    /// Number of faces detected in current frame
    @Published var faceCount: Int = 0

    /// Number of faces looking downward (phone posture)
    @Published var lookingDownCount: Int = 0

    /// Raw attention ratio (0.0 = all looking down, 1.0 = all engaged)
    @Published var rawAttentionRatio: Double = 1.0

    /// Smoothed attention ratio for stable display
    @Published var smoothedAttentionRatio: Double = 1.0

    // MARK: - Device Selection

    /// Available video input devices
    @Published var availableDevices: [VideoDevice] = []

    /// Currently selected device ID
    @Published var selectedDeviceID: String? = nil

    // MARK: - UI State

    /// Whether to show detection overlay on video
    @Published var showOverlay: Bool = true

    /// Whether the capture session is running
    @Published var isCapturing: Bool = false

    /// Error message if something goes wrong
    @Published var errorMessage: String? = nil

    // MARK: - MIDI Output

    /// MIDI output manager for sending attention data to external apps
    let midiOutput = MIDIOutput()

    // MARK: - Smoothing Configuration

    /// Smoothing factor for attention ratio (0-1, higher = more smoothing)
    private let smoothingFactor: Double = 0.8

    // MARK: - Methods

    /// Update detection results from a new frame
    func updateDetection(faces: [DetectedFace]) {
        self.detectedFaces = faces
        self.faceCount = faces.count

        let downCount = faces.filter { $0.isLookingDown }.count
        self.lookingDownCount = downCount

        // Calculate raw ratio (inverted: 1.0 = all engaged, 0.0 = all looking down)
        if faceCount > 0 {
            let engagedCount = faceCount - downCount
            self.rawAttentionRatio = Double(engagedCount) / Double(faceCount)
        } else {
            self.rawAttentionRatio = 1.0  // No faces = neutral
        }

        // Apply exponential smoothing
        self.smoothedAttentionRatio = (smoothingFactor * smoothedAttentionRatio) +
                                       ((1.0 - smoothingFactor) * rawAttentionRatio)

        // Send MIDI data (uses smoothed ratio for stability)
        midiOutput.sendAttentionData(
            attentionRatio: smoothedAttentionRatio,
            faceCount: faceCount,
            lookingDownCount: lookingDownCount
        )
    }

    /// Reset smoothed values (e.g., when changing devices)
    func resetSmoothing() {
        smoothedAttentionRatio = 1.0
        rawAttentionRatio = 1.0
    }

    /// Clear any error state
    func clearError() {
        errorMessage = nil
    }
}

/// Represents an available video input device
struct VideoDevice: Identifiable, Hashable {
    let id: String
    let name: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: VideoDevice, rhs: VideoDevice) -> Bool {
        lhs.id == rhs.id
    }
}
