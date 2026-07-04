//
//  OfflineStore.swift
//  Fluent
//
//  Single point of contact for the SwiftData offline cache — view models
//  don't touch ModelContext directly. Runs on MainActor (SwiftData's
//  ModelContext isn't Sendable across threads, and this project already
//  defaults every declaration to MainActor).
//

import Foundation
import SwiftData

@MainActor
final class OfflineStore {
    static let shared = OfflineStore()

    let container: ModelContainer

    private init() {
        // A broken/incompatible on-disk store (e.g. after a schema change
        // during development) should never crash launch — offline caching
        // degrading to "no cache" is acceptable; the app itself must not die.
        do {
            container = try ModelContainer(for: CachedDueCard.self, CachedDailySet.self, PendingReview.self, PendingEvent.self)
        } catch {
            container = (try? ModelContainer(
                for: CachedDueCard.self, CachedDailySet.self, PendingReview.self, PendingEvent.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )) ?? {
                fatalError("Couldn't create even an in-memory ModelContainer: \(error)")
            }()
        }
    }

    private var context: ModelContext { container.mainContext }

    // MARK: Due cards

    func cacheDueCards(_ cards: [Card]) {
        try? context.delete(model: CachedDueCard.self)
        for card in cards { context.insert(CachedDueCard(card)) }
        try? context.save()
    }

    func cachedDueCards() -> [Card] {
        let rows = (try? context.fetch(FetchDescriptor<CachedDueCard>())) ?? []
        return rows.compactMap(\.asCard)
    }

    // MARK: Daily set

    func cacheDailySet(_ set: DailySet) {
        let targetDate = set.date // #Predicate can't resolve a member access on a captured struct directly
        let existing = try? context.fetch(FetchDescriptor<CachedDailySet>(predicate: #Predicate { $0.date == targetDate }))
        existing?.forEach { context.delete($0) }
        context.insert(CachedDailySet(set))
        try? context.save()
    }

    func cachedDailySet(for date: String) -> DailySet? {
        let rows = try? context.fetch(FetchDescriptor<CachedDailySet>(predicate: #Predicate { $0.date == date }))
        return rows?.first?.asDailySet
    }

    /// Offline fallback when we can't even ask the server what "today" is in
    /// the user's tz — whatever was last cached beats an empty screen.
    func mostRecentCachedDailySet() -> DailySet? {
        var descriptor = FetchDescriptor<CachedDailySet>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.asDailySet
    }

    // MARK: Pending reviews (offline sync queue)

    func queuePendingReview(_ submission: ReviewSubmission) {
        context.insert(PendingReview(submission))
        try? context.save()
    }

    func pendingReviews() -> [ReviewSubmission] {
        let rows = (try? context.fetch(FetchDescriptor<PendingReview>())) ?? []
        return rows.map(\.asSubmission)
    }

    func removePendingReviews(ids: Set<String>) {
        let rows = (try? context.fetch(FetchDescriptor<PendingReview>())) ?? []
        for row in rows where ids.contains(row.id) { context.delete(row) }
        try? context.save()
    }

    // MARK: Pending events (offline sync queue)

    func queuePendingEvent(name: String, props: [String: String]?, at: Int) {
        context.insert(PendingEvent(name: name, props: props, at: at))
        try? context.save()
    }

    func pendingEvents() -> [PendingEvent] {
        (try? context.fetch(FetchDescriptor<PendingEvent>())) ?? []
    }

    func removePendingEvents(ids: Set<String>) {
        for row in pendingEvents() where ids.contains(row.id) { context.delete(row) }
        try? context.save()
    }
}
