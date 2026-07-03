//
//  ProgressRing.swift
//  Fluent
//
//  Daily goal ring, honey -> accent gradient (DESIGN.md §7).
//

import SwiftUI

struct ProgressRing: View {
    let progress: Double // 0...1
    var lineWidth: CGFloat = 8
    var size: CGFloat = 64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.surfaceAlt, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    AngularGradient(
                        colors: [Theme.Colors.honey, Theme.Colors.accent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(Theme.Motion.adaptive(reduceMotion), value: progress)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

#Preview {
    ProgressRing(progress: 0.4)
        .padding()
        .background(Theme.Colors.bg)
}
