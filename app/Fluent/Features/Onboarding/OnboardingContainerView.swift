//
//  OnboardingContainerView.swift
//  Fluent
//
//  Screen sequencing for DESIGN.md §9. One question, one card, one big
//  obvious action per screen (DESIGN.md §1.2).
//

import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case targetLanguage
    case knowledgeLevel
    case placement
    case placementResult
    case interests
    case goalReminder
    case meetTutor
    case firstMessage

    /// Progress dots show from screen 2 on (DESIGN.md §9).
    var dotIndex: Int? {
        self == .welcome ? nil : rawValue - 1
    }

    static var dotCount: Int { allCases.count - 1 }
}

struct OnboardingContainerView: View {
    let router: AppRouter

    @State private var viewModel = OnboardingViewModel()
    @State private var step: OnboardingStep = .welcome
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        VStack(spacing: 0) {
            if let dotIndex = step.dotIndex {
                ZStack {
                    PlacementProgressDots(total: OnboardingStep.dotCount, currentIndex: dotIndex)

                    if canGoBack {
                        HStack {
                            Button {
                                goBack()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.ink)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Back")
                            Spacer()
                        }
                        .padding(.leading, Theme.Spacing.sm)
                    }
                }
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.md)
            }

            Group {
                switch step {
                case .welcome:
                    WelcomeView(viewModel: viewModel) { advance() }
                case .targetLanguage:
                    TargetLanguageView(viewModel: viewModel) { advance() }
                case .knowledgeLevel:
                    KnowledgeLevelView(viewModel: viewModel) { advance() }
                case .placement:
                    PlacementView(viewModel: viewModel) { advance() }
                case .placementResult:
                    PlacementResultView(viewModel: viewModel) { advance() }
                case .interests:
                    InterestsView(viewModel: viewModel) { advance() }
                case .goalReminder:
                    GoalReminderView(viewModel: viewModel) { advance() }
                case .meetTutor:
                    MeetTutorView(viewModel: viewModel) { finishOnboarding() }
                case .firstMessage:
                    FirstMessageView(viewModel: viewModel, router: router)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(
            ZStack {
                Theme.Colors.bg
                if step != .welcome {
                    OnboardingBackdrop()
                }
            }
            .ignoresSafeArea()
        )
        .overlay {
            if isSaving {
                ProgressView().tint(Theme.Colors.accent)
            }
        }
        .alert("Couldn't save your profile", isPresented: .constant(saveError != nil), actions: {
            Button("OK") { saveError = nil }
        }, message: {
            Text(saveError ?? "")
        })
        .task {
            EventsClient.shared.log("onboarding_step", props: ["step": String(describing: OnboardingStep.welcome)])
        }
    }

    /// No back nav on Welcome (nothing before it) or FirstMessage (a real
    /// /v1/chat call may already have fired — going back would be confusing).
    private var canGoBack: Bool {
        step != .welcome && step != .firstMessage
    }

    private func advance() {
        if step == .placement {
            EventsClient.shared.log("placement_done")
        }
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        EventsClient.shared.log("onboarding_step", props: ["step": String(describing: next)])
        withAnimation(Theme.Motion.spring) { step = next }
    }

    private func goBack() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        Theme.Haptic.chipTap()
        withAnimation(Theme.Motion.spring) { step = previous }
    }

    private func finishOnboarding() {
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                let profile = try await viewModel.completeOnboarding()
                router.profile = profile
                advance() // -> .firstMessage; router.onboardingCompleted() fires after that chat lands
            } catch {
                saveError = error.localizedDescription
            }
        }
    }
}
