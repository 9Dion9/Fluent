//
//  PlacementView.swift
//  Fluent
//
//  DESIGN.md §9.4 — 5-question staircase (or a 2-question warmup for
//  "Nothing yet" users), instant feedback per answer.
//

import SwiftUI

struct PlacementView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        if viewModel.isPlacementDoneAsWarmup {
            WarmupPlacementView(viewModel: viewModel, onContinue: onContinue)
        } else {
            StaircasePlacementView(viewModel: viewModel, onContinue: onContinue)
        }
    }
}

private struct StaircasePlacementView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    @State private var staircase: PlacementStaircaseViewModel
    @State private var feedback: Bool?

    init(viewModel: OnboardingViewModel, onContinue: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onContinue = onContinue
        _staircase = State(initialValue: PlacementStaircaseViewModel(lang: viewModel.targetLang))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Quick check — 5 little questions, 30 seconds.")
                .font(Theme.Font.title(20))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.xl)
                .padding(.horizontal, Theme.Spacing.xl)

            if let question = staircase.currentQuestion {
                VStack(spacing: Theme.Spacing.lg) {
                    Text(question.prompt)
                        .font(Theme.Font.body(20, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)

                    VStack(spacing: Theme.Spacing.md) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                            SelectableCard(title: option, isSelected: false) {
                                answer(index)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .disabled(feedback != nil)
                }
            }

            Spacer()
        }
        .overlay(alignment: .top) {
            if let feedback {
                Text(feedback ? "Nice! ✓" : "We'll get there")
                    .font(Theme.Font.body(15, weight: .semibold))
                    .foregroundStyle(feedback ? Theme.Colors.leaf : Theme.Colors.inkSoft)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Capsule().fill(Theme.Colors.surface).shadow(color: Theme.Colors.shadow, radius: 8))
                    .padding(.top, Theme.Spacing.lg)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.spring, value: feedback)
    }

    private func answer(_ index: Int) {
        let isCorrect = staircase.answer(index)
        feedback = isCorrect
        if isCorrect { Theme.Haptic.correctAnswer() } else { Theme.Haptic.wrongAnswer() }

        Task {
            try? await Task.sleep(for: .milliseconds(600))
            feedback = nil
            if staircase.isComplete {
                viewModel.placementLevel = staircase.resultLevel()
                viewModel.placementInsight = "You nailed word order — we'll grow your vocabulary."
                onContinue()
            }
        }
    }
}

private struct WarmupPlacementView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    @State private var index = 0
    @State private var feedback: Bool?
    private let questions: [WarmupQuestion]

    init(viewModel: OnboardingViewModel, onContinue: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onContinue = onContinue
        questions = PlacementContent.warmup(for: viewModel.targetLang)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Two quick ones to warm up.")
                .font(Theme.Font.title(20))
                .foregroundStyle(Theme.Colors.ink)
                .padding(.top, Theme.Spacing.xl)

            if index < questions.count {
                let question = questions[index]
                VStack(spacing: Theme.Spacing.lg) {
                    Text(question.prompt)
                        .font(Theme.Font.body(20, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)

                    VStack(spacing: Theme.Spacing.md) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { optionIndex, option in
                            SelectableCard(title: option, isSelected: false) {
                                answer(optionIndex, question: question)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .disabled(feedback != nil)
                }
            }

            Spacer()
        }
    }

    private func answer(_ selected: Int, question: WarmupQuestion) {
        _ = selected // warmup is always encouraging — everyone gets a win (DESIGN.md §9.4)
        feedback = true
        Theme.Haptic.correctAnswer()

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            feedback = nil
            index += 1
            if index >= questions.count {
                viewModel.placementLevel = "beginner"
                viewModel.placementInsight = "You're just getting started — that's the fun part."
                onContinue()
            }
        }
    }
}

#Preview {
    PlacementView(viewModel: OnboardingViewModel()) {}
}
