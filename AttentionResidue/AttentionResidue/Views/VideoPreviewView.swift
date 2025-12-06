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
        nsView.setNeedsDisplay(nsView.bounds)
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

        guard let session = captureSession else { return }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
        layer.frame = bounds

        self.layer?.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard showOverlay, !detectedFaces.isEmpty else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Get the video preview rect (accounting for aspect ratio)
        let videoRect = calculateVideoRect()

        for face in detectedFaces {
            // Convert normalized coordinates to view coordinates
            // Vision coordinates: origin at bottom-left, values 0-1
            // View coordinates: origin at top-left (in AppKit, actually bottom-left too)
            let faceRect = CGRect(
                x: videoRect.origin.x + face.boundingBox.origin.x * videoRect.width,
                y: videoRect.origin.y + face.boundingBox.origin.y * videoRect.height,
                width: face.boundingBox.width * videoRect.width,
                height: face.boundingBox.height * videoRect.height
            )

            // Choose color based on gaze direction
            let color: NSColor = face.isLookingDown ? .systemRed : .systemGreen

            // Draw bounding box
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(2.0)
            context.stroke(faceRect)

            // Draw label
            let label = face.isLookingDown ? "PHONE" : "ENGAGED"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: color,
                .backgroundColor: NSColor.black.withAlphaComponent(0.5)
            ]

            let labelString = NSAttributedString(string: label, attributes: attributes)
            let labelSize = labelString.size()

            let labelRect = CGRect(
                x: faceRect.origin.x,
                y: faceRect.origin.y + faceRect.height + 2,
                width: labelSize.width + 4,
                height: labelSize.height
            )

            labelString.draw(in: labelRect)

            // Draw pitch angle if available
            if let pitch = face.pitchAngle {
                let pitchLabel = String(format: "%.0f°", pitch)
                let pitchAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: NSColor.white,
                    .backgroundColor: NSColor.black.withAlphaComponent(0.5)
                ]
                let pitchString = NSAttributedString(string: pitchLabel, attributes: pitchAttributes)
                let pitchRect = CGRect(
                    x: faceRect.origin.x,
                    y: faceRect.origin.y - 14,
                    width: pitchString.size().width + 4,
                    height: pitchString.size().height
                )
                pitchString.draw(in: pitchRect)
            }
        }
    }

    /// Calculate the actual video display rect within the view (accounting for aspect ratio)
    private func calculateVideoRect() -> CGRect {
        guard let previewLayer = previewLayer else { return bounds }

        // For resizeAspect, the video is centered and scaled to fit
        // We need to calculate where the video actually appears
        let layerRect = previewLayer.frame

        // Default to full bounds if we can't determine aspect ratio
        // The actual video rect depends on the capture device format
        // For simplicity, assume 16:9 aspect ratio
        let videoAspect: CGFloat = 16.0 / 9.0
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
