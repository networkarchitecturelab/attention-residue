//
//  ContentView.swift
//  AttentionResidue
//
//  Main UI combining video preview, controls, and statistics
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var detectionState: DetectionState

    @StateObject private var videoCapture = VideoCapture()
    @State private var faceDetector = FaceDetector()
    @State private var detectionBridge: DetectionBridge?  // Strong reference to prevent deallocation

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            ToolbarView(
                availableDevices: detectionState.availableDevices,
                selectedDeviceID: $detectionState.selectedDeviceID,
                showOverlay: $detectionState.showOverlay,
                onDeviceChange: handleDeviceChange
            )

            Divider()

            // Video preview with overlay
            VideoPreviewView(
                captureSession: videoCapture.captureSession,
                detectedFaces: detectionState.detectedFaces,
                showOverlay: detectionState.showOverlay
            )
            .background(Color.black)

            Divider()

            // Stats panel
            StatsOverlayView(
                faceCount: detectionState.faceCount,
                lookingDownCount: detectionState.lookingDownCount,
                attentionRatio: detectionState.smoothedAttentionRatio
            )
            .padding()
        }
        .frame(minWidth: 640, minHeight: 560)
        .onAppear {
            setupCapture()
        }
        .onDisappear {
            videoCapture.stop()
        }
    }

    // MARK: - Setup

    private func setupCapture() {
        // Check camera authorization
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            initializeCapture()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        initializeCapture()
                    }
                } else {
                    DispatchQueue.main.async {
                        detectionState.errorMessage = "Camera access denied"
                    }
                }
            }

        case .denied, .restricted:
            detectionState.errorMessage = "Camera access denied. Please enable in System Settings."

        @unknown default:
            detectionState.errorMessage = "Unknown camera authorization status"
        }
    }

    private func initializeCapture() {
        // Get available devices
        let devices = VideoCapture.availableDevices()
        detectionState.availableDevices = devices

        // Select first device if none selected
        if detectionState.selectedDeviceID == nil, let firstDevice = devices.first {
            detectionState.selectedDeviceID = firstDevice.id
        }

        // Set up video capture delegate (store strong reference to prevent deallocation)
        let bridge = DetectionBridge(
            faceDetector: faceDetector,
            detectionState: detectionState
        )
        detectionBridge = bridge
        videoCapture.delegate = bridge

        // Start capture
        if let deviceID = detectionState.selectedDeviceID {
            videoCapture.startCapture(with: deviceID)
        } else {
            videoCapture.startCapture()
        }

        detectionState.isCapturing = true
    }

    // MARK: - Actions

    private func handleDeviceChange(_ deviceID: String) {
        detectionState.resetSmoothing()
        videoCapture.switchDevice(to: deviceID)
    }
}

// MARK: - Toolbar View

struct ToolbarView: View {
    let availableDevices: [VideoDevice]
    @Binding var selectedDeviceID: String?
    @Binding var showOverlay: Bool
    let onDeviceChange: (String) -> Void

    var body: some View {
        HStack {
            // Device picker
            Picker("Camera", selection: Binding(
                get: { selectedDeviceID ?? "" },
                set: { newValue in
                    selectedDeviceID = newValue
                    onDeviceChange(newValue)
                }
            )) {
                ForEach(availableDevices) { device in
                    Text(device.name).tag(device.id)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 300)

            Spacer()

            // Overlay toggle
            Toggle("Show Overlay", isOn: $showOverlay)
                .toggleStyle(.checkbox)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Detection Bridge

/// Bridges video capture to face detection and state updates
class DetectionBridge: VideoCaptureDelegate {
    let faceDetector: FaceDetector
    let detectionState: DetectionState

    /// Frame skip counter for performance
    private var frameCount = 0
    private let processEveryNFrames = 2  // Process every other frame

    init(faceDetector: FaceDetector, detectionState: DetectionState) {
        self.faceDetector = faceDetector
        self.detectionState = detectionState
    }

    func videoCapture(_ capture: VideoCapture, didCapture sampleBuffer: CMSampleBuffer) {
        // Skip frames for performance
        frameCount += 1
        guard frameCount % processEveryNFrames == 0 else { return }

        // Run detection
        let faces = faceDetector.detectFaces(in: sampleBuffer)

        // Debug: log when faces are detected
        if !faces.isEmpty && frameCount % 30 == 0 {
            print("[Detection] Found \(faces.count) faces: \(faces.map { "bbox=\($0.boundingBox), pitch=\($0.pitchAngle ?? 0)" })")
        }

        // Update state on main thread
        Task { @MainActor in
            detectionState.updateDetection(faces: faces)
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DetectionState())
    }
}
