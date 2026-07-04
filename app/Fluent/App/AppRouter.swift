//
//  AppRouter.swift
//  Fluent
//
//  Single top-level router (CLAUDE.md §3). Owns the launch sequence: device
//  auth -> onboarding (if not yet done) -> home.
//

import SwiftUI

/// A completed real `/v1/chat` round-trip from FirstMessageView (DESIGN.md §9.9),
/// carried into Home so Chat continues the same server-side conversation
/// instead of starting a fresh one.
struct OnboardingChatExchange {
    let conversationID: String
    let tutorGreeting: String
    let userReply: String
    let tutorReply: String
    let corrections: [ChatReply.Correction]
    let suggestedReplies: [String]
}

@Observable
final class AppRouter {
    enum Screen {
        case launching
        case onboarding
        case home
        case launchFailed(String)
    }

    var screen: Screen = .launching
    var profile: Profile?
    var pendingChatSeed: OnboardingChatExchange?

    private let authProvider: AuthProvider

    init(authProvider: AuthProvider = DeviceAuthProvider()) {
        self.authProvider = authProvider
    }

    func start() async {
        do {
            let profile = try await authProvider.ensureAuthenticated()
            self.profile = profile
            screen = Self.hasCompletedOnboarding(profile) ? .home : .onboarding
        } catch {
            screen = .launchFailed(error.localizedDescription)
        }
    }

    func onboardingCompleted(with profile: Profile) {
        self.profile = profile
        screen = .home
    }

    /// Dev/testing affordance (no CLAUDE.md-specced Settings screen exists yet):
    /// re-runs onboarding against the SAME device/user — no re-auth, no data
    /// loss, just re-collects native/target language, level, interests, etc.
    /// and PUTs them onto the existing profile, e.g. to switch target language.
    func resetOnboarding() {
        screen = .onboarding
    }

    /// The schema has no explicit `onboarding_completed` flag. Interests are
    /// required (min 2, DESIGN.md §9.6) and default to empty at account
    /// creation, so a non-empty interests list is a reliable "has onboarded"
    /// signal without a migration. Revisit if that invariant ever changes.
    private static func hasCompletedOnboarding(_ profile: Profile) -> Bool {
        !profile.interests.isEmpty
    }
}
