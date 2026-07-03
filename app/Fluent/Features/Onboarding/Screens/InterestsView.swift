//
//  InterestsView.swift
//  Fluent
//
//  DESIGN.md §9.6 — multi-select chips, min 2, springy selection.
//

import SwiftUI

struct InterestsView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    private let allInterests: [(String, String)] = [
        ("travel", "Travel ✈️"), ("food", "Food 🥐"), ("work", "Work 💼"),
        ("daily life", "Daily life ☕"), ("culture", "Culture 🎭"), ("sport", "Sport ⚽"),
        ("relationships", "Relationships 💛"), ("music", "Music 🎧"),
    ]

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: Theme.Spacing.sm)]

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.sm) {
                Text("What do you want to talk about?")
                    .font(Theme.Font.title())
                    .foregroundStyle(Theme.Colors.ink)
                Text("Your chats and words will be about these.")
                    .font(Theme.Font.caption())
                    .foregroundStyle(Theme.Colors.inkSoft)
            }
            .multilineTextAlignment(.center)
            .padding(.top, Theme.Spacing.xl)
            .padding(.horizontal, Theme.Spacing.xl)

            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(allInterests, id: \.0) { key, label in
                    SelectableChip(title: label, isSelected: viewModel.interests.contains(key)) {
                        toggle(key)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()

            PrimaryButton(title: "Continue", isEnabled: viewModel.interests.count >= 2, action: onContinue)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.bottom, Theme.Spacing.xl)
    }

    private func toggle(_ key: String) {
        withAnimation(Theme.Motion.spring) {
            if let index = viewModel.interests.firstIndex(of: key) {
                viewModel.interests.remove(at: index)
            } else {
                viewModel.interests.append(key)
            }
        }
    }
}

#Preview {
    InterestsView(viewModel: OnboardingViewModel()) {}
}
