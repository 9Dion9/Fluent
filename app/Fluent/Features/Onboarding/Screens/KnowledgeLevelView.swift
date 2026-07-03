//
//  KnowledgeLevelView.swift
//  Fluent
//
//  DESIGN.md §9.3 — Four cards, sets the placement starting rung.
//

import SwiftUI

struct KnowledgeLevelView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    private let options: [(OnboardingViewModel.StartingKnowledge, String)] = [
        (.nothing, "Nothing yet"),
        (.few, "A few words"),
        (.getBy, "I can get by"),
        (.quiteABit, "Quite a bit"),
    ]

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.sm) {
                Text("How much do you know?")
                    .font(Theme.Font.title())
                    .foregroundStyle(Theme.Colors.ink)
                Text("No wrong answer — we'll fine-tune in a moment.")
                    .font(Theme.Font.caption())
                    .foregroundStyle(Theme.Colors.inkSoft)
            }
            .padding(.top, Theme.Spacing.xl)
            .multilineTextAlignment(.center)

            VStack(spacing: Theme.Spacing.md) {
                ForEach(options, id: \.0) { knowledge, title in
                    SelectableCard(title: title, isSelected: viewModel.startingKnowledge == knowledge) {
                        viewModel.startingKnowledge = knowledge
                        onContinue()
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
    }
}

#Preview {
    KnowledgeLevelView(viewModel: OnboardingViewModel()) {}
}
