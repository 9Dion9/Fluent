//
//  OrderGameView.swift
//  Fluent
//
//  Tap shuffled words in the right order to rebuild the sentence (DESIGN.md §7 "order").
//

import SwiftUI

struct OrderGameView: View {
    let tokens: [String]
    let correctOrder: [Int]
    let onAnswer: (Bool) -> Void

    @State private var pickedIndices: [Int] = []
    @State private var hasSubmitted = false

    private var remainingIndices: [Int] {
        tokens.indices.filter { !pickedIndices.contains($0) }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Put the words in order")
                .font(Theme.Font.title(20))
                .foregroundStyle(Theme.Colors.ink)
                .padding(.top, Theme.Spacing.xxl)

            // Built sentence so far
            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(pickedIndices, id: \.self) { index in
                    Text(tokens[index])
                        .font(Theme.Font.body(17, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Theme.Colors.accent))
                }
            }
            .frame(minHeight: 54)
            .padding(.horizontal, Theme.Spacing.xl)

            Divider().padding(.horizontal, Theme.Spacing.xl)

            // Remaining word bank
            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(remainingIndices, id: \.self) { index in
                    Button {
                        pickedIndices.append(index)
                        if pickedIndices.count == tokens.count {
                            hasSubmitted = true
                            onAnswer(pickedIndices == correctOrder)
                        }
                    } label: {
                        Text(tokens[index])
                            .font(Theme.Font.body(17, weight: .medium))
                            .foregroundStyle(Theme.Colors.ink)
                            .padding(.horizontal, Theme.Spacing.md)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(Theme.Colors.surfaceAlt))
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .disabled(hasSubmitted)

            if !pickedIndices.isEmpty {
                GhostButton(title: "Undo last") {
                    pickedIndices.removeLast()
                }
                .frame(maxWidth: 160)
                .disabled(hasSubmitted)
            }

            Spacer()
        }
    }
}

/// Minimal wrapping HStack — SwiftUI has no built-in flow layout pre-iOS 17's `Layout`
/// protocol usage here keeps it simple and dependency-free.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    OrderGameView(tokens: ["Kuchen", "und", "Kaffee"], correctOrder: [2, 1, 0]) { _ in }
        .background(Theme.Colors.bg)
}
