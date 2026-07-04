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
    /// Not part of the canonical /shared ChatReply schema (that's the model's
    /// output contract) — the Worker adds this to its HTTP response envelope
    /// so the app can continue the same conversation on the next turn.
    let conversationID: String

    enum CodingKeys: String, CodingKey {
        case reply
        case replyTargetText = "reply_target_text"
        case corrections
        case suggestedReplies = "suggested_replies"
        case newVocab = "new_vocab"
        case conversationID = "conversation_id"
    }
}

// MARK: - Chat request (worker-specific; mirrors POST /v1/chat body, CLAUDE.md §6)

nonisolated struct ChatRequest: Encodable, Sendable {
    var conversationID: String?
    var scenarioID: String?
    var text: String

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case scenarioID = "scenario_id"
        case text
    }
}

// MARK: - TTS (worker-specific; mirrors POST /v1/tts, CLAUDE.md §6)

nonisolated struct TTSRequest: Encodable, Sendable {
    let text: String
    let lang: String
}

nonisolated struct TTSResponse: Decodable, Sendable {
    let audioURL: URL

    enum CodingKeys: String, CodingKey {
        case audioURL = "audio_url"
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

// MARK: - SRS review (CLAUDE.md §6 POST /v1/srs/review — batch, idempotent by client id)

nonisolated struct ReviewSubmission: Encodable, Sendable {
    let id: String
    let cardID: String
    let rating: Int // 1 again | 2 hard | 3 good | 4 easy
    let elapsedMs: Int
    let reviewedAt: Int

    enum CodingKeys: String, CodingKey {
        case id, rating
        case cardID = "card_id"
        case elapsedMs = "elapsed_ms"
        case reviewedAt = "reviewed_at"
    }
}

nonisolated struct ReviewResult: Decodable, Sendable {
    let cardID: String
    let nextDue: Int

    enum CodingKeys: String, CodingKey {
        case cardID = "card_id"
        case nextDue = "next_due"
    }
}

// MARK: - Daily (CLAUDE.md §6 GET /v1/daily, POST /v1/daily/complete)

nonisolated struct DailySet: Decodable, Sendable {
    let date: String
    let words: [WordCard]
    let completed: Bool
}

nonisolated struct DailyCompleteRequest: Encodable, Sendable {
    let date: String
}

nonisolated struct StreakUpdate: Decodable, Sendable {
    let streakCurrent: Int
    let streakBest: Int

    enum CodingKeys: String, CodingKey {
        case streakCurrent = "streak_current"
        case streakBest = "streak_best"
    }
}

// MARK: - Vision (camera lens, CLAUDE.md §9)

nonisolated struct VisionIdentifyRequest: Encodable, Sendable {
    let imageB64: String?
    let detectedLabel: String?

    enum CodingKeys: String, CodingKey {
        case imageB64 = "image_b64"
        case detectedLabel = "detected_label"
    }
}

// MARK: - Quiz (shared/schemas/quiz.json) — prompt/answer shape depends on `type`

nonisolated struct Quiz: Decodable, Identifiable, Sendable {
    enum Content: Sendable {
        case mcq(question: String, options: [String], correctIndex: Int)
        case match(left: [String], right: [String], correctPairs: [[Int]])
        case fillBlank(sentence: String, blankIndex: Int, correctWord: String)
        case order(tokens: [String], correctOrder: [Int])
    }

    let id: String
    let lang: String
    let difficulty: Int
    let wordIDs: [String]
    let content: Content

    enum CodingKeys: String, CodingKey {
        case id, lang, type, prompt, answer, difficulty
        case wordIDs = "word_ids"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        lang = try container.decode(String.self, forKey: .lang)
        difficulty = try container.decode(Int.self, forKey: .difficulty)
        wordIDs = try container.decodeIfPresent([String].self, forKey: .wordIDs) ?? []

        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "mcq":
            let prompt = try container.decode(MCQPrompt.self, forKey: .prompt)
            let answer = try container.decode(MCQAnswer.self, forKey: .answer)
            content = .mcq(question: prompt.question, options: prompt.options, correctIndex: answer.correctIndex)
        case "match":
            let prompt = try container.decode(MatchPrompt.self, forKey: .prompt)
            let answer = try container.decode(MatchAnswer.self, forKey: .answer)
            content = .match(left: prompt.left, right: prompt.right, correctPairs: answer.correctPairs)
        case "fillblank":
            let prompt = try container.decode(FillBlankPrompt.self, forKey: .prompt)
            let answer = try container.decode(FillBlankAnswer.self, forKey: .answer)
            content = .fillBlank(sentence: prompt.sentence, blankIndex: prompt.blankIndex, correctWord: answer.correctWord)
        case "order":
            let prompt = try container.decode(OrderPrompt.self, forKey: .prompt)
            let answer = try container.decode(OrderAnswer.self, forKey: .answer)
            content = .order(tokens: prompt.tokens, correctOrder: answer.correctOrder)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown quiz type: \(type)")
        }
    }

    private struct MCQPrompt: Decodable { let question: String; let options: [String] }
    private struct MCQAnswer: Decodable {
        let correctIndex: Int
        enum CodingKeys: String, CodingKey { case correctIndex = "correct_index" }
    }
    private struct MatchPrompt: Decodable { let left: [String]; let right: [String] }
    private struct MatchAnswer: Decodable {
        let correctPairs: [[Int]]
        enum CodingKeys: String, CodingKey { case correctPairs = "correct_pairs" }
    }
    private struct FillBlankPrompt: Decodable {
        let sentence: String
        let blankIndex: Int
        enum CodingKeys: String, CodingKey { case sentence; case blankIndex = "blank_index" }
    }
    private struct FillBlankAnswer: Decodable {
        let correctWord: String
        enum CodingKeys: String, CodingKey { case correctWord = "correct_word" }
    }
    private struct OrderPrompt: Decodable { let tokens: [String] }
    private struct OrderAnswer: Decodable {
        let correctOrder: [Int]
        enum CodingKeys: String, CodingKey { case correctOrder = "correct_order" }
    }
}
