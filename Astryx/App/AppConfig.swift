//
//  AppConfig.swift
//  Astryx
//
//  Created by Mahadik, Amit on 2/1/26.
//


import Foundation

enum AppConfig {
    static let mcpBaseURL: URL = {
        guard
            let value = Bundle.main.object(
                forInfoDictionaryKey: "MCP_BASE_URL"
            ) as? String,
            let url = URL(string: value)
        else {
            fatalError("❌ MCP_BASE_URL missing or invalid in Info.plist")
        }
        return url
    }()
}