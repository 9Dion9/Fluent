//
//  QuizContainerView.swift
//  Fluent
//
//  Dispatches to the right mini-game per quiz type (DESIGN.md §7), shows a
//  brief correct/incorrect toast, then loads the next quiz.
//

import SwiftUI

struct QuizContainerView: View {
    @State private var viewModel = QuizViewModel()
    @State private var feedback: Bool?

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView().tint(Theme.Colors.accent)
            } else if let quiz = viewModel.currentQuiz {
                gameView(for: quiz)
                    .id(quiz.id)
            } else {
                EmptyStateView(
                    message: viewModel.errorMessage ?? "No games available yet for your level.",
                    actionTitle: "Try again"
                ) {
                    Task { await viewModel.loadNext() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.bg)
        .navigationTitle("Games")
        .toast(isPresented: Binding(get: { feedback != nil }, set: { if !$0 { feedback = nil } }), message: feedback == true ? "Correct! ✓" : "Not quite — next one", systemImage: feedback == true ? "checkmark.circle.fill" : "arrow.right.circle")
        .task {
            await viewModel.loadNext()
        }
    }

    @ViewBuilder
    private func gameView(for quiz: Quiz) -> some View {
        switch quiz.content {
        case .mcq(let question, let options, let correctIndex):
            MCQGameView(question: question, options: options, correctIndex: correctIndex, onAnswer: handleAnswer)
        case .match(let left, let right, let correctPairs):
            MatchGameView(left: left, right: right, correctPairs: correctPairs, onComplete: handleAnswer)
        case .fillBlank(let sentence, let blankIndex, let correctWord):
            FillBlankGameView(sentence: sentence, blankIndex: blankIndex, correctWord: correctWord, onAnswer: handleAnswer)
        case .order(let tokens, let correctOrder):
            OrderGameView(tokens: tokens, correctOrder: correctOrder, onAnswer: handleAnswer)
        }
    }

    private func handleAnswer(_ isCorrect: Bool) {
        Theme.Haptic.chipTap()
        feedback = isCorrect
        if isCorrect {
            Theme.Haptic.correctAnswer()
        } else {
            Theme.Haptic.wrongAnswer()
        }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            await viewModel.loadNext()
        }
    }
}

#Preview {
    NavigationStack {
        QuizContainerView()
    }
}
