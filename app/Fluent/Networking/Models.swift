//
//  Models.swift
//  Fluent
//
//  Codable mirrors of /shared/schemas/*.json — the JSON Schema is canonical
//  (CLAUDE.md §4). If a contract changes, change /shared first, then this
//  file, in the same commit. FluentTests has a decoding test per schema
//  fixture.
//
//  Every type here is `nonisolated` — the project defaults every declaration
//  to `@MainActor` (SWIFT_DEFAULT_ACTOR_ISOLATION), but these are plain,
//  Sendable data types decoded/encoded from inside `actor APIClient`'s own
//  isolation domain, so they must opt out of the MainActor default.
//

import Foundation

// MARK: - WordCard (shared/schemas/word-card.json)

nonisolated struct WordCard: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let lang: String
    let word: String
    let translation: String
    let pos: String?
    let gender: String?
    let ipa: String?
    let cefr: String
    let topics: [String]?
    let example: String?
    let exampleTranslation: String?
    let audioURL: URL?
    let source: String?
    let verified: Bool?

    enum CodingKeys: String, CodingKey {
        case id, lang, word, translation, pos, gender, ipa, cefr, topics, example, source, verified
        case exampleTranslation = "example_translation"
        case audioURL = "audio_url"
    }

    /// Maps the DB `der`/`die`/`das` article string to the gender-color token (DESIGN.md §4).
    /// `nil` for genderless languages/POS — the neutral POS chip renders instead.
    var genderColor: Theme.GenderColor? {
        switch gender {
        case "der", "el": .masculine
        case "die", "la": .feminine
        case "das": .neuter
        default: nil
        }
    }
}

// MARK: - Card (shared/schemas/card.json) — one row of the FSRS due queue

nonisolated struct Card: Codable, Identifiable, Hashable, Sendable {
    let cardID: String
    let word: WordCard
    let dueAt: Int
    let stability: Double?
    let difficulty: Double?
    let reps: Int
    let lapses: Int
    let state: String
    let lastReviewAt: Int?

    var id: String { cardID }

    enum CodingKeys: String, CodingKey {
        case word, reps, lapses, state
        case cardID = "card_id"
        case dueAt = "due_at"
        case stability, difficulty
        case lastReviewAt = "last_review_at"
    }
}

// MARK: - ChatReply (shared/schemas/chat-reply.json)

nonisolated struct ChatReply: Codable, Hashable, Sendable {
    nonisolated struct Correction: Codable, Hashable, Sendable {
        let original: String
        let corrected: String
        let explanation: String
    }

    nonisolated struct NewVocab: Codable, Hashable, Sendable {
        let word: String
        let translation: String
        let example: String
    }

    let reply: String
    let replyTargetText: String
    let corrections: [Correction]
    let suggestedReplies: [String]
    let newVocab: [NewVocab]

    enum CodingKeys: String, CodingKey {
        case reply
        case replyTargetText = "reply_target_text"
        case corrections
        case suggestedReplies = "suggested_replies"
        case newVocab = "new_vocab"
    }
}

// MARK: - Scenario (shared/schemas/scenario.json)

nonisolated struct Scenario: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let lang: String
    let title: String
    let emoji: String?
    let minLevel: String
    let seedPrompt: String
    let focusWordIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case id, lang, title, emoji
        case minLevel = "min_level"
        case seedPrompt = "seed_prompt"
        case focusWordIDs = "focus_word_ids"
    }
}

// MARK: - Error contract (shared/schemas/error.json)

nonisolated struct APIErrorResponse: Codable, Sendable {
    nonisolated struct ErrorBody: Codable, Sendable {
        let code: String
        let message: String
        let retryable: Bool
    }

    let error: ErrorBody
}

// MARK: - Worker-specific (not in /shared — Fluent's own auth/profile contract)

nonisolated struct DeviceAuthResponse: Codable, Sendable {
    let userID: String
    let token: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case token
    }
}

nonisolated struct Profile: Codable, Equatable, Sendable {
    let id: String
    var nativeLang: String
    var targetLang: String
    var level: String
    var interests: [String]
    var tutorName: String
    var tutorPersona: String
    var tz: String
    var reminderTime: String?
    var dailyGoal: Int
    let streakCurrent: Int
    let streakBest: Int
    let streakFreezes: Int

    enum CodingKeys: String, CodingKey {
        case id, level, interests, tz
        case nativeLang = "native_lang"
        case targetLang = "target_lang"
        case tutorName = "tutor_name"
        case tutorPersona = "tutor_persona"
        case reminderTime = "reminder_time"
        case dailyGoal = "daily_goal"
        case streakCurrent = "streak_current"
        case streakBest = "streak_best"
        case streakFreezes = "streak_freezes"
    }
}

nonisolated struct ProfileUpdate: Codable, Sendable {
    var nativeLang: String
    var targetLang: String
    var level: String
    var interests: [String]
    var tutorName: String
    var tutorPersona: String
    var tz: String
    var reminderTime: String?
    var dailyGoal: Int

    enum CodingKeys: String, CodingKey {
        case level, interests, tz
        case nativeLang = "native_lang"
        case targetLang = "target_lang"
        case tutorName = "tutor_name"
        case tutorPersona = "tutor_persona"
        case reminderTime = "reminder_time"
        case dailyGoal = "daily_goal"
    }
}
