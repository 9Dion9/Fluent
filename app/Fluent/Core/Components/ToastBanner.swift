//
//  ToastBanner.swift
//  Fluent
//

import SwiftUI

struct ToastBanner: View {
    let message: String
    var systemImage: String = "checkmark.circle.fill"

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.Colors.leaf)
            Text(message)
                .font(Theme.Font.body(15, weight: .medium))
                .foregroundStyle(Theme.Colors.ink)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            Capsule()
                .fill(Theme.Colors.surface)
                .shadow(color: Theme.Colors.shadow, radius: 12, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Attach with `.toast(isPresented:message:)` to show a banner that auto-dismisses.
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    var systemImage: String = "checkmark.circle.fill"
    var duration: TimeInterval = 2.0

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if isPresented {
                ToastBanner(message: message, systemImage: systemImage)
                    .padding(.top, Theme.Spacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(duration))
                        isPresented = false
                    }
            }
        }
        .animation(Theme.Motion.spring, value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, systemImage: String = "checkmark.circle.fill") -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, systemImage: systemImage))
    }
}

#Preview {
    ToastBanner(message: "Added to your words ✓")
        .padding()
        .background(Theme.Colors.bg)
}
