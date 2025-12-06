//
//  StatsOverlayView.swift
//  AttentionResidue
//
//  Display for detection statistics and attention ratio
//

import SwiftUI

/// Displays detection statistics and attention ratio visualization
struct StatsOverlayView: View {
    let faceCount: Int
    let lookingDownCount: Int
    let attentionRatio: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stats row
            HStack(spacing: 24) {
                StatItem(label: "Faces", value: "\(faceCount)", color: .primary)
                StatItem(label: "Looking Down", value: "\(lookingDownCount)", color: .red)
                StatItem(label: "Engaged", value: "\(faceCount - lookingDownCount)", color: .green)
            }

            // Attention ratio
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Attention Ratio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", attentionRatio * 100))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                }

                // Bar graph
                AttentionBar(ratio: attentionRatio)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

/// Individual stat display
struct StatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

/// Horizontal bar showing attention ratio
struct AttentionBar: View {
    let ratio: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))

                // Filled portion
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: max(0, geometry.size.width * CGFloat(ratio)))
            }
        }
        .frame(height: 24)
    }

    /// Color gradient based on ratio
    var barColor: Color {
        if ratio > 0.7 {
            return .green
        } else if ratio > 0.4 {
            return .yellow
        } else {
            return .red
        }
    }
}

/// Preview provider for development
struct StatsOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            StatsOverlayView(faceCount: 5, lookingDownCount: 2, attentionRatio: 0.6)
            StatsOverlayView(faceCount: 3, lookingDownCount: 3, attentionRatio: 0.0)
            StatsOverlayView(faceCount: 4, lookingDownCount: 0, attentionRatio: 1.0)
            StatsOverlayView(faceCount: 0, lookingDownCount: 0, attentionRatio: 1.0)
        }
        .padding()
        .frame(width: 400)
    }
}
