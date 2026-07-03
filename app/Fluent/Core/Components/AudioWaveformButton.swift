//
//  AudioWaveformButton.swift
//  Fluent
//
//  Mic button toggles walkie-talkie mode: hold to record, waveform, release
//  to send (DESIGN.md §7, §8). Recording wiring itself lands in M4 — this is
//  the visual/interaction shell built now per the DESIGN.md §7 component list.
//

import SwiftUI

struct AudioWaveformButton: View {
    let isRecording: Bool
    let onHoldStart: () -> Void
    let onHoldEnd: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(isRecording ? Theme.Colors.accent : Theme.Colors.surfaceAlt)
                .frame(width: 54, height: 54)

            if isRecording {
                WaveformShape()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: 28, height: 20)
            } else {
                Image(systemName: "mic.fill")
                    .foregroundStyle(Theme.Colors.ink)
            }
        }
        .scaleEffect(isRecording ? 1.08 : 1)
        .animation(Theme.Motion.adaptive(reduceMotion), value: isRecording)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isRecording { onHoldStart() } }
                .onEnded { _ in onHoldEnd() }
        )
        .accessibilityLabel(isRecording ? "Recording, release to send" : "Hold to record a voice message")
    }
}

private struct WaveformShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bars = 5
        let barWidth = rect.width / CGFloat(bars * 2)
        let heights: [CGFloat] = [0.4, 0.8, 1.0, 0.6, 0.3]
        for (index, heightFraction) in heights.enumerated() {
            let x = CGFloat(index) * barWidth * 2 + barWidth / 2
            let barHeight = rect.height * heightFraction
            let y = (rect.height - barHeight) / 2
            path.addRect(CGRect(x: x, y: y, width: barWidth, height: barHeight))
        }
        return path
    }
}

#Preview {
    HStack(spacing: Theme.Spacing.xl) {
        AudioWaveformButton(isRecording: false, onHoldStart: {}, onHoldEnd: {})
        AudioWaveformButton(isRecording: true, onHoldStart: {}, onHoldEnd: {})
    }
    .padding()
    .background(Theme.Colors.bg)
}
