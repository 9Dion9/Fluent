//
//  GoalReminderView.swift
//  Fluent
//
//  DESIGN.md §9.7 — daily goal ring, then reminder pre-prompt. Only tapping
//  "Remind me" triggers the real system permission dialog — a declined
//  pre-prompt is recoverable, a declined system dialog is not.
//

import SwiftUI
import UserNotifications

struct GoalReminderView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    @State private var showTimePicker = false
    @State private var selectedTime = Date()

    private let goalOptions = [5, 10, 15]

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("How many new words a day?")
                .font(Theme.Font.title())
                .foregroundStyle(Theme.Colors.ink)
                .padding(.top, Theme.Spacing.xl)

            ProgressRing(
                progress: Double(goalIndex + 1) / Double(goalOptions.count),
                size: 110,
                centerLabel: "\(viewModel.dailyGoal)"
            )

            HStack(spacing: Theme.Spacing.md) {
                ForEach(goalOptions, id: \.self) { goal in
                    SelectableChip(title: "\(goal)", isSelected: viewModel.dailyGoal == goal) {
                        viewModel.dailyGoal = goal
                    }
                }
            }

            if viewModel.dailyGoal == 10 {
                Text("Most people keep this one.")
                    .font(Theme.Font.caption())
                    .foregroundStyle(Theme.Colors.inkSoft)
            }

            Divider().padding(.horizontal, Theme.Spacing.xl)

            if showTimePicker {
                VStack(spacing: Theme.Spacing.md) {
                    DatePicker("Reminder time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .onChange(of: selectedTime) { _, newValue in
                            viewModel.reminderTime = Self.timeString(from: newValue)
                        }
                    Text("Want a nudge at \(Self.timeString(from: selectedTime))? One friendly reminder a day, never spam.")
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .multilineTextAlignment(.center)
                    PrimaryButton(title: "Remind me", action: requestNotificationPermission)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
            } else {
                GhostButton(title: "Set a daily reminder") {
                    withAnimation(Theme.Motion.spring) { showTimePicker = true }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }

            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                PrimaryButton(title: "Continue", action: onContinue)
                if viewModel.reminderTime == nil {
                    Button("Skip") { onContinue() }
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.Colors.inkSoft)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.bottom, Theme.Spacing.xl)
    }

    private var goalIndex: Int {
        goalOptions.firstIndex(of: viewModel.dailyGoal) ?? 1
    }

    private static func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted, let reminderTime = viewModel.reminderTime {
                await LocalNotifier().scheduleDailyReminder(
                    at: reminderTime,
                    tutorName: viewModel.tutorName.isEmpty ? "Fluent" : viewModel.tutorName,
                    persona: viewModel.tutorPersona
                )
            } else {
                viewModel.reminderTime = nil
            }
            onContinue()
        }
    }
}

#Preview {
    GoalReminderView(viewModel: OnboardingViewModel()) {}
}
