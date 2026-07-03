//
//  TargetLanguageView.swift
//  Fluent
//
//  DESIGN.md §9.2 — Two big flag-free cards (objects, not flags). Tap = select + advance.
//

import SwiftUI

struct TargetLanguageView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("What do you want to learn?")
                .font(Theme.Font.title())
                .foregroundStyle(Theme.Colors.ink)
                .padding(.top, Theme.Spacing.xl)

            VStack(spacing: Theme.Spacing.md) {
                SelectableCard(
                    title: "German",
                    subtitle: "spoken by 130M people",
                    emoji: "🥨",
                    isSelected: viewModel.targetLang == "de"
                ) {
                    viewModel.targetLang = "de"
                    viewModel.tutorName = OnboardingViewModel.suggestedTutorName(targetLang: "de")
                    onContinue()
                }

                SelectableCard(
                    title: "English",
                    subtitle: "the world's handshake",
                    emoji: "☕",
                    isSelected: viewModel.targetLang == "en"
                ) {
                    viewModel.targetLang = "en"
                    viewModel.tutorName = OnboardingViewModel.suggestedTutorName(targetLang: "en")
                    onContinue()
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
    }
}

#Preview {
    TargetLanguageView(viewModel: OnboardingViewModel()) {}
}
