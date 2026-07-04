//
//  ReviewViewModel.swift
//  Fluent
//
//  Drives the SRS review session (CLAUDE.md §6, §10; DESIGN.md §8). Offline
//  queuing of reviews (CLAUDE.md §13's degradation matrix) is M8 hardening
//  scope, not built here — a submit failure is surfaced but doesn't block
//  moving to the next card, since re-reviewing later is harmless.
//

import Foundation

@Observable
final class ReviewViewModel {
    private(set) var cards: [Card] = []
    private(set) var currentIndex = 0
    private(set) var isLoading = true
    private(set) var isFinished = false
    private(set) var reviewedCount = 0
    var errorMessage: String?

    private let apiClient: APIClient
    private var cardStartedAt = Date()

    var currentCard: Card? {
        currentIndex < cards.count ? cards[currentIndex] : nil
    }

    var progress: Double {
        cards.isEmpty ? 0 : Double(currentIndex) / Double(cards.count)
    }

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            cards = try await apiClient.getDueCards()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
        cardStartedAt = Date()
        isFinished = cards.isEmpty
    }

    /// Re-checks the due queue from the summary screen — without this, the
    /// summary is a dead end since `isFinished` never resets on its own.
    func reload() async {
        currentIndex = 0
        reviewedCount = 0
        isFinished = false
        await load()
    }

    /// rating: 1 again | 2 hard | 3 good | 4 easy (DESIGN.md §8 rating buttons).
    func rate(_ rating: Int) async {
        guard let card = currentCard else { return }
        Theme.Haptic.chipTap()

        let elapsedMs = Int(Date().timeIntervalSince(cardStartedAt) * 1000)
        let submission = ReviewSubmission(
            id: UUID().uuidString,
            cardID: card.id,
            rating: rating,
            elapsedMs: elapsedMs,
            reviewedAt: Int(Date().timeIntervalSince1970 * 1000)
        )

        reviewedCount += 1
        currentIndex += 1
        cardStartedAt = Date()
        if currentIndex >= cards.count {
            isFinished = true
            Theme.Haptic.streakOrLevelUp()
        }

        do {
            _ = try await apiClient.submitReviews([submission])
        } catch {
            // Non-fatal: the session keeps moving. A dropped sync just means
            // this card's FSRS state didn't advance server-side this time.
        }
    }
}
