//
//  PlacementContent.swift
//  Fluent
//
//  Static placement-quiz seed. The real quiz bank (content_words + quizzes,
//  Wiktionary-sourced per CLAUDE.md §3) doesn't exist until the M5 batch
//  pipeline runs. This is a deliberate, temporary stand-in so onboarding is
//  fully functional today — swap for `GET /v1/quiz/next` once M5/M6 land.
//  Same UI (PlacementViewModel), just a different data source behind it.
//

import Foundation

struct PlacementQuestion: Identifiable {
    let id = UUID()
    let difficulty: Int // 1 (easiest) ... 5 (hardest)
    let prompt: String
    let options: [String]
    let correctIndex: Int
}

/// A simpler 2-question "tap the word" warmup for "Nothing yet" users
/// (DESIGN.md §9.4) — everyone gets a win, no staircase.
struct WarmupQuestion: Identifiable {
    let id = UUID()
    let prompt: String
    let options: [String]
    let correctIndex: Int
}

enum PlacementContent {
    static func staircase(for lang: String) -> [PlacementQuestion] {
        lang == "de" ? germanStaircase : englishStaircase
    }

    static func warmup(for lang: String) -> [WarmupQuestion] {
        lang == "de" ? germanWarmup : englishWarmup
    }

    // MARK: German

    private static let germanWarmup: [WarmupQuestion] = [
        .init(prompt: "Which word means \"hello\"?", options: ["Tschüss", "Hallo", "Danke"], correctIndex: 1),
        .init(prompt: "Which word means \"table\"?", options: ["Tisch", "Stuhl", "Fenster"], correctIndex: 0),
    ]

    private static let germanStaircase: [PlacementQuestion] = [
        .init(difficulty: 1, prompt: "\"Guten Morgen\" means...", options: ["Good night", "Good morning", "Good afternoon"], correctIndex: 1),
        .init(difficulty: 1, prompt: "\"Danke\" means...", options: ["Please", "Sorry", "Thank you"], correctIndex: 2),
        .init(difficulty: 2, prompt: "Fill in: Ich ___ ein Buch. (I read a book.)", options: ["lese", "liest", "lesen"], correctIndex: 0),
        .init(difficulty: 2, prompt: "\"Der Hund\" means...", options: ["The cat", "The dog", "The bird"], correctIndex: 1),
        .init(difficulty: 3, prompt: "Which is correct? \"Ich habe ___ Auto.\"", options: ["ein", "eine", "einen"], correctIndex: 0),
        .init(difficulty: 3, prompt: "\"Obwohl\" means...", options: ["because", "although", "therefore"], correctIndex: 1),
        .init(difficulty: 4, prompt: "Perfekt of \"gehen\" (to go) uses which auxiliary?", options: ["haben", "sein", "werden"], correctIndex: 1),
        .init(difficulty: 4, prompt: "Which sentence uses correct word order? ", options: ["Ich gehe heute nicht zur Schule.", "Ich gehe nicht heute zur Schule.", "Ich heute gehe nicht zur Schule."], correctIndex: 0),
        .init(difficulty: 5, prompt: "\"Er hätte es tun können\" means...", options: ["He does it.", "He could have done it.", "He will do it."], correctIndex: 1),
        .init(difficulty: 5, prompt: "Which is the correct subjunctive II of \"sein\"?", options: ["war", "wäre", "sei"], correctIndex: 1),
    ]

    // MARK: English (for German-native learners, per CLAUDE.md §7 v1 languages)

    private static let englishWarmup: [WarmupQuestion] = [
        .init(prompt: "Welches Wort bedeutet \"Hallo\"?", options: ["Bye", "Hello", "Thanks"], correctIndex: 1),
        .init(prompt: "Welches Wort bedeutet \"Tisch\"?", options: ["Table", "Chair", "Window"], correctIndex: 0),
    ]

    private static let englishStaircase: [PlacementQuestion] = [
        .init(difficulty: 1, prompt: "\"Good morning\" bedeutet...", options: ["Guten Abend", "Guten Morgen", "Gute Nacht"], correctIndex: 1),
        .init(difficulty: 1, prompt: "\"Thank you\" bedeutet...", options: ["Bitte", "Entschuldigung", "Danke"], correctIndex: 2),
        .init(difficulty: 2, prompt: "Fill in: I ___ a book every week.", options: ["read", "reads", "reading"], correctIndex: 0),
        .init(difficulty: 2, prompt: "\"The dog\" bedeutet...", options: ["Die Katze", "Der Hund", "Der Vogel"], correctIndex: 1),
        .init(difficulty: 3, prompt: "Which is correct?", options: ["She don't like coffee.", "She doesn't like coffee.", "She not like coffee."], correctIndex: 1),
        .init(difficulty: 3, prompt: "\"Although\" bedeutet...", options: ["weil", "obwohl", "deshalb"], correctIndex: 1),
        .init(difficulty: 4, prompt: "Which is the correct present perfect?", options: ["I have went there.", "I have gone there.", "I has gone there."], correctIndex: 1),
        .init(difficulty: 4, prompt: "Which sentence is correctly ordered?", options: ["I don't go today to school.", "I don't today go to school.", "Today I don't go to school."], correctIndex: 2),
        .init(difficulty: 5, prompt: "\"He could have done it\" bedeutet...", options: ["Er tut es.", "Er hätte es tun können.", "Er wird es tun."], correctIndex: 1),
        .init(difficulty: 5, prompt: "Which is the correct third conditional form?", options: ["If I knew, I would go.", "If I had known, I would have gone.", "If I know, I go."], correctIndex: 1),
    ]
}
