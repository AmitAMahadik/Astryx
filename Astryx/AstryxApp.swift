//
//  AstryxApp.swift
//  Astryx
//
//  Created by Mahadik, Amit on 1/23/26.
//

import SwiftUI
import SwiftData

import AIProxy

@main
struct AstryxApp: App {
    @StateObject private var appState = AppState()
    private let aiService: any AIInsightService = AIInsightServiceFactory.make()
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ProfileView()
                .environment(\.aiInsightService, aiService)
                .environmentObject(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}
