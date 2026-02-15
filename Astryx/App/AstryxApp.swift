//
//  AstryxApp.swift
//  Astryx
//
//  Created by Mahadik, Amit on 1/23/26.
//

import SwiftUI
import SwiftData
import AIProxy
import UIKit

enum AppTab: Hashable {
    case profile
    case focus
    case chat
}

@main
struct AstryxApp: App {
    @StateObject private var appState = AppState()
    @State private var selectedTab: AppTab
    
    private let aiService: any AIInsightService = AIInsightServiceFactory.make()

    init() {
        // SwiftUI's `.toolbar(.hidden, for: .tabBar)` can still leave the system tab bar
        // background visible in some layouts. Hide the underlying UITabBar so only our
        // floating `CosmicTabBarView` is rendered.
        UITabBar.appearance().isHidden = true

        // If a profile is already selected, start the app on Focus for a better default flow.
        let storedProfileID = (UserDefaults.standard.string(forKey: "selectedProfileID") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        _selectedTab = State(initialValue: storedProfileID.isEmpty ? .profile : .focus)
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Profile.self,
            ChatMessage.self,
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
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    TabView(selection: $selectedTab) {
                        NavigationStack {
                            ProfileView()
                                .environment(\.aiInsightService, aiService)
                                .environmentObject(appState)
                        }
                        .toolbar(.hidden, for: .tabBar)
                        .tabItem {
                            Label("Profile", systemImage: "person.crop.circle")
                        }
                        .tag(AppTab.profile)
                        
                        NavigationStack {
                            FocusView()
                                .environmentObject(appState)
                        }
                        .toolbar(.hidden, for: .tabBar)
                        .tabItem {
                            Label("Focus", systemImage: "sparkles")
                        }
                        .tag(AppTab.focus)
                        
                        NavigationStack {
                            ChatView()
                                .environment(\.aiInsightService, aiService)
                                .environmentObject(appState)
                        }
                        .toolbar(.hidden, for: .tabBar)
                        .tabItem {
                            Label("Chat", systemImage: "bubble.left.and.bubble.right")
                        }
                        .tag(AppTab.chat)
                    }
                    // Keep existing TabView navigation logic, but replace the default tab bar UI.
                    .toolbar(.hidden, for: .tabBar)

                    CosmicTabBarView(selection: $selectedTab)
                        // Sit above the home indicator / bottom safe area.
                        // Keep it low (closer to screen bottom) while still clearing the home indicator.
                        .padding(.bottom, max(6, proxy.safeAreaInsets.bottom * 0.25))
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
