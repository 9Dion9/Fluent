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

    @Test func decodesErrorFixture() throws {
        let json = """
        { "error": { "code": "rate_limited", "message": "You've hit today's chat limit — come back tomorrow!", "retryable": false } }
        """
        let error = try decoder.decode(APIErrorResponse.self, from: Data(json.utf8))
        #expect(error.error.code == "rate_limited")
        #expect(error.error.retryable == false)
    }
}
