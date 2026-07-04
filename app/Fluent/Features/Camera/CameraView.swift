//
//  CameraView.swift
//  Fluent
//
//  DESIGN.md §8 "Camera ('caught a word' moment)" — live viewfinder, soft
//  reticle, word card springs up on identify, audio auto-plays once, toast.
//  CLAUDE.md §9: this loop is the differentiated, sticky experience.
//

import SwiftUI
import UIKit

struct CameraView: View {
    @State private var controller = CameraController()
    @State private var viewModel = CameraViewModel()
    @State private var ttsPlayer = TTSPlayer()
    @State private var isStarting = true
    @State private var showAddedToast = false

    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()

            if isStarting {
                ProgressView().tint(Theme.Colors.accent)
            } else if !controller.isAuthorized {
                EmptyStateView(
                    message: controller.lastErrorMessage ?? "Camera access is off.",
                    actionTitle: "Open Settings"
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                viewfinder
            }
        }
        .navigationTitle("Camera")
        .toast(isPresented: $showAddedToast, message: "Added to your words ✓", systemImage: "checkmark.circle.fill")
        .task {
            isStarting = true
            await controller.start()
            isStarting = false
        }
        .onDisappear { controller.stop() }
    }

    private var viewfinder: some View {
        ZStack {
            CameraPreviewView(session: controller.session)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Colors.surface.opacity(0.6), lineWidth: 2)
                .frame(width: 220, height: 220)
                .opacity(viewModel.state == .idle ? 1 : 0)

            VStack {
                Spacer()

                switch viewModel.state {
                case .idle:
                    captureButton
                        .padding(.bottom, Theme.Spacing.xl)
                case .identifying:
                    ProgressView()
                        .tint(.white)
                        .padding(Theme.Spacing.lg)
                        .background(Circle().fill(Theme.Colors.ink.opacity(0.6)))
                        .padding(.bottom, Theme.Spacing.xl)
                case .caught(let word):
                    caughtCard(word)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.xl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .failed(let message):
                    VStack(spacing: Theme.Spacing.md) {
                        Text(message)
                            .font(Theme.Font.body(15))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(Theme.Spacing.md)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.Colors.ink.opacity(0.7)))
                        captureButton
                    }
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .animation(Theme.Motion.spring, value: viewModel.state)
        }
    }

    private var captureButton: some View {
        Button {
            Task { await capture() }
        } label: {
            Circle()
                .fill(.white)
                .frame(width: 72, height: 72)
                .overlay(Circle().stroke(Theme.Colors.ink.opacity(0.2), lineWidth: 4).padding(4))
        }
        .accessibilityLabel("Snap a photo to identify")
    }

    private func caughtCard(_ word: WordCard) -> some View {
        WordCardView(word: word) {
            Task { await ttsPlayer.speak(text: word.word, lang: word.lang) }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                viewModel.reset()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.Colors.inkSoft)
            }
            .padding(Theme.Spacing.sm)
        }
        .task(id: word.id) {
            Theme.Haptic.streakOrLevelUp()
            showAddedToast = true
            await ttsPlayer.speak(text: word.word, lang: word.lang)
        }
    }

    private func capture() async {
        guard let image = await controller.capturePhoto() else {
            viewModel.state = .failed("Couldn't take that photo — try again.")
            return
        }
        await viewModel.identify(image)
    }
}

#Preview {
    NavigationStack {
        CameraView()
    }
}
