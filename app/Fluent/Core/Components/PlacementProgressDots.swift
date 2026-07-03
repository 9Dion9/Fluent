//
//  PlacementProgressDots.swift
//  Fluent
//
//  Progress dots across the top, from onboarding screen 2 on (DESIGN.md §9).
//

import SwiftUI

struct PlacementProgressDots: View {
    let total: Int
    let currentIndex: Int // 0-based

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? Theme.Colors.accent : Theme.Colors.surfaceAlt)
                    .frame(width: index == currentIndex ? 20 : 8, height: 8)
                    .animation(Theme.Motion.adaptive(reduceMotion), value: currentIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentIndex + 1) of \(total)")
    }
}

#Preview {
    PlacementProgressDots(total: 8, currentIndex: 3)
        .padding()
        .background(Theme.Colors.bg)
}
