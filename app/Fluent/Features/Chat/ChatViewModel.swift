//
//  ChatViewModel.swift
//  Fluent
//
//  Drives the tutor chat screen (CLAUDE.md §6, §7; DESIGN.md §8). Owns the
//  message list, the active conversation id, and the "tutor napping"
//  degraded state the gateway's circuit breaker can trigger.
//

import Foundation

@Observable
final class ChatViewModel {
    struct MessageItem: Identifiable {
        enum Role { case user, tutor }

        let id = UUID()
        let role: Role
        let text: String
        var corrections: [ChatReply.Correction] = []
    }

    private(set) var messages: [MessageItem] = []
    private(set) var suggestedReplies: [String] = []
    private(set) var isTyping = false
    private(set) var isTutorNapping = false
    var errorMessage: String?

    private var conversationID: String?
    private let apiClient: APIClient
    private let ttsPlayer: TTSPlayer
    let tutorName: String
    let targetLang: String

    var isMuted: Bool {
        get { ttsPlayer.isMuted }
        set { ttsPlayer.isMuted = newValue }
    }

    init(apiClient: APIClient = .shared, ttsPlayer: TTSPlayer = TTSPlayer(), tutorName: String, targetLang: String) {
        self.apiClient = apiClient
        self.ttsPlayer = ttsPlayer
        self.tutorName = tutorName
        self.targetLang = targetLang
    }

    /// Seeds the thread with the tutor's onboarding greeting so chat picks up
    /// where the first-message moment (DESIGN.md §9.9) left off, without
    /// re-sending it to the server.
    func seed(tutorGreeting: String, userReply: String?) {
        messages = [MessageItem(role: .tutor, text: tutorGreeting)]
        if let userReply {
            messages.append(MessageItem(role: .user, text: userReply))
        }
    }

    /// Seeds the thread from a real onboarding exchange (FirstMessageView) so
    /// the conversation continues on the same `conversation_id` server-side
    /// instead of starting a fresh one when the user lands on Home.
    func seed(from onboardingExchange: OnboardingChatExchange) {
        conversationID = onboardingExchange.conversationID
        messages = [
            MessageItem(role: .tutor, text: onboardingExchange.tutorGreeting),
            MessageItem(role: .user, text: onboardingExchange.userReply),
            MessageItem(role: .tutor, text: onboardingExchange.tutorReply, corrections: onboardingExchange.corrections),
        ]
        suggestedReplies = onboardingExchange.suggestedReplies
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Theme.Haptic.sendMessage()
        messages.append(MessageItem(role: .user, text: trimmed))
        suggestedReplies = []
        isTyping = true
        isTutorNapping = false
        errorMessage = nil

        do {
            let reply = try await apiClient.sendChat(text: trimmed, conversationID: conversationID)
            conversationID = reply.conversationID
            isTyping = false
            messages.append(MessageItem(role: .tutor, text: reply.reply, corrections: reply.corrections))
            suggestedReplies = reply.suggestedReplies
            EventsClient.shared.log("chat_turn")
            if !UserDefaults.standard.bool(forKey: "hasSentFirstChatTurn") {
                UserDefaults.standard.set(true, forKey: "hasSentFirstChatTurn")
                EventsClient.shared.log("first_chat_turn")
            }
            // new_vocab auto-add to the deck lands once the SRS/`/v1/srs` +
            // `user_cards` seam exists (CLAUDE.md M5) — nothing to wire yet.
            await ttsPlayer.speak(text: reply.replyTargetText, lang: targetLang)
        } catch let error as APIError {
            isTyping = false
            handleError(error)
        } catch {
            isTyping = false
            errorMessage = error.localizedDescription
        }
    }

    private func handleError(_ error: APIError) {
        if case .server(let code, let message, _) = error {
            if code == "tutor_napping" {
                isTutorNapping = true
                errorMessage = message
                return
            }
            errorMessage = message
            return
        }
        errorMessage = error.localizedDescription
    }
}
