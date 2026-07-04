//
//  FluentApp.swift
//  Fluent
//
//  Created by Dion on 03.07.26.
//

import SwiftUI

@main
struct FluentApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task { await EventsClient.shared.flush() }
            }
        }
    }
}
