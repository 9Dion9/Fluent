//
//  GhostButton.swift
//  Fluent
//

import SwiftUI

/// Secondary action — outlined, no fill. Pairs with `PrimaryButton` (DESIGN.md §7).
struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            Theme.Haptic.chipTap()
            action()
        } label: {
            Text(title)
                .font(Theme.Font.body(17, weight: .medium))
                .foregroundStyle(Theme.Colors.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .stroke(Theme.Colors.inkSoft.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GhostButton(title: "Skip") {}
        .padding()
        .background(Theme.Colors.bg)
}
