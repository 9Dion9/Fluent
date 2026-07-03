//
//  WelcomeView.swift
//  Fluent
//
//  DESIGN.md §9.1 — Warm paper bg, app name in Rounded, one line. Detected
//  native language confirmed inline. Single button: "Let's go".
//

import SwiftUI

struct WelcomeView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    private var detectedLanguageName: String {
        Locale.current.localizedString(forLanguageCode: viewModel.nativeLang)?.capitalized ?? "English"
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                Text("Fluent")
                    .font(Theme.Font.display(40))
                    .foregroundStyle(Theme.Colors.ink)

                Text("Learn a language by actually talking.")
                    .font(Theme.Font.body(17))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .multilineTextAlignment(.center)

                Text("I'll speak \(detectedLanguageName) with you — change anytime in settings.")
                    .font(Theme.Font.caption())
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            PrimaryButton(title: "Let's go", action: onContinue)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.bottom, Theme.Spacing.xl)
    }
}

#Preview {
    WelcomeView(viewModel: OnboardingViewModel()) {}
}
