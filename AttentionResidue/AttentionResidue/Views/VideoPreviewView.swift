//
//  VideoPreviewView.swift
//  AttentionResidue
//
//  NSViewRepresentable wrapper for AVCaptureVideoPreviewLayer with detection overlay
//

import SwiftUI
import AVFoundation
import AppKit

/// SwiftUI wrapper for the video preview layer
struct VideoPreviewView: NSViewRepresentable {
    let captureSession: AVCaptureSession
    let detectedFaces: [DetectedFace]
    let showOverlay: Bool

    func makeNSView(context: Context) -> VideoPreviewNSView {
        let view = VideoPreviewNSView()
        view.captureSession = captureSession
        return view
    }

    func updateNSView(_ nsView: VideoPreviewNSView, context: Context) {
        nsView.detectedFaces = detectedFaces
        nsView.showOverlay = showOverlay
        nsView.updateOverlay()
    }
}

/// Custom NSView that hosts the preview layer and draws detection overlay
class VideoPreviewNSView: NSView {
    var captureSession: AVCaptureSession? {
        didSet {
            setupPreviewLayer()
        }
    }

    var detectedFaces: [DetectedFace] = []
    var showOverlay: Bool = true

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var overlayLayer: CALayer?
    private var faceBoxLayers: [CALayer] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    private func setupPreviewLayer() {
        // Remove existing preview layer
        previewLayer?.removeFromSuperlayer()
        overlayLayer?.removeFromSuperlayer()

        guard let session = captureSession, let rootLayer = self.layer else { return }

        // Create preview layer
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspect
        preview.frame = bounds
        rootLayer.addSublayer(preview)
        previewLayer = preview

        // Create overlay layer on top of preview
        let overlay = CALayer()
        overlay.frame = bounds
        overlay.zPosition = 1  // Ensure overlay is above preview
        rootLayer.addSublayer(overlay)
        overlayLayer = overlay

        print("[VideoPreview] Setup complete - preview: \(preview.frame), overlay: \(overlay.frame)")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        overlayLayer?.frame = bounds
        updateOverlay()
        CATransaction.commit()
    }

    /// Update the overlay with current face detections
    func updateOverlay() {
        // Remove old face boxes
        for layer in faceBoxLayers {
            layer.removeFromSuperlayer()
        }
        faceBoxLayers.removeAll()

        // Debug: print face count
        if !detectedFaces.isEmpty {
            print("[Overlay] Updating with \(detectedFaces.count) faces, showOverlay=\(showOverlay), overlayLayer=\(overlayLayer != nil)")
        }

        guard showOverlay, !detectedFaces.isEmpty else { return }

        // Ensure overlay layer exists
        guard let overlayLayer = overlayLayer else {
            print("[Overlay] ERROR: overlayLayer is nil!")
            return
        }

        // Get the video preview rect (accounting for aspect ratio)
        let videoRect = calculateVideoRect()
        print("[Overlay] videoRect=\(videoRect), bounds=\(bounds)")

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for face in detectedFaces {
            // Convert normalized coordinates to view coordinates
            // Vision coordinates: origin at bottom-left, values 0-1
            // macOS layer coordinates: origin at bottom-left (same as Vision)
            let faceRect = CGRect(
                x: videoRect.origin.x + face.boundingBox.origin.x * videoRect.width,
                y: videoRect.origin.y + face.boundingBox.origin.y * videoRect.height,
                width: face.boundingBox.width * videoRect.width,
                height: face.boundingBox.height * videoRect.height
            )
            print("[Overlay] Drawing face at \(faceRect) from bbox \(face.boundingBox)")

            // Choose color based on gaze direction
            let color: CGColor = face.isLookingDown ? NSColor.systemRed.cgColor : NSColor.systemGreen.cgColor

            // Create bounding box layer
            let boxLayer = CAShapeLayer()
            boxLayer.frame = faceRect
            boxLayer.borderColor = color
            boxLayer.borderWidth = 3.0
            boxLayer.fillColor = nil
            boxLayer.cornerRadius = 4
            overlayLayer.addSublayer(boxLayer)
            faceBoxLayers.append(boxLayer)

            // Create label layer
            let label = face.isLookingDown ? "PHONE" : "ENGAGED"
            let textLayer = CATextLayer()
            textLayer.string = label
            textLayer.fontSize = 14
            textLayer.font = NSFont.systemFont(ofSize: 14, weight: .bold)
            textLayer.foregroundColor = color
            textLayer.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0

            let textSize = CGSize(width: 80, height: 20)
            textLayer.frame = CGRect(
                x: faceRect.origin.x,
                y: faceRect.origin.y + faceRect.height + 4,
                width: textSize.width,
                height: textSize.height
            )
            textLayer.cornerRadius = 3
            overlayLayer.addSublayer(textLayer)
            faceBoxLayers.append(textLayer)

            // Create pitch angle label if available
            if let pitch = face.pitchAngle {
                let pitchLabel = String(format: "%.0f°", pitch)
                let pitchLayer = CATextLayer()
                pitchLayer.string = pitchLabel
                pitchLayer.fontSize = 12
                pitchLayer.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
                pitchLayer.foregroundColor = NSColor.white.cgColor
                pitchLayer.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
                pitchLayer.alignmentMode = .center
                pitchLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
                pitchLayer.frame = CGRect(
                    x: faceRect.origin.x,
                    y: faceRect.origin.y - 22,
                    width: 50,
                    height: 18
                )
                pitchLayer.cornerRadius = 3
                overlayLayer.addSublayer(pitchLayer)
                faceBoxLayers.append(pitchLayer)
            }
        }

        CATransaction.commit()
    }

    /// Calculate the actual video display rect within the view (accounting for aspect ratio)
    private func calculateVideoRect() -> CGRect {
        guard let previewLayer = previewLayer else { return bounds }

        let layerRect = previewLayer.frame

        // Try to get actual video dimensions from the session
        var videoAspect: CGFloat = 16.0 / 9.0  // Default fallback

        if let connection = previewLayer.connection,
           let inputPort = connection.inputPorts.first,
           let formatDescription = inputPort.formatDescription {
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            if dimensions.height > 0 {
                videoAspect = CGFloat(dimensions.width) / CGFloat(dimensions.height)
            }
        }

        let viewAspect = layerRect.width / layerRect.height

        var videoRect: CGRect

        if videoAspect > viewAspect {
            // Video is wider than view - letterboxed top/bottom
            let videoHeight = layerRect.width / videoAspect
            let yOffset = (layerRect.height - videoHeight) / 2
            videoRect = CGRect(x: 0, y: yOffset, width: layerRect.width, height: videoHeight)
        } else {
            // Video is taller than view - pillarboxed left/right
            let videoWidth = layerRect.height * videoAspect
            let xOffset = (layerRect.width - videoWidth) / 2
            videoRect = CGRect(x: xOffset, y: 0, width: videoWidth, height: layerRect.height)
        }

        return videoRect
    }
}
