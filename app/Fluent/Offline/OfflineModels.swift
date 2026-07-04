//
//  OfflineModels.swift
//  Fluent
//
//  SwiftData-backed offline cache (CLAUDE.md §10, §13's degradation matrix:
//  "Offline -> review cached due queue, cached daily words, cached audio;
//  queue reviews + events for sync"). Server FSRS state always wins after
//  sync (CLAUDE.md §10) — these caches are read-through/write-behind, never
//  a second source of truth.
//

import Foundation
import SwiftData

@Model
final class CachedDueCard {
    @Attribute(.unique) var cardID: String
    var wordJSON: Data
    var dueAt: Int
    var stability: Double?
    var difficulty: Double?
    var reps: Int
    var lapses: Int
    var state: String
    var lastReviewAt: Int?

    init(_ card: Card) {
        cardID = card.cardID
        wordJSON = (try? JSONEncoder().encode(card.word)) ?? Data()
        dueAt = card.dueAt
        stability = card.stability
        difficulty = card.difficulty
        reps = card.reps
        lapses = card.lapses
        state = card.state
        lastReviewAt = card.lastReviewAt
    }

    var asCard: Card? {
        guard let word = try? JSONDecoder().decode(WordCard.self, from: wordJSON) else { return nil }
        return Card(
            cardID: cardID, word: word, dueAt: dueAt, stability: stability, difficulty: difficulty,
            reps: reps, lapses: lapses, state: state, lastReviewAt: lastReviewAt
        )
    }
}

@Model
final class CachedDailySet {
    @Attribute(.unique) var date: String
    var wordsJSON: Data
    var completed: Bool

    init(_ set: DailySet) {
        date = set.date
        wordsJSON = (try? JSONEncoder().encode(set.words)) ?? Data()
        completed = set.completed
    }

    var asDailySet: DailySet? {
        guard let words = try? JSONDecoder().decode([WordCard].self, from: wordsJSON) else { return nil }
        return DailySet(date: date, words: words, completed: completed)
    }
}

/// Queued when `/v1/srs/review` fails while offline — flushed on the next
/// successful sync. `id` is the client-generated review id, so re-submitting
/// after a partial-failure is safe (Worker upserts idempotently by that id).
@Model
final class PendingReview {
    @Attribute(.unique) var id: String
    var cardID: String
    var rating: Int
    var elapsedMs: Int
    var reviewedAt: Int

    init(_ submission: ReviewSubmission) {
        id = submission.id
        cardID = submission.cardID
        rating = submission.rating
        elapsedMs = submission.elapsedMs
        reviewedAt = submission.reviewedAt
    }

    var asSubmission: ReviewSubmission {
        ReviewSubmission(id: id, cardID: cardID, rating: rating, elapsedMs: elapsedMs, reviewedAt: reviewedAt)
    }
}

/// Queued analytics events (CLAUDE.md §14) when `/v1/events` fails or the app
/// is offline — flushed on next launch/foreground. Fire-and-forget: dropping
/// these after too many retries is acceptable, losing user-facing data isn't.
@Model
final class PendingEvent {
    @Attribute(.unique) var id: String
    var name: String
    var propsJSON: Data?
    var at: Int

    init(name: String, props: [String: String]?, at: Int) {
        id = UUID().uuidString
        self.name = name
        propsJSON = props.flatMap { try? JSONEncoder().encode($0) }
        self.at = at
    }
}
