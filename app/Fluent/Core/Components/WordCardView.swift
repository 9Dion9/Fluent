//
//  WordCardView.swift
//  Fluent
//
//  Big rounded word, gender-colored article chip, IPA, example with
//  tap-to-play audio, translation reveal (DESIGN.md §7).
//

import SwiftUI

struct WordCardView: View {
    let word: WordCard
    var onPlayAudio: (() -> Void)? = nil

    @State private var isTranslationRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                if let genderColor = word.genderColor {
                    Text(genderColor.article)
                        .font(Theme.Font.caption())
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(genderColor.color))
                } else if let pos = word.pos {
                    Text(pos)
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.Colors.surfaceAlt))
                }
                Spacer()
                if onPlayAudio != nil {
                    Button {
                        onPlayAudio?()
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(Theme.Colors.sky)
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Play pronunciation")
                }
            }

            Text(word.word)
                .font(Theme.Font.display(28))
                .foregroundStyle(Theme.Colors.ink)

            if let ipa = word.ipa {
                Text(ipa)
                    .font(Theme.Font.caption())
                    .foregroundStyle(Theme.Colors.inkSoft)
            }

            if let example = word.example {
                Text(example)
                    .font(Theme.Font.body(15))
                    .foregroundStyle(Theme.Colors.ink)
            }

            Button {
                withAnimation(Theme.Motion.spring) { isTranslationRevealed.toggle() }
            } label: {
                Text(isTranslationRevealed ? word.translation : "Show translation")
                    .font(Theme.Font.body(14, weight: .medium))
                    .foregroundStyle(Theme.Colors.sky)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Colors.surface)
                .shadow(color: Theme.Colors.shadow, radius: 12, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(word.genderColor?.color.opacity(0.4) ?? .clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [word.word]
        if let genderColor = word.genderColor {
            parts.append("\(genderColor.article), \(genderColor.rawValue)")
        }
        parts.append(word.translation)
        return parts.joined(separator: ", ")
    }
}

#Preview {
    WordCardView(
        word: WordCard(
            id: "1", lang: "de", word: "Tisch", translation: "table", pos: "noun",
            gender: "der", ipa: "/tɪʃ/", cefr: "A1", topics: nil,
            example: "Der Tisch steht in der Küche.", exampleTranslation: nil,
            audioURL: nil, source: nil, verified: nil
        ),
        onPlayAudio: {}
    )
    .padding()
    .background(Theme.Colors.bg)
}
