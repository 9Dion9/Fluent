//
//  ChatView.swift
//  Fluent
//
//  DESIGN.md §8 "Chat" — clean thread, corrections collapsed under the tutor
//  bubble, suggested-reply chips above the input, tutor-napping degraded state.
//  Mic button toggles walkie-talkie mode: hold to record, on-device STT,
//  release to send; reply audio auto-plays with a mute toggle (CLAUDE.md §8).
//

import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var voiceRecorder = VoiceRecorder()
    @State private var draft = ""
    @State private var micUnavailableHint = false
    @State private var showErrorToast = false
    @State private var scenarios: [Scenario] = []
    @FocusState private var inputFocused: Bool
    private let apiClient: APIClient = .shared

    init(tutorName: String, targetLang: String, seed: OnboardingChatExchange? = nil) {
        let model = ChatViewModel(tutorName: tutorName, targetLang: targetLang)
        if let seed {
            model.seed(from: seed)
        }
        _viewModel = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !scenarios.isEmpty {
                scenarioShelf
            }
            if let scenario = viewModel.activeScenario {
                activeScenarioBanner(scenario)
            }

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

                        if voiceRecorder.isRecording {
                            HStack(spacing: Theme.Spacing.sm) {
                                Text(voiceRecorder.transcript.isEmpty ? "Listening…" : voiceRecorder.transcript)
                                    .font(Theme.Font.body(15))
                                    .foregroundStyle(Theme.Colors.inkSoft)
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
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
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { inputFocused = false }

            if !viewModel.suggestedReplies.isEmpty {
                SuggestionChips(suggestions: viewModel.suggestedReplies) { suggestion in
                    draft = ""
                    Task { await viewModel.send(suggestion) }
                }
                .padding(.bottom, Theme.Spacing.sm)
            }

            if micUnavailableHint {
                Text("Voice isn't available right now — you can still type.")
                    .font(Theme.Font.caption())
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .padding(.bottom, Theme.Spacing.xs)
            }

            inputBar
        }
        .background(Theme.Colors.bg)
        .navigationTitle(viewModel.tutorName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.isMuted.toggle()
                } label: {
                    Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundStyle(Theme.Colors.ink)
                }
                .accessibilityLabel(viewModel.isMuted ? "Unmute tutor voice" : "Mute tutor voice")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { inputFocused = false }
            }
        }
        .task {
            voiceRecorder.configure(forTargetLang: viewModel.targetLang)
            scenarios = (try? await apiClient.getScenarios()) ?? []
        }
        .toast(isPresented: $showErrorToast, message: viewModel.errorMessage ?? "", systemImage: "exclamationmark.triangle.fill")
        .onChange(of: viewModel.errorMessage) {
            // The napping state already renders its own inline EmptyStateView —
            // only toast for everything else (e.g. an empty voice transcript).
            showErrorToast = viewModel.errorMessage != nil && !viewModel.isTutorNapping
        }
    }

    /// DESIGN.md §8: "Scenario picker as a horizontal shelf."
    private var scenarioShelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(scenarios) { scenario in
                    let isActive = viewModel.activeScenario?.id == scenario.id
                    Button {
                        Theme.Haptic.chipTap()
                        viewModel.selectScenario(scenario)
                    } label: {
                        Text("\(scenario.emoji ?? "") \(scenario.title)")
                            .font(Theme.Font.body(14, weight: .medium))
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(Capsule().fill(isActive ? Theme.Colors.accent : Theme.Colors.surfaceAlt))
                            .foregroundStyle(isActive ? .white : Theme.Colors.ink)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func activeScenarioBanner(_ scenario: Scenario) -> some View {
        HStack {
            Text("Roleplaying: \(scenario.emoji ?? "") \(scenario.title)")
                .font(Theme.Font.caption())
                .foregroundStyle(Theme.Colors.inkSoft)
            Spacer()
            Button("End") { viewModel.clearScenario() }
                .font(Theme.Font.caption())
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.sky)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xs)
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

            if draft.trimmingCharacters(in: .whitespaces).isEmpty {
                AudioWaveformButton(
                    isRecording: voiceRecorder.isRecording,
                    onHoldStart: startRecording,
                    onHoldEnd: stopRecordingAndSend
                )
            } else {
                Button {
                    let text = draft
                    draft = ""
                    Task { await viewModel.send(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
        }
        .padding(Theme.Spacing.lg)
    }

    private func startRecording() {
        Task {
            let started = await voiceRecorder.startRecording()
            micUnavailableHint = !started
        }
    }

    private func stopRecordingAndSend() {
        let transcript = voiceRecorder.stopRecording()
        guard !transcript.trimmingCharacters(in: .whitespaces).isEmpty else {
            // Nothing was transcribed — surface why instead of silently doing
            // nothing (this exact silence was a real bug: see VoiceRecorder).
            viewModel.errorMessage = voiceRecorder.lastErrorMessage
                ?? "Didn't catch that — check you're online (voice recognition needs it) and try again."
            return
        }
        Task { await viewModel.send(transcript) }
    }
}

#Preview {
    NavigationStack {
        ChatView(tutorName: "Emma", targetLang: "de")
    }
}
