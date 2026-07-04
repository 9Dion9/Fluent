//
//  SettingsView.swift
//  Fluent
//
//  Minimal dev/testing affordance — CLAUDE.md's milestones never spec a
//  Settings screen, so this is intentionally small: today it only exists to
//  let you redo onboarding (e.g. to switch target language) without
//  reinstalling the app. Expand here if/when a real Settings screen gets
//  specced in DESIGN.md.
//

import SwiftUI

struct SettingsView: View {
    let router: AppRouter
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            if let profile = router.profile {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Learning")
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.Colors.inkSoft)
                    Text("\(profile.nativeLang.uppercased()) → \(profile.targetLang.uppercased()), \(profile.level)")
                        .font(Theme.Font.body(17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink)
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.Colors.surface))
            }

            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Text("Restart onboarding")
                    .font(Theme.Font.body(17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(.white)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous).fill(Theme.Colors.ink))
            }
            .buttonStyle(.plain)

            Text("Re-collects native/target language, level, interests, tutor, and reminder — for the same account, no data loss.")
                .font(Theme.Font.caption())
                .foregroundStyle(Theme.Colors.inkSoft)

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.bg)
        .navigationTitle("Settings")
        .confirmationDialog(
            "Restart onboarding?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restart onboarding", role: .destructive) {
                router.resetOnboarding()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(router: AppRouter())
    }
}
