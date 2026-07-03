//
//  PrimaryButton.swift
//  Fluent
//

import SwiftUI

/// Full-width, 54pt, `Theme.Colors.accent` — the one primary action per screen (DESIGN.md §3, §7).
struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    var body: some View {
        Button {
            Theme.Haptic.chipTap()
            action()
        } label: {
            Text(title)
                .font(Theme.Font.body(17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .fill(Theme.Colors.accent)
                        .opacity(isEnabled ? 1 : 0.4)
                )
                .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(Theme.Motion.adaptive(reduceMotion), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        PrimaryButton(title: "Let's go") {}
        PrimaryButton(title: "Disabled", isEnabled: false) {}
    }
    .padding()
    .background(Theme.Colors.bg)
}
