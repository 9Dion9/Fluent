//
//  RootView.swift
//  Fluent
//

import SwiftUI

struct RootView: View {
    @State private var router = AppRouter()

    var body: some View {
        Group {
            switch router.screen {
            case .launching:
                ProgressView()
                    .tint(Theme.Colors.accent)

            case .onboarding:
                OnboardingContainerView(router: router)

            case .home:
                // Real Home (DESIGN.md §8) lands with chat/daily-words/review in
                // M3+. This placeholder proves the onboarding -> home handoff works.
                HomePlaceholderView(profile: router.profile)

            case .launchFailed(let message):
                EmptyStateView(
                    message: "Couldn't reach {tutor} — your words and reviews still work offline.\n(\(message))",
                    actionTitle: "Try again"
                ) {
                    Task { await router.start() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.bg)
        .task {
            if case .launching = router.screen {
                await router.start()
            }
        }
    }
}

private struct HomePlaceholderView: View {
    let profile: Profile?

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if let profile {
                StreakFlame(count: profile.streakCurrent, earnedToday: false)
                Text("Welcome back — onboarded as a \(profile.level) \(profile.targetLang) learner.")
                    .font(Theme.Font.body(17))
                    .foregroundStyle(Theme.Colors.ink)
                    .multilineTextAlignment(.center)
                Text("Chat, daily words, and review land in the next milestones.")
                    .font(Theme.Font.caption())
                    .foregroundStyle(Theme.Colors.inkSoft)
            }
        }
        .padding(Theme.Spacing.xl)
    }
}

#Preview {
    RootView()
}
