//
//  Notifier.swift
//  Fluent
//
//  `Notifier` seam (CLAUDE.md §2): local notifications in v1, APNs in v2 —
//  call sites never change. Copy rotates per persona so the reminder never
//  says the same thing twice in a row (DESIGN.md §10).
//

import Foundation
import UserNotifications

protocol Notifier {
    /// Schedules (replacing any existing one) a daily repeating reminder at `time` ("HH:mm").
    func scheduleDailyReminder(at time: String, tutorName: String, persona: String) async
    func cancelDailyReminder() async
}

struct LocalNotifier: Notifier {
    private static let reminderIdentifierPrefix = "daily-reminder-"

    func scheduleDailyReminder(at time: String, tutorName: String, persona: String) async {
        await cancelDailyReminder()

        guard let (hour, minute) = Self.parseTime(time) else { return }

        let center = UNUserNotificationCenter.current()
        let copyVariants = NotificationCopy.variants(persona: persona, tutorName: tutorName)

        // iOS has no built-in "different text each day" for a single repeating
        // request, so each copy variant gets its own weekday-anchored request
        // (Sun=1...Sat=7), repeating weekly — spreads the rotation across the
        // week with no backend/background-task dependency. With N variants,
        // day-of-week `d` uses variant `d % N`, so it still rotates even with
        // fewer than 7 variants.
        for weekday in 1...7 {
            let body = copyVariants[weekday % copyVariants.count]
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.weekday = weekday
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let content = UNMutableNotificationContent()
            content.title = tutorName
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "\(Self.reminderIdentifierPrefix)\(weekday)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelDailyReminder() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(Self.reminderIdentifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func parseTime(_ time: String) -> (hour: Int, minute: Int)? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        return (hour, minute)
    }
}

/// DESIGN.md §10 — never the same message twice in a row; each persona has its own voice.
enum NotificationCopy {
    static func variants(persona: String, tutorName: String) -> [String] {
        switch persona {
        case "dry":
            return [
                "Ten new words are waiting. Try to contain your excitement.",
                "Your streak needs you. It's not going to save itself.",
                "\(tutorName) has prepared exactly one thing to say: come practice.",
                "Two minutes. That's the whole ask.",
            ]
        case "professor":
            return [
                "Ten new words are ready for study — each one a small door to another way of thinking.",
                "A brief review now compounds remarkably over time. Shall we?",
                "\(tutorName) has a small etymology worth sharing today.",
                "Consistency, not intensity, is what builds fluency.",
            ]
        default: // sunny
            return [
                "10 new words are waiting \u{1F99C} They're getting impatient.",
                "Your streak is on fire \u{1F525} Two minutes keeps it alive.",
                "Quick one: how do you say 'coffee' today? ...come check.",
                "\(tutorName) misses you. So does your streak.",
            ]
        }
    }
}
