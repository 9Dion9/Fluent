//
//  DailyWordsView.swift
//  Fluent
//
//  CLAUDE.md §0 "Daily 10 new words" — first real UI for the daily set;
//  previously these words were silently added to the deck with no way to see
//  them. Simple list + a completion action; the celebration ring/confetti
//  treatment DESIGN.md envisions for the full Home dashboard lands with M8's
//  Today tab, not duplicated here.
//

import SwiftUI

struct DailyWordsView: View {
    @State private var viewModel = DailyWordsViewModel()
    @State private var showConfetti = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if viewModel.isLoading {
                    ProgressView().tint(Theme.Colors.accent).padding(.top, Theme.Spacing.xxl)
                } else if let dailySet = viewModel.dailySet {
                    Text(dailySet.date)
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .padding(.top, Theme.Spacing.lg)

                    ForEach(dailySet.words) { word in
                        WordCardView(word: word)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)

                    if dailySet.completed {
                        Text("Today's set complete ✓")
                            .font(Theme.Font.body(15, weight: .semibold))
                            .foregroundStyle(Theme.Colors.leaf)
                            .padding(.vertical, Theme.Spacing.lg)
                    } else {
                        PrimaryButton(title: "Mark today's words done") {
                            Task {
                                await viewModel.markComplete()
                                showConfetti = true
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.lg)
                    }
                } else {
                    EmptyStateView(
                        message: viewModel.errorMessage ?? "Couldn't load today's words.",
                        actionTitle: "Try again"
                    ) {
                        Task { await viewModel.load() }
                    }
                    .padding(.top, Theme.Spacing.xxl)
                }
            }
        }
        .background(Theme.Colors.bg)
        .overlay { ConfettiView(isActive: $showConfetti) }
        .navigationTitle("Daily Words")
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        DailyWordsView()
    }
}
