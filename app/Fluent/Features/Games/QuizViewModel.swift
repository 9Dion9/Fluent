//
//  QuizViewModel.swift
//  Fluent
//
//  Drives the games loop (CLAUDE.md §6 GET /v1/quiz/next; DESIGN.md §7-8).
//  Answers are checked client-side against the quiz's own answer payload —
//  there's no submit endpoint in the API contract, quizzes are practice,
//  not synced state (unlike SRS reviews).
//

import Foundation

@Observable
final class QuizViewModel {
    private(set) var currentQuiz: Quiz?
    private(set) var isLoading = true
    var errorMessage: String?

    private let apiClient: APIClient
    private let types: [String]

    init(apiClient: APIClient = .shared, types: [String] = []) {
        self.apiClient = apiClient
        self.types = types
    }

    func loadNext() async {
        isLoading = true
        errorMessage = nil
        do {
            currentQuiz = try await apiClient.getNextQuiz(types: types)
        } catch let error as APIError {
            currentQuiz = nil
            errorMessage = error.errorDescription
        } catch {
            currentQuiz = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
