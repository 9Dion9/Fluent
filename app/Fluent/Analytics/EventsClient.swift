//
//  EventsClient.swift
//  Fluent
//
//  Batches product analytics to POST /v1/events, flushing on background
//  (CLAUDE.md §14). Every `log()` call queues to SwiftData FIRST, then
//  attempts an immediate flush — so a dropped network call never loses an
//  event, it just waits for the next flush (app launch, foreground, or the
//  next `log()`). Fire-and-forget: callers never await network I/O.
//
//  Tracks the funnel that decides everything (CLAUDE.md §14):
//  onboarding_step, placement_done, first_chat_turn, daily_completed,
//  review_done, camera_snap, streak_day.
//

import Foundation

@Observable
final class EventsClient {
    static let shared = EventsClient()

    private let apiClient: APIClient
    private let offlineStore: OfflineStore

    init(apiClient: APIClient = .shared, offlineStore: OfflineStore = .shared) {
        self.apiClient = apiClient
        self.offlineStore = offlineStore
    }

    func log(_ name: String, props: [String: String]? = nil) {
        offlineStore.queuePendingEvent(name: name, props: props, at: Int(Date().timeIntervalSince1970 * 1000))
        Task { await flush() }
    }

    /// Call on launch and on foreground — picks up anything queued while
    /// offline or not yet authenticated.
    func flush() async {
        let pending = offlineStore.pendingEvents()
        guard !pending.isEmpty else { return }

        let payloads = pending.map { row in
            EventPayload(name: row.name, props: row.propsJSON.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }, at: row.at)
        }

        do {
            try await apiClient.postEvents(payloads)
            offlineStore.removePendingEvents(ids: Set(pending.map(\.id)))
        } catch {
            // Offline, unauthenticated, or gateway-adjacent failure — stays
            // queued, tried again on the next log()/foreground.
        }
    }
}
