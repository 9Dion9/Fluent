//
//  PlacementResultView.swift
//  Fluent
//
//  DESIGN.md §9.5 — first celebration. "This is the screen people screenshot."
//

import SwiftUI

struct PlacementResultView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    @State private var showConfetti = true

    private var levelDisplayName: String {
        switch viewModel.placementLevel {
        case "elementary": "Elementary"
        case "intermediate": "Intermediate"
        case "advanced": "Advanced"
        default: "Beginner"
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                VStack(spacing: Theme.Spacing.md) {
                    Text("You're starting at")
                        .font(Theme.Font.body(17))
                        .foregroundStyle(Theme.Colors.inkSoft)

                    Text(levelDisplayName)
                        .font(Theme.Font.display(40))
                        .foregroundStyle(Theme.Colors.accent)

                    Text("You already know more than you think.")
                        .font(Theme.Font.body(17))
                        .foregroundStyle(Theme.Colors.ink)
                        .multilineTextAlignment(.center)

                    Text(viewModel.placementInsight)
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.top, Theme.Spacing.sm)
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer()

                PrimaryButton(title: "Continue", action: onContinue)
                    .padding(.horizontal, Theme.Spacing.xl)
            }
            .padding(.bottom, Theme.Spacing.xl)

            ConfettiView(isActive: $showConfetti)
        }
    }
}

#Preview {
    let vm = OnboardingViewModel()
    return PlacementResultView(viewModel: vm) {}
}
