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
                // DESIGN.md §8's full "Today" dashboard (streak flame + progress
                // ring + the 3 action cards in one scroll) lands with M8 hardening
                // once every feature exists — for now each feature gets its own
                // reachable tab instead of a single combined Home screen.
                TabView {
                    NavigationStack {
                        ChatView(
                            tutorName: router.profile?.tutorName ?? "Tutor",
                            targetLang: router.profile?.targetLang ?? "de",
                            seed: router.pendingChatSeed
                        )
                    }
                    .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }

                    NavigationStack {
                        DailyWordsView()
                    }
                    .tabItem { Label("Words", systemImage: "textformat.abc") }

                    NavigationStack {
                        ReviewSessionView()
                    }
                    .tabItem { Label("Review", systemImage: "rectangle.stack.fill") }

                    NavigationStack {
                        QuizContainerView()
                    }
                    .tabItem { Label("Games", systemImage: "gamecontroller.fill") }

                    NavigationStack {
                        CameraView()
                    }
                    .tabItem { Label("Camera", systemImage: "camera.fill") }
                }
                .tint(Theme.Colors.accent)

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
