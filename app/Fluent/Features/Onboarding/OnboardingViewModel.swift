//
//  OnboardingViewModel.swift
//  Fluent
//
//  Accumulates onboarding state across DESIGN.md §9's 9 screens, then PUTs
//  it as one profile update. The adaptive placement staircase lives here too.
//

import Foundation
import Observation

@Observable
final class OnboardingViewModel {
    // Screen 1-2
    var nativeLang = Locale.current.language.languageCode?.identifier ?? "en"
    var targetLang = "de"

    // Screen 3
    enum StartingKnowledge: String, CaseIterable {
        case nothing, few, getBy, quiteABit
    }
    var startingKnowledge: StartingKnowledge = .few

    // Screen 4-5 (placement)
    var placementLevel: String? // beginner | elementary | intermediate | advanced
    var placementInsight: String = ""

    // Screen 6
    var interests: [String] = []

    // Screen 7
    var dailyGoal = 10
    var reminderTime: String?

    // Screen 8
    var tutorPersona = "sunny"
    var tutorName = "Emma"

    let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    var isPlacementDoneAsWarmup: Bool { startingKnowledge == .nothing }

    /// Suggested tutor name per target language (DESIGN.md §9.8).
    static func suggestedTutorName(targetLang: String) -> String {
        targetLang == "de" ? "Emma" : "Mateo"
    }

    func completeOnboarding() async throws -> Profile {
        let update = ProfileUpdate(
            nativeLang: nativeLang,
            targetLang: targetLang,
            level: placementLevel ?? "beginner",
            interests: interests,
            tutorName: tutorName,
            tutorPersona: tutorPersona,
            tz: TimeZone.current.identifier,
            reminderTime: reminderTime,
            dailyGoal: dailyGoal
        )
        return try await apiClient.updateProfile(update)
    }
}

/// Staircase over `PlacementContent`: correct -> harder, miss -> easier
/// (DESIGN.md §9.4). Five questions, starts at the middle rung.
@Observable
final class PlacementStaircaseViewModel {
    private(set) var currentDifficulty = 3
    private(set) var questionsAnswered = 0
    private(set) var difficultiesSeen: [Int] = []
    private var askedQuestionIDs: Set<UUID> = []
    private let pool: [PlacementQuestion]

    let totalQuestions = 5

    init(lang: String) {
        pool = PlacementContent.staircase(for: lang)
    }

    var isComplete: Bool { questionsAnswered >= totalQuestions }

    var currentQuestion: PlacementQuestion? {
        let candidates = pool.filter { !askedQuestionIDs.contains($0.id) }
        let exactMatch = candidates.filter { $0.difficulty == currentDifficulty }
        let question = exactMatch.first ?? candidates.min {
            abs($0.difficulty - currentDifficulty) < abs($1.difficulty - currentDifficulty)
        }
        return question
    }

    /// Returns whether the answer was correct.
    @discardableResult
    func answer(_ selectedIndex: Int) -> Bool {
        guard let question = currentQuestion else { return false }
        askedQuestionIDs.insert(question.id)
        difficultiesSeen.append(question.difficulty)
        questionsAnswered += 1

        let isCorrect = selectedIndex == question.correctIndex
        currentDifficulty = isCorrect
            ? min(5, currentDifficulty + 1)
            : max(1, currentDifficulty - 1)
        return isCorrect
    }

    /// Maps the average difficulty reached to CLAUDE.md's level enum.
    func resultLevel() -> String {
        let average = difficultiesSeen.isEmpty
            ? 1.0
            : Double(difficultiesSeen.reduce(0, +)) / Double(difficultiesSeen.count)
        switch average {
        case ..<1.5: return "beginner"
        case ..<2.5: return "elementary"
        case ..<4.0: return "intermediate"
        default: return "advanced"
        }
    }
}
