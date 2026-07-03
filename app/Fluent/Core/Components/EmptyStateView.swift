//
//  EmptyStateView.swift
//  Fluent
//
//  Blob + one line of tutor-voice copy + one action (DESIGN.md §7).
//

import SwiftUI

struct EmptyStateView: View {
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Circle()
                .fill(Theme.Colors.surfaceAlt)
                .frame(width: 96, height: 96)

            Text(message)
                .font(Theme.Font.body(17))
                .foregroundStyle(Theme.Colors.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                GhostButton(title: actionTitle, action: action)
                    .frame(maxWidth: 220)
            }
        }
        .padding(Theme.Spacing.xl)
    }
}

#Preview {
    EmptyStateView(message: "Nothing here yet — that's about to change.", actionTitle: "Get started") {}
        .background(Theme.Colors.bg)
}
