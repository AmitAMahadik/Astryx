//
//  AstryxApp.swift
//  Astryx
//
//  Created by Mahadik, Amit on 1/23/26.
//

import SwiftUI
import SwiftData
import AIProxy

enum AppTab: Hashable {
    case profile
    case focus
    case chat
}

@main
struct AstryxApp: App {
    @StateObject private var appState = AppState()
    @State private var selectedTab: AppTab = .profile
    
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
            TabView(selection: $selectedTab) {
                NavigationStack {
                    ProfileView()
                        .environment(\.aiInsightService, aiService)
                        .environmentObject(appState)
                }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(AppTab.profile)
                
                NavigationStack {
                    FocusView()
                        .environmentObject(appState)
                }
                .tabItem {
                    Label("Focus", systemImage: "sparkles")
                }
                .tag(AppTab.focus)
                
                NavigationStack {
                    ChatView()
                        .environment(\.aiInsightService, aiService)
                        .environmentObject(appState)
                }
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(AppTab.chat)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
