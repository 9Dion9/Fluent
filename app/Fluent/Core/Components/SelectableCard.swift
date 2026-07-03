//
//  SelectableCard.swift
//  Fluent
//
//  Big single-select cards (onboarding target-language, level, persona screens)
//  and small multi-select chips (interests). Springy select with checkmark morph,
//  color is never the only signal — a checkmark/border always confirms selection
//  (DESIGN.md §7, §12).
//

import SwiftUI

struct SelectableCard: View {
    let title: String
    let subtitle: String?
    let emoji: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(title: String, subtitle: String? = nil, emoji: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.emoji = emoji
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button {
            Theme.Haptic.chipTap()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                if let emoji {
                    Text(emoji).font(.system(size: 32))
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Font.body(17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Font.caption())
                            .foregroundStyle(Theme.Colors.inkSoft)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.accent)
                        .font(.system(size: 22))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .shadow(color: Theme.Colors.shadow, radius: 12, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(isSelected ? Theme.Colors.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.adaptive(reduceMotion), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Small multi-select pill (interests screen).
struct SelectableChip: View {
    let title: String
    let emoji: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(title: String, emoji: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.emoji = emoji
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button {
            Theme.Haptic.chipTap()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                if let emoji {
                    Text(emoji)
                }
                Text(title)
                    .font(Theme.Font.body(15, weight: .medium))
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundStyle(isSelected ? .white : Theme.Colors.ink)
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(minHeight: 44)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.Colors.accent : Theme.Colors.surfaceAlt)
            )
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.adaptive(reduceMotion), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        SelectableCard(title: "German", subtitle: "spoken by 130M people", emoji: "🥨", isSelected: true) {}
        SelectableCard(title: "English", subtitle: "the world's handshake", emoji: "☕", isSelected: false) {}
        HStack {
            SelectableChip(title: "Travel", emoji: "✈️", isSelected: true) {}
            SelectableChip(title: "Food", emoji: "🥐", isSelected: false) {}
        }
    }
    .padding()
    .background(Theme.Colors.bg)
}
