//
//  VideoCapture.swift
//  AttentionResidue
//
//  AVFoundation video capture manager
//

import Foundation
import AVFoundation
import CoreImage

/// Protocol for receiving video frames
protocol VideoCaptureDelegate: AnyObject {
    func videoCapture(_ capture: VideoCapture, didCapture sampleBuffer: CMSampleBuffer)
}

/// Manages video capture from cameras and USB capture devices
class VideoCapture: NSObject, ObservableObject {
    // MARK: - Properties

    weak var delegate: VideoCaptureDelegate?

    /// The AVFoundation capture session
    let captureSession = AVCaptureSession()

    /// Preview layer for displaying video
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    /// Current video input
    private var videoInput: AVCaptureDeviceInput?

    /// Video output for frame processing
    private var videoOutput: AVCaptureVideoDataOutput?

    /// Queue for video processing
    private let videoQueue = DispatchQueue(label: "com.attentionresidue.video", qos: .userInteractive)

    /// Currently selected device
    private(set) var currentDevice: AVCaptureDevice?

    /// Whether capture is running
    @Published private(set) var isRunning = false

    // MARK: - Initialization

    override init() {
        super.init()
        setupSession()
    }

    // MARK: - Device Enumeration

    /// Get all available video capture devices
    static func availableDevices() -> [VideoDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .externalUnknown  // This covers USB capture devices
            ],
            mediaType: .video,
            position: .unspecified
        )

        return discoverySession.devices.map { device in
            VideoDevice(id: device.uniqueID, name: device.localizedName)
        }
    }

    /// Get the default video device
    static func defaultDevice() -> AVCaptureDevice? {
        // Try to get a USB/external device first (for the capture card)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.externalUnknown],
            mediaType: .video,
            position: .unspecified
        )

        if let external = discoverySession.devices.first {
            return external
        }

        // Fall back to default video device (usually built-in webcam)
        return AVCaptureDevice.default(for: .video)
    }

    // MARK: - Session Setup

    private func setupSession() {
        captureSession.sessionPreset = .hd1280x720  // Good balance of quality and performance

        // Create preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspect
    }

    // MARK: - Device Selection

    /// Start capture with the specified device
    func startCapture(with deviceID: String? = nil) {
        let device: AVCaptureDevice?

        if let id = deviceID {
            device = AVCaptureDevice(uniqueID: id)
        } else {
            device = VideoCapture.defaultDevice()
        }

        guard let captureDevice = device else {
            print("No video device available")
            return
        }

        configure(with: captureDevice)
        start()
    }

    /// Configure session with a specific device
    private func configure(with device: AVCaptureDevice) {
        captureSession.beginConfiguration()

        // Remove existing input
        if let existingInput = videoInput {
            captureSession.removeInput(existingInput)
        }

        // Remove existing output
        if let existingOutput = videoOutput {
            captureSession.removeOutput(existingOutput)
        }

        // Add new input
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                videoInput = input
                currentDevice = device
            }
        } catch {
            print("Error creating video input: \(error)")
            captureSession.commitConfiguration()
            return
        }

        // Add video output for frame processing
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: videoQueue)

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            videoOutput = output
        }

        captureSession.commitConfiguration()
    }

    /// Switch to a different device
    func switchDevice(to deviceID: String) {
        guard let device = AVCaptureDevice(uniqueID: deviceID) else {
            print("Device not found: \(deviceID)")
            return
        }

        // Perform all session operations on the video queue to avoid threading issues
        videoQueue.async { [weak self] in
            guard let self = self else { return }

            let wasRunning = self.captureSession.isRunning
            if wasRunning {
                self.captureSession.stopRunning()
            }

            // Configure on video queue
            self.captureSession.beginConfiguration()

            // Remove existing input
            if let existingInput = self.videoInput {
                self.captureSession.removeInput(existingInput)
            }

            // Remove existing output
            if let existingOutput = self.videoOutput {
                self.captureSession.removeOutput(existingOutput)
            }

            // Add new input
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    self.videoInput = input
                    self.currentDevice = device
                }
            } catch {
                print("Error creating video input: \(error)")
                self.captureSession.commitConfiguration()
                return
            }

            // Add video output for frame processing
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.setSampleBufferDelegate(self, queue: self.videoQueue)

            if self.captureSession.canAddOutput(output) {
                self.captureSession.addOutput(output)
                self.videoOutput = output
            }

            self.captureSession.commitConfiguration()

            if wasRunning {
                self.captureSession.startRunning()
            }

            DispatchQueue.main.async {
                self.isRunning = self.captureSession.isRunning
            }
        }
    }

    // MARK: - Session Control

    /// Start the capture session
    func start() {
        videoQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.captureSession.isRunning else { return }

            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    /// Stop the capture session
    func stop() {
        videoQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.captureSession.isRunning else { return }

            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        delegate?.videoCapture(self, didCapture: sampleBuffer)
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Frame dropped - this is fine, we intentionally skip frames if we fall behind
    }
}
