//
//  DailyWordsViewModel.swift
//  Fluent
//

import Foundation

@Observable
final class DailyWordsViewModel {
    private(set) var dailySet: DailySet?
    private(set) var isLoading = true
    private(set) var streakCurrent: Int?
    var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            dailySet = try await apiClient.getDaily()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func markComplete() async {
        guard let date = dailySet?.date else { return }
        do {
            let streak = try await apiClient.completeDaily(date: date)
            streakCurrent = streak.streakCurrent
            Theme.Haptic.streakOrLevelUp()
            await load()
        } catch {
            // Non-fatal — user can retry via the button, which is still visible.
        }
    }
}
