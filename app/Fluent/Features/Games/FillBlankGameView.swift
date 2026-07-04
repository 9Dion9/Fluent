//
//  FillBlankGameView.swift
//  Fluent
//

import SwiftUI

struct FillBlankGameView: View {
    let sentence: String
    let blankIndex: Int
    let correctWord: String
    let onAnswer: (Bool) -> Void

    @State private var typedAnswer = ""
    @State private var hasSubmitted = false
    @FocusState private var isFocused: Bool

    private var displaySentence: String {
        let tokens = sentence.split(separator: " ").map(String.init)
        guard blankIndex < tokens.count else { return sentence }
        var mutable = tokens
        mutable[blankIndex] = "_____"
        return mutable.joined(separator: " ")
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Fill in the blank")
                .font(Theme.Font.title(20))
                .foregroundStyle(Theme.Colors.ink)
                .padding(.top, Theme.Spacing.xxl)

            Text(displaySentence)
                .font(Theme.Font.body(19, weight: .medium))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            TextField("Type the missing word…", text: $typedAnswer)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(Theme.Font.body(17))
                .padding(Theme.Spacing.md)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous).fill(Theme.Colors.surface))
                .padding(.horizontal, Theme.Spacing.xl)
                .disabled(hasSubmitted)

            PrimaryButton(title: "Check", isEnabled: !typedAnswer.trimmingCharacters(in: .whitespaces).isEmpty && !hasSubmitted) {
                hasSubmitted = true
                isFocused = false
                let isCorrect = typedAnswer.trimmingCharacters(in: .whitespaces).lowercased() == correctWord.lowercased()
                onAnswer(isCorrect)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
    }
}

#Preview {
    FillBlankGameView(sentence: "Bitte nicht stören!", blankIndex: 1, correctWord: "nicht") { _ in }
        .background(Theme.Colors.bg)
}
