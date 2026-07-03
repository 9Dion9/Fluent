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
    /// Shown centered in the ring, e.g. the daily goal number. `nil` renders no label.
    var centerLabel: String?

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

            if let centerLabel {
                Text(centerLabel)
                    .font(Theme.Font.display(size * 0.32))
                    .foregroundStyle(Theme.Colors.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

#Preview {
    ProgressRing(progress: 0.4, centerLabel: "10")
        .padding()
        .background(Theme.Colors.bg)
}
