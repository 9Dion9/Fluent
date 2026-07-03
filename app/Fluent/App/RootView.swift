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
                // Full Home (DESIGN.md §8: Today/Chat/Words/Camera tabs) lands once
                // daily words (M5) and camera (M7) exist. Chat is the only feature
                // built so far, so it's the whole home surface for now.
                NavigationStack {
                    ChatView(tutorName: router.profile?.tutorName ?? "Tutor", seed: router.pendingChatSeed)
                }

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

#Preview {
    RootView()
}
