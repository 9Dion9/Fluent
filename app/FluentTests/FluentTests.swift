//
//  FluentTests.swift
//  FluentTests
//
//  Codable decoding test per /shared schema fixture (CLAUDE.md §4). The
//  fixture JSON is duplicated inline from /shared/fixtures/*.json rather than
//  wired up as a copied build resource — keep these in sync by hand when a
//  contract changes; /shared's ajv round-trip tests remain the source of truth
//  for schema validity, this only proves the Swift Codable side decodes it.
//

import Testing
import Foundation
@testable import Fluent

struct FluentTests {

    private let decoder = JSONDecoder()

    @Test func decodesWordCardFixture() throws {
        let json = """
        {
          "id": "w_ab12cd34", "lang": "de", "word": "Tisch", "translation": "table",
          "pos": "noun", "gender": "der", "ipa": "/tɪʃ/", "cefr": "A1",
          "topics": ["daily life", "furniture"], "example": "Der Tisch steht in der Küche.",
          "example_translation": "The table is in the kitchen.",
          "audio_url": "https://audio.fluent.app/de/w_ab12cd34.m4a",
          "source": "pipeline", "verified": true
        }
        """
        let card = try decoder.decode(WordCard.self, from: Data(json.utf8))
        #expect(card.id == "w_ab12cd34")
        #expect(card.word == "Tisch")
        #expect(card.genderColor == .masculine)
    }

    @Test func decodesChatReplyFixture() throws {
        let json = """
        {
          "reply": "Ha, close! You meant \\"ich bin gegangen\\" — nice try though. So, where did you go?",
          "reply_target_text": "Wohin bist du gegangen?",
          "corrections": [
            { "original": "ich habe gegeht", "corrected": "ich bin gegangen",
              "explanation": "'gehen' takes 'sein' in the perfect tense 🙂" }
          ],
          "suggested_replies": ["Ich bin ins Kino gegangen.", "Und du?"],
          "new_vocab": [
            { "word": "gegangen", "translation": "gone/went", "example": "Ich bin nach Hause gegangen." }
          ]
        }
        """
        let reply = try decoder.decode(ChatReply.self, from: Data(json.utf8))
        #expect(reply.corrections.count == 1)
        #expect(reply.suggestedReplies == ["Ich bin ins Kino gegangen.", "Und du?"])
        #expect(reply.newVocab.first?.word == "gegangen")
    }

    @Test func decodesCardFixture() throws {
        let json = """
        {
          "card_id": "c_9f8e7d6c",
          "word": {
            "id": "w_ab12cd34", "lang": "de", "word": "Tisch", "translation": "table",
            "pos": "noun", "gender": "der", "ipa": "/tɪʃ/", "cefr": "A1",
            "topics": ["daily life", "furniture"], "example": "Der Tisch steht in der Küche.",
            "example_translation": "The table is in the kitchen.",
            "audio_url": "https://audio.fluent.app/de/w_ab12cd34.m4a",
            "source": "pipeline", "verified": true
          },
          "due_at": 1751500800000, "stability": 4.2, "difficulty": 5.8,
          "reps": 3, "lapses": 0, "state": "review", "last_review_at": 1751414400000
        }
        """
        let card = try decoder.decode(Card.self, from: Data(json.utf8))
        #expect(card.cardID == "c_9f8e7d6c")
        #expect(card.state == "review")
        #expect(card.word.word == "Tisch")
    }

    @Test func decodesScenarioFixture() throws {
        let json = """
        {
          "id": "s_cafe01", "lang": "de", "title": "Order a coffee", "emoji": "☕",
          "min_level": "A1",
          "seed_prompt": "You are a friendly barista at a Berlin café. The user is ordering a drink. Keep it short and encouraging.",
          "focus_word_ids": ["w_ab12cd34"]
        }
        """
        let scenario = try decoder.decode(Scenario.self, from: Data(json.utf8))
        #expect(scenario.id == "s_cafe01")
        #expect(scenario.minLevel == "A1")
    }

    @Test func decodesMCQQuizFixture() throws {
        let json = """
        {
          "id": "q_11223344", "lang": "de", "type": "mcq",
          "prompt": { "question": "What does \\"Tisch\\" mean?", "options": ["chair", "table", "window", "door"] },
          "answer": { "correct_index": 1 },
          "difficulty": 1, "word_ids": ["w_ab12cd34"]
        }
        """
        let quiz = try decoder.decode(Quiz.self, from: Data(json.utf8))
        guard case .mcq(let question, let options, let correctIndex) = quiz.content else {
            Issue.record("expected .mcq content")
            return
        }
        #expect(question.contains("Tisch"))
        #expect(options.count == 4)
        #expect(correctIndex == 1)
        #expect(quiz.wordIDs == ["w_ab12cd34"])
    }

    // match/fillblank/order aren't in /shared/fixtures/quiz.json yet (only the
    // mcq example is fixtured there) — these cover the shapes this app's own
    // custom Quiz decoder expects from worker/src/routes/quiz.ts.
    @Test func decodesMatchQuiz() throws {
        let json = """
        { "id": "q1", "lang": "de", "type": "match",
          "prompt": { "left": ["Tisch", "Stuhl"], "right": ["chair", "table"] },
          "answer": { "correct_pairs": [[0, 1], [1, 0]] },
          "difficulty": 1, "word_ids": ["w1", "w2"] }
        """
        let quiz = try decoder.decode(Quiz.self, from: Data(json.utf8))
        guard case .match(let left, let right, let correctPairs) = quiz.content else {
            Issue.record("expected .match content")
            return
        }
        #expect(left == ["Tisch", "Stuhl"])
        #expect(right == ["chair", "table"])
        #expect(correctPairs == [[0, 1], [1, 0]])
    }

    @Test func decodesFillBlankQuiz() throws {
        let json = """
        { "id": "q1", "lang": "de", "type": "fillblank",
          "prompt": { "sentence": "Bitte nicht stören!", "blank_index": 1 },
          "answer": { "correct_word": "nicht" },
          "difficulty": 1, "word_ids": ["w1"] }
        """
        let quiz = try decoder.decode(Quiz.self, from: Data(json.utf8))
        guard case .fillBlank(let sentence, let blankIndex, let correctWord) = quiz.content else {
            Issue.record("expected .fillBlank content")
            return
        }
        #expect(sentence == "Bitte nicht stören!")
        #expect(blankIndex == 1)
        #expect(correctWord == "nicht")
    }

    @Test func decodesOrderQuiz() throws {
        let json = """
        { "id": "q1", "lang": "de", "type": "order",
          "prompt": { "tokens": ["und", "Kaffee", "Kuchen"] },
          "answer": { "correct_order": [2, 0, 1] },
          "difficulty": 1, "word_ids": ["w1"] }
        """
        let quiz = try decoder.decode(Quiz.self, from: Data(json.utf8))
        guard case .order(let tokens, let correctOrder) = quiz.content else {
            Issue.record("expected .order content")
            return
        }
        #expect(tokens == ["und", "Kaffee", "Kuchen"])
        #expect(correctOrder == [2, 0, 1])
    }

    @Test func decodesErrorFixture() throws {
        let json = """
        { "error": { "code": "rate_limited", "message": "You've hit today's chat limit — come back tomorrow!", "retryable": false } }
        """
        let error = try decoder.decode(APIErrorResponse.self, from: Data(json.utf8))
        #expect(error.error.code == "rate_limited")
        #expect(error.error.retryable == false)
    }
}
