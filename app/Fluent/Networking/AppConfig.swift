//
//  AppConfig.swift
//  Fluent
//
//  The app talks ONLY to the Worker, never to the gateway directly (CLAUDE.md §2).
//

import Foundation

/// `nonisolated` — read from `actor APIClient`'s isolation domain, not just MainActor
/// (the project defaults every declaration to `@MainActor`; this opts out).
nonisolated enum AppConfig {
    /// The Cloudflare Worker's base URL. See docs/RUNBOOK.md for history.
    static let workerBaseURL = URL(string: "https://fluent-worker.dionmain.workers.dev")!
}
