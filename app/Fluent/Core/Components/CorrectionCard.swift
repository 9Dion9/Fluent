//
//  CorrectionCard.swift
//  Fluent
//
//  Leaf-tinted: original struck softly -> arrow -> natural way + one-line why.
//  Renders collapsed to one line under the tutor bubble, tap to expand (DESIGN.md §7, §8).
//  Corrections are gifts, never red ink — never pure red (DESIGN.md §3).
//

import SwiftUI

struct CorrectionCard: View {
    let correction: ChatReply.Correction

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(Theme.Motion.adaptive(reduceMotion)) { isExpanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(correction.original)
                        .strikethrough()
                        .foregroundStyle(Theme.Colors.inkSoft)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Theme.Colors.leaf)
                    Text(correction.corrected)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.leaf)
                }
                .font(Theme.Font.body(14))
                .lineLimit(isExpanded ? nil : 1)

                if isExpanded {
                    Text(correction.explanation)
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .transition(.opacity)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(Theme.Colors.leaf.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Correction: \(correction.original) becomes \(correction.corrected). \(correction.explanation)")
    }
}

#Preview {
    CorrectionCard(correction: .init(
        original: "ich habe gegeht",
        corrected: "ich bin gegangen",
        explanation: "'gehen' takes 'sein' in the perfect tense 🙂"
    ))
    .padding()
    .background(Theme.Colors.bg)
}
