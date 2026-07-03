//
//  ChatView.swift
//  Fluent
//
//  DESIGN.md §8 "Chat" — clean thread, corrections collapsed under the tutor
//  bubble, suggested-reply chips above the input, tutor-napping degraded state.
//  Voice (mic button, walkie-talkie mode) is M4 — the input is text-only here.
//

import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    init(tutorName: String, seed: OnboardingChatExchange? = nil) {
        let model = ChatViewModel(tutorName: tutorName)
        if let seed {
            model.seed(from: seed)
        }
        _viewModel = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        ForEach(viewModel.messages) { message in
                            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                                ChatBubble(text: message.text, role: message.role == .user ? .user : .tutor)
                                ForEach(Array(message.corrections.enumerated()), id: \.offset) { _, correction in
                                    CorrectionCard(correction: correction)
                                }
                            }
                            .id(message.id)
                        }

                        if viewModel.isTyping {
                            TypingIndicator()
                        }

                        if viewModel.isTutorNapping {
                            EmptyStateView(
                                message: viewModel.errorMessage
                                    ?? "\(viewModel.tutorName) is taking a quick nap — your words and reviews still work offline.",
                                actionTitle: nil,
                                action: nil
                            )
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation(Theme.Motion.spring) { scrollProxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if !viewModel.suggestedReplies.isEmpty {
                SuggestionChips(suggestions: viewModel.suggestedReplies) { suggestion in
                    draft = ""
                    Task { await viewModel.send(suggestion) }
                }
                .padding(.bottom, Theme.Spacing.sm)
            }

            inputBar
        }
        .background(Theme.Colors.bg)
        .navigationTitle(viewModel.tutorName)
    }

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Say something…", text: $draft, axis: .vertical)
                .focused($inputFocused)
                .font(Theme.Font.body(17))
                .padding(Theme.Spacing.md)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .fill(Theme.Colors.surface)
                )

            Button {
                let text = draft
                draft = ""
                Task { await viewModel.send(text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.Colors.inkSoft : Theme.Colors.accent)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(Theme.Spacing.lg)
    }
}

#Preview {
    NavigationStack {
        ChatView(tutorName: "Emma")
    }
}
