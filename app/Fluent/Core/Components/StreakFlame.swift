//
//  StreakFlame.swift
//  Fluent
//
//  Count + flame, grayscale when today's activity isn't earned yet (DESIGN.md §7).
//

import SwiftUI

struct StreakFlame: View {
    let count: Int
    let earnedToday: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "flame.fill")
                .foregroundStyle(earnedToday ? Theme.Colors.accent : Theme.Colors.inkSoft)
                .saturation(earnedToday ? 1 : 0)
            Text("\(count)")
                .font(Theme.Font.body(17, weight: .bold))
                .foregroundStyle(Theme.Colors.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak")
        .accessibilityValue("\(count) days\(earnedToday ? "" : ", not earned today yet")")
    }
}

#Preview {
    HStack {
        StreakFlame(count: 12, earnedToday: true)
        StreakFlame(count: 12, earnedToday: false)
    }
    .padding()
    .background(Theme.Colors.bg)
}
