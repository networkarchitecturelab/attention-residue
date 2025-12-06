//
//  AttentionResidueApp.swift
//  AttentionResidue
//
//  Attention Residue - Video art installation analyzing phone attention
//  Artist: Kazys Varnelis
//

import SwiftUI

@main
struct AttentionResidueApp: App {
    @StateObject private var detectionState = DetectionState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(detectionState)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 800, height: 700)
    }
}
