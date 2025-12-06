//
//  MIDIOutput.swift
//  AttentionResidue
//
//  CoreMIDI virtual source for sending attention data to external apps like Lumen
//

import Foundation
import CoreMIDI

/// Manages a virtual MIDI source for outputting attention data as CC messages
class MIDIOutput: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var lastCCValue: UInt8 = 0
    @Published private(set) var lastFaceCountCC: UInt8 = 0
    @Published private(set) var lastLookingDownCC: UInt8 = 0

    // MARK: - MIDI Properties

    private var midiClient: MIDIClientRef = 0
    private var midiSource: MIDIEndpointRef = 0

    /// MIDI channel (0-15, we use channel 1 = index 0)
    private let midiChannel: UInt8 = 0

    /// CC numbers
    private let ccAttentionRatio: UInt8 = 1
    private let ccFaceCount: UInt8 = 2
    private let ccLookingDown: UInt8 = 3

    /// Throttling
    private var lastSendTime: Date = .distantPast
    private let minimumInterval: TimeInterval = 1.0 / 30.0  // 30Hz max

    /// Source name visible in MIDI apps
    private let sourceName = "Attention Residue"

    // MARK: - Initialization

    init() {
        // Don't auto-enable, wait for user to toggle
    }

    deinit {
        disable()
    }

    // MARK: - Public Methods

    /// Enable MIDI output by creating virtual source
    func enable() {
        guard !isEnabled else { return }

        // Create MIDI client
        var status = MIDIClientCreateWithBlock(sourceName as CFString, &midiClient) { notification in
            // Handle MIDI setup changes if needed
            print("[MIDI] Setup changed: \(notification.pointee.messageID)")
        }

        guard status == noErr else {
            print("[MIDI] Failed to create client: \(status)")
            return
        }

        // Create virtual source
        status = MIDISourceCreate(midiClient, sourceName as CFString, &midiSource)

        guard status == noErr else {
            print("[MIDI] Failed to create source: \(status)")
            MIDIClientDispose(midiClient)
            midiClient = 0
            return
        }

        isEnabled = true
        print("[MIDI] Virtual source '\(sourceName)' created successfully")
    }

    /// Disable MIDI output and clean up
    func disable() {
        guard isEnabled else { return }

        if midiSource != 0 {
            MIDIEndpointDispose(midiSource)
            midiSource = 0
        }

        if midiClient != 0 {
            MIDIClientDispose(midiClient)
            midiClient = 0
        }

        isEnabled = false
        print("[MIDI] Virtual source disposed")
    }

    /// Toggle MIDI output on/off
    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }

    /// Send attention data as MIDI CC messages
    /// - Parameters:
    ///   - attentionRatio: 0.0 to 1.0 attention ratio
    ///   - faceCount: Number of detected faces
    ///   - lookingDownCount: Number of faces looking down
    func sendAttentionData(attentionRatio: Double, faceCount: Int, lookingDownCount: Int) {
        guard isEnabled else { return }

        // Throttle to avoid flooding
        let now = Date()
        guard now.timeIntervalSince(lastSendTime) >= minimumInterval else { return }
        lastSendTime = now

        // Convert values to 0-127 range
        let ratioCC = UInt8(min(127, max(0, Int(attentionRatio * 127.0))))
        let faceCC = UInt8(min(127, faceCount))
        let downCC = UInt8(min(127, lookingDownCount))

        // Send CC messages
        sendCC(controller: ccAttentionRatio, value: ratioCC)
        sendCC(controller: ccFaceCount, value: faceCC)
        sendCC(controller: ccLookingDown, value: downCC)

        // Update published values on main thread
        DispatchQueue.main.async {
            self.lastCCValue = ratioCC
            self.lastFaceCountCC = faceCC
            self.lastLookingDownCC = downCC
        }
    }

    // MARK: - Private Methods

    /// Send a single CC message
    private func sendCC(controller: UInt8, value: UInt8) {
        // MIDI CC message: status byte (0xB0 + channel), controller number, value
        let statusByte = UInt8(0xB0) + midiChannel

        // Build the MIDI packet
        var packet = MIDIPacket()
        packet.timeStamp = 0  // Send immediately
        packet.length = 3
        packet.data.0 = statusByte
        packet.data.1 = controller
        packet.data.2 = value

        // Create packet list
        var packetList = MIDIPacketList(numPackets: 1, packet: packet)

        // Send from our virtual source
        let status = MIDIReceived(midiSource, &packetList)
        if status != noErr {
            print("[MIDI] Failed to send CC \(controller)=\(value): \(status)")
        }
    }
}
