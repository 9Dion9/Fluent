//
//  SuggestionChips.swift
//  Fluent
//
//  Tappable reply suggestions above the chat input (DESIGN.md §7, §8).
//  The first-message flow relies on one of these being pre-glowing so the
//  very first interaction cannot fail (DESIGN.md §9.9).
//

import SwiftUI

struct SuggestionChips: View {
    let suggestions: [String]
    var highlightedIndex: Int? = nil
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    Button {
                        Theme.Haptic.chipTap()
                        onSelect(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(Theme.Font.body(14, weight: .medium))
                            .foregroundStyle(index == highlightedIndex ? .white : Theme.Colors.ink)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .frame(minHeight: 44)
                            .background(
                                Capsule().fill(
                                    index == highlightedIndex ? Theme.Colors.accent : Theme.Colors.surfaceAlt
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
}

#Preview {
    SuggestionChips(suggestions: ["Hallo, Emma!", "Wie geht's?"], highlightedIndex: 0) { _ in }
        .padding(.vertical)
        .background(Theme.Colors.bg)
}
