//
//  MCQGameView.swift
//  Fluent
//

import SwiftUI

struct MCQGameView: View {
    let question: String
    let options: [String]
    let correctIndex: Int
    let onAnswer: (Bool) -> Void

    @State private var selectedIndex: Int?

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text(question)
                .font(Theme.Font.title(22))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxl)

            VStack(spacing: Theme.Spacing.md) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    SelectableCard(title: option, isSelected: selectedIndex == index) {
                        guard selectedIndex == nil else { return }
                        selectedIndex = index
                        onAnswer(index == correctIndex)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .disabled(selectedIndex != nil)

            Spacer()
        }
    }
}

#Preview {
    MCQGameView(question: "Was bedeutet \"Tisch\"?", options: ["table", "chair", "door", "window"], correctIndex: 0) { _ in }
        .background(Theme.Colors.bg)
}
