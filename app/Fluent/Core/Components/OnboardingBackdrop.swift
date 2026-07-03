//
//  OnboardingBackdrop.swift
//  Fluent
//
//  Soft blob shapes in surfaceAlt behind onboarding content (DESIGN.md §2
//  "Illustration style: simple filled SF Symbols + soft blob shapes"). Fills
//  the breathing room below auto-advancing cards with brand texture instead
//  of a flat void, without competing with the one primary action per screen.
//

import SwiftUI

struct OnboardingBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Circle()
                    .fill(Theme.Colors.surfaceAlt.opacity(0.6))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .blur(radius: 40)
                    .offset(x: -w * 0.35, y: h * 0.78 + (drift ? -8 : 0))

                Circle()
                    .fill(Theme.Colors.honey.opacity(0.10))
                    .frame(width: w * 0.6, height: w * 0.6)
                    .blur(radius: 50)
                    .offset(x: w * 0.4, y: h * 0.12 + (drift ? 6 : 0))

                Circle()
                    .fill(Theme.Colors.leaf.opacity(0.07))
                    .frame(width: w * 0.45, height: w * 0.45)
                    .blur(radius: 45)
                    .offset(x: w * 0.32, y: h * 0.92 + (drift ? -6 : 0))
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.Colors.bg.ignoresSafeArea()
        OnboardingBackdrop()
    }
}
