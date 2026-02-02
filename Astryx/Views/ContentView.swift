//
//  ContentView.swift
//  Astryx
//
//  Created by Mahadik, Amit on 1/23/26.
//

import SwiftUI
import SwiftData


struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationSplitView {
            List {
                Section {
                    NavigationLink {
                        SwissEphemerisMCPTestView()
                    } label: {
                        Label("Swiss Ephemeris MCP Test", systemImage: "wave.3.right")
                    }

                    NavigationLink {
                        AIProxyTestView()
                    } label: {
                        Label("AIProxy Test", systemImage: "sparkles")
                    }
                }

                Section("Items") {
                    ForEach(viewModel.items) { item in
                        NavigationLink {
                            Text(
                                "Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))"
                            )
                        } label: {
                            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                        }
                    }
                    .onDelete { offsets in
                        withAnimation {
                            viewModel.deleteItems(using: modelContext, offsets: offsets)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button {
                        withAnimation {
                            viewModel.addItem(using: modelContext)
                        }
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .overlay {
                if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Something went wrong",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                }
            }
            .task {
                // `.task` runs on appearance and is cancelable; ideal for initial load.
                viewModel.loadItems(using: modelContext)
            }
        } detail: {
            Text("Select an item or open the MCP test")
        }
    }
}

// The following view is added before #Preview
struct SwissEphemerisMCPTestView: View {
    @State private var zodiac: ZodiacSystem = .siderealLahiri
    @State private var datetimeUTC: Date = Date()

    // Default to San Jose, CA (approx) for quick testing.
    @State private var latitudeText: String = "37.3382"
    @State private var longitudeText: String = "-121.8863"

    @State private var isRunning: Bool = false
    @State private var output: String = ""
    @State private var errorMessage: String?

    private let client = SwissEphemerisMCPClient(baseURL: AppConfig.mcpBaseURL)

    var body: some View {
        Form {
            Section("Request") {
                Picker("Zodiac", selection: $zodiac) {
                    Text("Sidereal (Lahiri)").tag(ZodiacSystem.siderealLahiri)
                    Text("Tropical").tag(ZodiacSystem.tropical)
                }

                DatePicker(
                    "Datetime (UTC)",
                    selection: $datetimeUTC,
                    displayedComponents: [.date, .hourAndMinute]
                )

                TextField("Latitude", text: $latitudeText)
                    .keyboardType(.numbersAndPunctuation)

                TextField("Longitude", text: $longitudeText)
                    .keyboardType(.numbersAndPunctuation)

                Button {
                    Task { await runMoonInfo() }
                } label: {
                    if isRunning {
                        ProgressView()
                    } else {
                        Label("Fetch Moon Info", systemImage: "moon.stars")
                    }
                }
                .disabled(isRunning)

                Button(role: .destructive) {
                    Task { await resetSession() }
                } label: {
                    Label("Reset MCP Session", systemImage: "arrow.counterclockwise")
                }
                .disabled(isRunning)
            }

            Section("Response") {
                if let errorMessage {
                    ContentUnavailableView(
                        "Request failed",
                        systemImage: "xmark.octagon",
                        description: Text(errorMessage)
                    )
                }

                Text(output.isEmpty ? "(No output yet)" : output)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            Section("Notes") {
                Text("This view calls SwissEphemerisMCPClient.fetchMoonInfo(...) and displays the parsed Moon longitude/sign/degree. Ensure your Container Apps endpoint is reachable and returning SSE responses.")
            }
        }
        .navigationTitle("Swiss Ephemeris MCP")
    }

    private func runMoonInfo() async {
        isRunning = true
        defer { isRunning = false }
        errorMessage = nil
        output = ""

        do {
            let lat = try parseDouble(latitudeText, fieldName: "Latitude")
            let lon = try parseDouble(longitudeText, fieldName: "Longitude")

            let moon = try await client.fetchMoonInfo(
                datetimeUTC: datetimeUTC,
                latitude: lat,
                longitude: lon,
                zodiac: zodiac
            )

            output = [
                "Moon Info",
                "- Zodiac: \(zodiac.rawValue)",
                "- UTC: \(datetimeUTC.formatted(.iso8601))",
                "- Latitude: \(lat)",
                "- Longitude: \(lon)",
                "- Longitude (ecliptic): \(moon.longitude)",
                "- Sign: \(moon.sign)",
                "- Degree in sign: \(moon.degreeInSign)"
            ].joined(separator: "\n")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetSession() async {
        await client.resetSession()
        output = "MCP session reset. Next request will re-initialize."
        errorMessage = nil
    }

    private func parseDouble(_ text: String, fieldName: String) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed) else {
            throw NSError(
                domain: "Astryx",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "\(fieldName) must be a number."]
            )
        }
        return value
    }
}

struct AIProxyTestView: View {
    @Environment(\.aiInsightService) private var ai

    @State private var prompt: String = "Reply with exactly: AIProxy OK"
    @State private var isRunning: Bool = false
    @State private var output: String = ""
    @State private var errorMessage: String?

    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }
    private var bundleID: String { Bundle.main.bundleIdentifier ?? "(nil)" }

    private var partialKey: String? { info["AIPROXY_PARTIAL_KEY"] as? String }
    private var serviceURL: String? { info["AIPROXY_SERVICE_URL"] as? String }

    private var aiproxyKeys: [String] {
        info.keys
            .filter { $0.uppercased().contains("AIPROXY") }
            .sorted()
    }

    private func masked(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return trimmed }
        let prefix = trimmed.prefix(4)
        let suffix = trimmed.suffix(4)
        return "\(prefix)…\(suffix)"
    }

    var body: some View {
        Form {
            Section("Request") {
                TextEditor(text: $prompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)

                Button {
                    Task { await runTest() }
                } label: {
                    if isRunning {
                        ProgressView()
                    } else {
                        Label("Run AIProxy Test", systemImage: "play.fill")
                    }
                }
                .disabled(isRunning)
            }

            Section("Response") {
                if let errorMessage {
                    ContentUnavailableView(
                        "Request failed",
                        systemImage: "xmark.octagon",
                        description: Text(errorMessage)
                    )
                }

                Text(output.isEmpty ? "(No output yet)" : output)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("AIProxy Test")
    }

    @MainActor
    private func runTest() async {
        isRunning = true
        defer { isRunning = false }
        errorMessage = nil
        output = ""

        do {
            let text = try await ai.generateText(prompt: prompt)
            output = text
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
