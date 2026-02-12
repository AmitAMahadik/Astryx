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
    @State private var selectedTab: AppTab = .profile
    @State private var cosmicTabBarHeight: CGFloat = 0
    
    private let aiService: any AIInsightService = AIInsightServiceFactory.make()

    init() {
        // SwiftUI's `.toolbar(.hidden, for: .tabBar)` can still leave the system tab bar
        // background visible in some layouts. Hide the underlying UITabBar so only our
        // floating `CosmicTabBarView` is rendered.
        UITabBar.appearance().isHidden = true
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
                // Reserve exactly what we render for the floating tab bar (including its safe-area padding).
                // Note: shadows/glows do not contribute to layout size, so we add a small visual
                // clearance to ensure bottom content (e.g. chat input) is fully above the capsule.
                let visualClearance: CGFloat = 22
                let reserve = max(0, cosmicTabBarHeight + visualClearance)

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
                    .padding(.bottom, reserve)

                    CosmicTabBarView(selection: $selectedTab)
                        // Sit above the home indicator / bottom safe area.
                        .padding(.bottom, proxy.safeAreaInsets.bottom)
                        .background(
                            GeometryReader { tabProxy in
                                Color.clear
                                    .preference(key: CosmicTabBarHeightKey.self, value: tabProxy.size.height)
                            }
                        )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .onPreferenceChange(CosmicTabBarHeightKey.self) { newValue in
                    cosmicTabBarHeight = newValue
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct CosmicTabBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // Use the latest measured value.
        value = nextValue()
    }
}
