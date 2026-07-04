//
//  ReviewViewModel.swift
//  Fluent
//
//  Drives the SRS review session (CLAUDE.md §6, §10; DESIGN.md §8). Offline
//  degradation (CLAUDE.md §13): the due queue is cached in SwiftData so a
//  session can start with no network, and a review that fails to sync is
//  queued locally and flushed on the next successful load — never silently
//  lost. Server FSRS state always wins after sync (CLAUDE.md §10): the local
//  cache is a read-through/write-behind convenience, never a second truth.
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
    /// Surfaced so the UI can show a small "you're offline, reviews will sync
    /// later" hint rather than pretending everything's live.
    private(set) var isOffline = false

    private let apiClient: APIClient
    private let offlineStore: OfflineStore
    private var cardStartedAt = Date()

    var currentCard: Card? {
        currentIndex < cards.count ? cards[currentIndex] : nil
    }

    var progress: Double {
        cards.isEmpty ? 0 : Double(currentIndex) / Double(cards.count)
    }

    init(apiClient: APIClient = .shared, offlineStore: OfflineStore = .shared) {
        self.apiClient = apiClient
        self.offlineStore = offlineStore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        await flushPendingReviews()

        do {
            cards = try await apiClient.getDueCards()
            isOffline = false
            offlineStore.cacheDueCards(cards)
        } catch {
            // Offline/gateway-down degradation: fall back to whatever was
            // cached from the last successful load instead of an empty/error
            // screen — CLAUDE.md §13: "Offline -> review cached due queue."
            let cached = offlineStore.cachedDueCards()
            if !cached.isEmpty {
                cards = cached
                isOffline = true
            } else {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }

        isLoading = false
        cardStartedAt = Date()
        isFinished = cards.isEmpty
    }

    /// Re-sends any reviews that failed to sync during a previous offline
    /// session. Best-effort — a review still stuck after this just stays
    /// queued for the next `load()`.
    private func flushPendingReviews() async {
        let pending = offlineStore.pendingReviews()
        guard !pending.isEmpty else { return }
        do {
            _ = try await apiClient.submitReviews(pending)
            offlineStore.removePendingReviews(ids: Set(pending.map(\.id)))
        } catch {
            // Still offline / gateway down — stays queued, tried again next load().
        }
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
            EventsClient.shared.log("review_done", props: ["count": String(reviewedCount)])
        }

        do {
            _ = try await apiClient.submitReviews([submission])
        } catch {
            // Non-fatal: the session keeps moving regardless. Queue it rather
            // than dropping it silently — flushed on the next load() (CLAUDE.md
            // §13: "queue reviews ... for sync").
            offlineStore.queuePendingReview(submission)
        }
    }
}
