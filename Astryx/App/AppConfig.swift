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
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            value != "$(MCP_BASE_URL)",
            let url = URL(string: value)
        else {
            fatalError("❌ MCP_BASE_URL missing or invalid. Copy Secrets.xcconfig.example to Secrets.xcconfig and set MCP_BASE_URL to your MCP server URL.")
        }
        return url
    }()
}