//
//  ConfettiView.swift
//  Fluent
//
//  Small, tasteful, accent+honey+leaf particles, 1.2s (DESIGN.md §6). Used at:
//  placement result, daily set complete, streak milestone, first camera word.
//  Nowhere else — scarcity keeps it special. Reduce Motion swaps to a crossfade.
//

import SwiftUI

struct ConfettiView: View {
    @Binding var isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let colors = [Theme.Colors.accent, Theme.Colors.honey, Theme.Colors.leaf]
    private let particleCount = 24

    var body: some View {
        ZStack {
            if isActive {
                ForEach(0..<particleCount, id: \.self) { index in
                    ConfettiParticle(color: colors[index % colors.count], reduceMotion: reduceMotion)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newValue in
            guard newValue else { return }
            Theme.Haptic.streakOrLevelUp()
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                isActive = false
            }
        }
    }
}

private struct ConfettiParticle: View {
    let color: Color
    let reduceMotion: Bool

    @State private var animate = false

    private let startX = Double.random(in: -80...80)
    private let endX = Double.random(in: -160...160)
    private let endY = Double.random(in: 200...400)
    private let rotation = Double.random(in: 0...360)
    private let size = Double.random(in: 6...10)

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: size, height: size * 0.6)
            .rotationEffect(.degrees(animate ? rotation : 0))
            .offset(x: animate ? endX : startX, y: animate ? endY : -20)
            .opacity(reduceMotion ? (animate ? 0 : 1) : (animate ? 0 : 1))
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .easeOut(duration: 1.1)) {
                    animate = true
                }
            }
    }
}

#Preview {
    @Previewable @State var isActive = true
    ZStack {
        Theme.Colors.bg
        ConfettiView(isActive: $isActive)
    }
    .ignoresSafeArea()
}
