//
//  ChatBubble.swift
//  Fluent
//
//  User right/surfaceAlt, tutor left/surface with avatar (DESIGN.md §7, §8).
//

import SwiftUI

struct ChatBubble: View {
    enum Role {
        case user
        case tutor
    }

    let text: String
    let role: Role

    var body: some View {
        HStack {
            if role == .user { Spacer(minLength: 40) }

            Text(text)
                .font(Theme.Font.body(16))
                .foregroundStyle(Theme.Colors.ink)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(role == .user ? Theme.Colors.surfaceAlt : Theme.Colors.surface)
                )

            if role == .tutor { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Three soft dots breathing in the tutor bubble — appears within 100ms of send (DESIGN.md §6).
struct TypingIndicator: View {
    @State private var phase = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.Colors.inkSoft)
                    .frame(width: 6, height: 6)
                    .opacity(phase == index ? 1 : 0.3)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.Colors.surface))
        .onReceive(timer) { _ in
            guard !reduceMotion else { return }
            phase = (phase + 1) % 3
        }
        .accessibilityLabel("Tutor is typing")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        ChatBubble(text: "Hallo! 👋 That's the first of many.", role: .tutor)
        ChatBubble(text: "Hallo!", role: .user)
        TypingIndicator()
    }
    .padding()
    .background(Theme.Colors.bg)
}
