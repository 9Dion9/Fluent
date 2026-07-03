//
//  AppConfig.swift
//  Fluent
//
//  The app talks ONLY to the Worker, never to the gateway directly (CLAUDE.md §2).
//

import Foundation

enum AppConfig {
    /// The Cloudflare Worker's base URL. Update once the Worker is deployed;
    /// see docs/RUNBOOK.md for the current dev tunnel / production URL.
    static let workerBaseURL = URL(string: "http://localhost:8787")!
}
