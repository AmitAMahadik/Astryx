//
//  AstryxApp.swift
//  Astryx
//
//  Created by Mahadik, Amit on 1/23/26.
//

import SwiftUI
import SwiftData

//#if canImport(AIProxy)
import AIProxy
//#endif

@main
struct AstryxApp: App {
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
    
    init() {
        #if canImport(AIProxy)
       /* AIProxy.configure(
            logLevel: .debug,
            printRequestBodies: false,
            printResponseBodies: false,
            resolveDNSOverTLS: true,
            useStableID: true
        )*/
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.aiInsightService, aiService)
        }
        .modelContainer(sharedModelContainer)
    }
}
