//
//  FaceDetector.swift
//  AttentionResidue
//
//  Vision framework face detection and gaze analysis
//

import Foundation
import Vision
import CoreMedia
import CoreImage

/// Handles face detection and gaze analysis using Apple's Vision framework
class FaceDetector {
    // MARK: - Properties

    /// Threshold for considering someone as "looking down" (in degrees)
    /// Vision framework: positive pitch = looking down, negative = looking up
    /// This threshold is the minimum positive pitch to consider "looking down"
    var lookingDownThreshold: Double = 5.0

    /// Reusable request handler
    private var sequenceHandler = VNSequenceRequestHandler()

    /// Face detection request
    private lazy var faceDetectionRequest: VNDetectFaceLandmarksRequest = {
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        return request
    }()

    // MARK: - Detection

    /// Detect faces in a sample buffer and analyze gaze
    /// - Parameter sampleBuffer: The video frame to analyze
    /// - Returns: Array of detected faces with gaze analysis
    func detectFaces(in sampleBuffer: CMSampleBuffer) -> [DetectedFace] {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return []
        }

        return detectFaces(in: pixelBuffer)
    }

    /// Detect faces in a pixel buffer and analyze gaze
    /// - Parameter pixelBuffer: The pixel buffer to analyze
    /// - Returns: Array of detected faces with gaze analysis
    func detectFaces(in pixelBuffer: CVPixelBuffer) -> [DetectedFace] {
        do {
            try sequenceHandler.perform([faceDetectionRequest], on: pixelBuffer)
        } catch {
            print("Face detection error: \(error)")
            return []
        }

        guard let observations = faceDetectionRequest.results else {
            return []
        }

        return observations.compactMap { observation in
            analyzeFace(observation)
        }
    }

    // MARK: - Analysis

    /// Analyze a single face observation for gaze direction
    private func analyzeFace(_ observation: VNFaceObservation) -> DetectedFace? {
        let boundingBox = observation.boundingBox

        // Estimate pitch from various available data
        let pitchAngle = estimatePitch(from: observation)
        let isLookingDown = pitchAngle != nil && pitchAngle! > lookingDownThreshold

        return DetectedFace(
            boundingBox: boundingBox,
            isLookingDown: isLookingDown,
            pitchAngle: pitchAngle
        )
    }

    /// Estimate head pitch angle from face observation
    /// Uses multiple cues: roll/yaw if available, and landmark geometry
    private func estimatePitch(from observation: VNFaceObservation) -> Double? {
        // Method 1: Use Vision's built-in pitch if available (iOS 15+/macOS 12+)
        if let pitch = observation.pitch {
            // Vision returns pitch in radians, convert to degrees
            return Double(truncating: pitch) * (180.0 / .pi)
        }

        // Method 2: Estimate from facial landmarks
        if let landmarks = observation.landmarks {
            return estimatePitchFromLandmarks(landmarks, boundingBox: observation.boundingBox)
        }

        return nil
    }

    /// Estimate pitch from facial landmark geometry
    /// When looking down:
    /// - Nose appears higher relative to face center
    /// - Forehead is more visible
    /// - Chin/mouth area is compressed
    private func estimatePitchFromLandmarks(_ landmarks: VNFaceLandmarks2D, boundingBox: CGRect) -> Double? {
        guard let nose = landmarks.nose,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            return nil
        }

        // Get key points (normalized to face bounding box)
        let nosePoints = nose.normalizedPoints
        let leftEyePoints = leftEye.normalizedPoints
        let rightEyePoints = rightEye.normalizedPoints

        guard !nosePoints.isEmpty,
              !leftEyePoints.isEmpty,
              !rightEyePoints.isEmpty else {
            return nil
        }

        // Calculate nose tip position (usually the lowest point of the nose region)
        let noseTip = nosePoints.max(by: { $0.y > $1.y }) ?? nosePoints[0]

        // Calculate eye center
        let leftEyeCenter = averagePoint(leftEyePoints)
        let rightEyeCenter = averagePoint(rightEyePoints)
        let eyeCenter = CGPoint(
            x: (leftEyeCenter.x + rightEyeCenter.x) / 2,
            y: (leftEyeCenter.y + rightEyeCenter.y) / 2
        )

        // Calculate vertical distance from eyes to nose tip
        // In normalized coordinates within the face box
        let noseToEyeVertical = eyeCenter.y - noseTip.y

        // When looking down, this ratio changes
        // Normal frontal face: nose tip is roughly 0.3-0.4 of face height below eyes
        // Looking down: nose tip appears closer to eyes (ratio decreases)
        // Looking up: nose tip appears further from eyes (ratio increases)

        // Estimate pitch based on this ratio
        // These values are empirically determined
        let neutralRatio: CGFloat = 0.35
        let deviation = noseToEyeVertical - neutralRatio

        // Convert to approximate degrees
        // Rough mapping: 0.1 change in ratio ≈ 20 degrees pitch
        let estimatedPitch = Double(deviation) * 200.0

        return estimatedPitch
    }

    /// Calculate the average of an array of points
    private func averagePoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }

        let sum = points.reduce(CGPoint.zero) { result, point in
            CGPoint(x: result.x + point.x, y: result.y + point.y)
        }

        return CGPoint(
            x: sum.x / CGFloat(points.count),
            y: sum.y / CGFloat(points.count)
        )
    }
}
