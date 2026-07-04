//
//  ReviewSessionView.swift
//  Fluent
//
//  DESIGN.md §8 "Review session" — one card centered, four rating buttons
//  colored ink->leaf, progress bar on top, celebratory summary at the end.
//

import SwiftUI

struct ReviewSessionView: View {
    @State private var viewModel = ReviewViewModel()
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                if viewModel.isLoading {
                    ProgressView().tint(Theme.Colors.accent)
                } else if viewModel.isFinished {
                    summaryView
                } else if let card = viewModel.currentCard {
                    progressBar
                    Spacer()
                    WordCardView(word: card.word)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .id(card.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                    Spacer()
                    ratingButtons
                }
            }
            .padding(.vertical, Theme.Spacing.xl)
            .animation(Theme.Motion.spring, value: viewModel.currentIndex)

            ConfettiView(isActive: $showConfetti)
        }
        .navigationTitle("Review")
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.isFinished) {
            if viewModel.isFinished && viewModel.reviewedCount > 0 {
                showConfetti = true
            }
        }
    }

    private var progressBar: some View {
        ProgressView(value: viewModel.progress)
            .tint(Theme.Colors.accent)
            .padding(.horizontal, Theme.Spacing.xl)
    }

    private var ratingButtons: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ratingButton(title: "Again", rating: 1, color: Theme.Colors.ink)
            ratingButton(title: "Hard", rating: 2, color: Theme.Colors.honey)
            ratingButton(title: "Good", rating: 3, color: Theme.Colors.sky)
            ratingButton(title: "Easy", rating: 4, color: Theme.Colors.leaf)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func ratingButton(title: String, rating: Int, color: Color) -> some View {
        Button {
            Task { await viewModel.rate(rating) }
        } label: {
            Text(title)
                .font(Theme.Font.body(15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous).fill(color))
        }
        .buttonStyle(.plain)
    }

    private var summaryView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            if viewModel.reviewedCount > 0 {
                ProgressRing(progress: 1, size: 96)
                Text("\(viewModel.reviewedCount) word\(viewModel.reviewedCount == 1 ? "" : "s") strengthened 🎉")
                    .font(Theme.Font.title(20))
                    .foregroundStyle(Theme.Colors.ink)
                    .multilineTextAlignment(.center)
            } else {
                EmptyStateView(message: "Nothing due for review right now — check back later.")
            }

            Button {
                showConfetti = false
                Task { await viewModel.reload() }
            } label: {
                Text("Done")
                    .font(Theme.Font.body(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous).fill(Theme.Colors.accent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(Theme.Spacing.xl)
    }
}

#Preview {
    NavigationStack {
        ReviewSessionView()
    }
}
