//
//  MatchGameView.swift
//  Fluent
//
//  Tap a word, then its translation, to pair them (DESIGN.md §7 "match").
//

import SwiftUI

struct MatchGameView: View {
    let left: [String]
    let right: [String]
    let correctPairs: [[Int]]
    let onComplete: (Bool) -> Void

    @State private var selectedLeft: Int?
    @State private var matchedLeft: Set<Int> = []
    @State private var matchedRight: Set<Int> = []
    @State private var wrongFlash: (left: Int, right: Int)?

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Match the pairs")
                .font(Theme.Font.title(20))
                .foregroundStyle(Theme.Colors.ink)
                .padding(.top, Theme.Spacing.xxl)

            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(left.enumerated()), id: \.offset) { index, word in
                        matchTile(
                            text: word,
                            isSelected: selectedLeft == index,
                            isMatched: matchedLeft.contains(index),
                            isWrong: wrongFlash?.left == index
                        ) {
                            guard !matchedLeft.contains(index) else { return }
                            selectedLeft = index
                        }
                    }
                }
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(right.enumerated()), id: \.offset) { index, translation in
                        matchTile(
                            text: translation,
                            isSelected: false,
                            isMatched: matchedRight.contains(index),
                            isWrong: wrongFlash?.right == index
                        ) {
                            attemptMatch(rightIndex: index)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
    }

    private func matchTile(text: String, isSelected: Bool, isMatched: Bool, isWrong: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(Theme.Font.body(15, weight: .medium))
                .foregroundStyle(isMatched ? Theme.Colors.inkSoft : Theme.Colors.ink)
                .multilineTextAlignment(.leading)
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .fill(isMatched ? Theme.Colors.leaf.opacity(0.15) : Theme.Colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .stroke(isWrong ? Theme.Colors.honey : (isSelected ? Theme.Colors.accent : .clear), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(isMatched)
        .animation(Theme.Motion.spring, value: isWrong)
    }

    private func attemptMatch(rightIndex: Int) {
        guard let leftIndex = selectedLeft, !matchedRight.contains(rightIndex) else { return }

        if correctPairs.contains(where: { $0 == [leftIndex, rightIndex] }) {
            Theme.Haptic.correctAnswer()
            matchedLeft.insert(leftIndex)
            matchedRight.insert(rightIndex)
            selectedLeft = nil
            if matchedLeft.count == left.count {
                onComplete(true)
            }
        } else {
            Theme.Haptic.wrongAnswer()
            wrongFlash = (leftIndex, rightIndex)
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                wrongFlash = nil
                selectedLeft = nil
            }
        }
    }
}

#Preview {
    MatchGameView(
        left: ["Schöne", "zweimal", "Mark", "gelernt"],
        right: ["marrow", "nominalization of schön", "twice", "skilled, trained"],
        correctPairs: [[0, 1], [1, 2], [2, 0], [3, 3]]
    ) { _ in }
    .background(Theme.Colors.bg)
}
