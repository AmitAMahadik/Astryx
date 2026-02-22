//
//  AppConfig.swift
//  Astryx
//
//  Created by Mahadik, Amit on 2/1/26.
//


import Foundation

enum AppConfig {
    /// Base URL for the Swiss Ephemeris MCP server. Replace with your deployed endpoint (e.g. Azure Container Apps).
    static let mcpBaseURL: URL = URL(string: "https://swiss-ephemeris-mcp.jollycoast-183c219a.westus.azurecontainerapps.io")!
}
