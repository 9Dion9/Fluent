//
//  DailyWordsViewModel.swift
//  Fluent
//
//  Offline degradation (CLAUDE.md §13): "Offline -> ... cached daily words."
//

import Foundation

@Observable
final class DailyWordsViewModel {
    private(set) var dailySet: DailySet?
    private(set) var isLoading = true
    private(set) var streakCurrent: Int?
    private(set) var isOffline = false
    var errorMessage: String?

    private let apiClient: APIClient
    private let offlineStore: OfflineStore

    init(apiClient: APIClient = .shared, offlineStore: OfflineStore = .shared) {
        self.apiClient = apiClient
        self.offlineStore = offlineStore
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let daily = try await apiClient.getDaily()
            dailySet = daily
            isOffline = false
            offlineStore.cacheDailySet(daily)
        } catch {
            if let cached = offlineStore.mostRecentCachedDailySet() {
                dailySet = cached
                isOffline = true
            } else if let apiError = error as? APIError {
                errorMessage = apiError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    func markComplete() async {
        guard let date = dailySet?.date else { return }
        do {
            let streak = try await apiClient.completeDaily(date: date)
            streakCurrent = streak.streakCurrent
            Theme.Haptic.streakOrLevelUp()
            EventsClient.shared.log("daily_completed")
            EventsClient.shared.log("streak_day", props: ["streak_current": String(streak.streakCurrent)])
            await load()
        } catch {
            // Non-fatal — user can retry via the button, which is still visible.
        }
    }
}
