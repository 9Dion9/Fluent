//
//  Theme.swift
//  Fluent
//
//  Design tokens per docs/DESIGN.md §3-§6. Never hardcode a color, font,
//  radius, or spring curve outside this file — reference Theme.* instead.
//

import SwiftUI

enum Theme {

    // MARK: §3 Color tokens

    enum Colors {
        static let bg = Color("Bg")
        static let surface = Color("Surface")
        static let surfaceAlt = Color("SurfaceAlt")
        static let ink = Color("Ink")
        static let inkSoft = Color("InkSoft")
        static let accent = Color("AccentBrand")
        static let leaf = Color("Leaf")
        static let sky = Color("Sky")
        static let honey = Color("Honey")

        /// `Theme.Colors.ink` at 6% opacity — the app's one shadow tone (DESIGN.md §3).
        static let shadow = Color("Ink").opacity(0.06)
    }

    // MARK: §4 Gender colors (the signature mnemonic system)

    enum GenderColor: String {
        case masculine
        case feminine
        case neuter

        var color: Color {
            switch self {
            case .masculine: Color("GenderM")
            case .feminine: Color("GenderF")
            case .neuter: Color("GenderN")
            }
        }

        /// The article itself is always spelled out alongside the color (DESIGN.md §4,
        /// §12) — color reinforces, it's never the only signal.
        var article: String {
            switch self {
            case .masculine: "der"
            case .feminine: "die"
            case .neuter: "das"
            }
        }
    }

    // MARK: §5 Typography & shape

    enum Font {
        static func display(_ size: CGFloat = 34) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .rounded)
        }

        static func title(_ size: CGFloat = 24) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .rounded)
        }

        static func body(_ size: CGFloat = 17, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }

        static func caption(_ size: CGFloat = 13) -> SwiftUI.Font {
            .system(size: size, weight: .regular, design: .default)
        }
    }

    enum Radius {
        static let card: CGFloat = 20
        static let button: CGFloat = 14
        static let chip: CGFloat = 999 // fully rounded
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: §6 Motion & haptics

    enum Motion {
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)

        /// Use in place of `spring` when `accessibilityReduceMotion` is on.
        static let reducedMotion = SwiftUI.Animation.easeInOut(duration: 0.2)

        static func adaptive(_ reduceMotion: Bool) -> SwiftUI.Animation {
            reduceMotion ? reducedMotion : spring
        }
    }

    enum Haptic {
        static func chipTap() {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        static func sendMessage() {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        static func correctAnswer() {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        /// Wrong answer uses a soft impact, never the sharp `.error` buzz (DESIGN.md §6).
        static func wrongAnswer() {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }

        static func streakOrLevelUp() {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
