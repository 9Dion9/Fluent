//
//  FirstMessageView.swift
//  Fluent
//
//  DESIGN.md §9.9 — the guaranteed win. Tutor's first message lands with a
//  suggested-reply chip already glowing so the first interaction cannot fail.
//  Real chat (POST /v1/chat) is M3 — this is a scripted, local-only exchange
//  so onboarding's emotional arc is complete today; M3 swaps in the real call.
//

import SwiftUI

struct FirstMessageView: View {
    @Bindable var viewModel: OnboardingViewModel
    let router: AppRouter

    @State private var showTutorMessage = false
    @State private var showTyping = false
    @State private var userReplySent = false
    @State private var showTutorDelight = false
    @State private var showRing = false

    private var greeting: (native: String, targetWord: String) {
        viewModel.targetLang == "de"
            ? ("Hallo! 👋 That's the first of many.", "Hallo, \(viewModel.tutorName)!")
            : ("Hallo! 👋 Das ist das erste von vielen.", "Hello, \(viewModel.tutorName)!")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if showTutorMessage {
                        ChatBubble(text: greeting.native, role: .tutor)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    if userReplySent {
                        ChatBubble(text: greeting.targetWord, role: .user)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    if showTyping {
                        TypingIndicator()
                    }
                    if showTutorDelight {
                        ChatBubble(text: "You did it! 🎉 That's real \(viewModel.targetLang == "de" ? "German" : "English"), on your first try.", role: .tutor)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .padding(Theme.Spacing.lg)
            }

            if showRing {
                HStack {
                    ProgressRing(progress: 0.1, size: 44)
                    Text("1/\(viewModel.dailyGoal) today")
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.Colors.inkSoft)
                    Spacer()
                    PrimaryButton(title: "Start exploring") {
                        if let profile = router.profile {
                            router.onboardingCompleted(with: profile)
                        }
                    }
                    .frame(maxWidth: 180)
                }
                .padding(Theme.Spacing.lg)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showTutorMessage && !userReplySent {
                SuggestionChips(suggestions: [greeting.targetWord], highlightedIndex: 0) { _ in
                    sendReply()
                }
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .animation(Theme.Motion.spring, value: showTutorMessage)
        .animation(Theme.Motion.spring, value: userReplySent)
        .animation(Theme.Motion.spring, value: showTutorDelight)
        .animation(Theme.Motion.spring, value: showRing)
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            showTutorMessage = true
        }
    }

    private func sendReply() {
        Theme.Haptic.sendMessage()
        userReplySent = true
        showTyping = true
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            showTyping = false
            showTutorDelight = true
            try? await Task.sleep(for: .milliseconds(400))
            showRing = true
        }
    }
}

#Preview {
    FirstMessageView(viewModel: OnboardingViewModel(), router: AppRouter())
}
