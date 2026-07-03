//
//  MeetTutorView.swift
//  Fluent
//
//  DESIGN.md §9.8 — three persona cards with a sample line each, then a
//  pre-filled editable name field. Button: "Meet {name}".
//

import SwiftUI

struct MeetTutorView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    @FocusState private var nameFieldFocused: Bool

    private let personas: [(id: String, title: String, sample: String, emoji: String)] = [
        ("sunny", "Sunny", "Ooh, this'll be fun!", "☀️"),
        ("dry", "Dry", "I promise this hurts less than the gym.", "🌵"),
        ("professor", "Professor", "Every word has a story — let's find yours.", "🎓"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                Text("Meet your tutor")
                    .font(Theme.Font.title())
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.top, Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.md) {
                    ForEach(personas, id: \.id) { persona in
                        SelectableCard(
                            title: persona.title,
                            subtitle: "\"\(persona.sample)\"",
                            emoji: persona.emoji,
                            isSelected: viewModel.tutorPersona == persona.id
                        ) {
                            viewModel.tutorPersona = persona.id
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Name your tutor")
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.Colors.inkSoft)
                    TextField("Tutor name", text: $viewModel.tutorName)
                        .focused($nameFieldFocused)
                        .font(Theme.Font.body(17, weight: .semibold))
                        .padding(Theme.Spacing.md)
                        .frame(minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .fill(Theme.Colors.surface)
                        )
                }
                .padding(.horizontal, Theme.Spacing.xl)

                PrimaryButton(
                    title: "Meet \(viewModel.tutorName.isEmpty ? "your tutor" : viewModel.tutorName)",
                    isEnabled: !viewModel.tutorName.trimmingCharacters(in: .whitespaces).isEmpty,
                    action: onContinue
                )
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }
}

#Preview {
    MeetTutorView(viewModel: OnboardingViewModel()) {}
}
