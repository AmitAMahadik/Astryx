//
//  FocusSummaryViewModel.swift
//  Astryx
//
//  Created by Mahadik, Amit on 1/25/26.
//


//
//  FocusSummaryViewModel.swift
//  Astryx
//
//  Created by Axolotl Labs LLC
//

import Foundation
import Combine

// MARK: - ViewModel

final class FocusSummaryViewModel: ObservableObject {

    // Back-side content per FocusArea (what your FocusCardView shows when flipped).
    @Published private(set) var backTextByArea: [FocusArea: String] = [:]

    // Loading / error state per FocusArea.
    @Published private(set) var isLoadingByArea: [FocusArea: Bool] = [:]
    @Published private(set) var errorMessageByArea: [FocusArea: String?] = [:]

    // Optional: track when each area was last refreshed.
    @Published private(set) var lastUpdatedByArea: [FocusArea: Date] = [:]

    private let service: FocusSummaryServiceProtocol

    init(service: FocusSummaryServiceProtocol = DefaultFocusSummaryService()) {
        self.service = service
    }

    // Convenience getter used by Views
    func backText(for area: FocusArea) -> String {
        backTextByArea[area] ?? "—"
    }

    func isLoading(for area: FocusArea) -> Bool {
        isLoadingByArea[area] ?? false
    }

    func errorMessage(for area: FocusArea) -> String? {
        errorMessageByArea[area] ?? nil
    }

    /// Stream-generate (or fetch) a summary for an area and progressively update `backTextByArea[area]`.
    ///
    /// Call this when the user flips/expands a card and you want to populate the back side.
    @MainActor
    func streamSummary(
        for area: FocusArea,
        context: FocusSummaryContext
    ) async {
        // Prevent duplicate concurrent streams for the same area.
        if isLoading(for: area) { return }

        isLoadingByArea[area] = true
        errorMessageByArea[area] = nil

        // Ensure there is always some initial content (prevents empty back side).
        if (backTextByArea[area] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            backTextByArea[area] = "…"
        }

        var buffer = ""

        do {
            for try await chunk in service.streamSummary(for: area, context: context) {
                buffer.append(chunk)
                backTextByArea[area] = buffer
            }

            backTextByArea[area] = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            lastUpdatedByArea[area] = Date()
        } catch {
            errorMessageByArea[area] = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription

            // Keep any partial output, but if none, show a fallback.
            if buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                backTextByArea[area] = "Unable to generate summary right now."
            }
        }

        isLoadingByArea[area] = false
    }

    /// Optionally clear cached content (e.g., when user changes date/context).
    @MainActor
    func reset(area: FocusArea? = nil) {
        if let area {
            backTextByArea.removeValue(forKey: area)
            isLoadingByArea.removeValue(forKey: area)
            errorMessageByArea.removeValue(forKey: area)
            lastUpdatedByArea.removeValue(forKey: area)
        } else {
            backTextByArea.removeAll()
            isLoadingByArea.removeAll()
            errorMessageByArea.removeAll()
            lastUpdatedByArea.removeAll()
        }
    }
}

// MARK: - Context

/// Everything the model needs to craft a good prompt without depending on SwiftUI.
struct FocusSummaryContext: Sendable {
    var date: Date = .init()
    var timezoneIdentifier: String = TimeZone.current.identifier

    // Add fields as needed:
    // var userName: String?
    // var localeIdentifier: String = Locale.current.identifier
    // var natalChartSummary: String?
    // var currentTransitsSummary: String?
    // var userNotes: String?
}

// MARK: - Service Protocol

/// Abstraction so your ViewModel is testable and you can swap implementations (AIProxy, Azure, etc.)
protocol FocusSummaryServiceProtocol: Sendable {
    func streamSummary(
        for area: FocusArea,
        context: FocusSummaryContext
    ) -> AsyncThrowingStream<String, Error>
}

// MARK: - Default Service (Placeholder)

/// Replace the internals of this type with your real implementation (AIProxy/OpenAI/Azure/etc.).
///
/// This placeholder streams a deterministic, preview-friendly response so the app builds
/// even before you wire up the network/LLM path.
struct DefaultFocusSummaryService: FocusSummaryServiceProtocol {

    func streamSummary(
        for area: FocusArea,
        context: FocusSummaryContext
    ) -> AsyncThrowingStream<String, Error> {

        let fullText = cannedText(for: area)
        let chunks = chunk(fullText, size: 18)

        return AsyncThrowingStream { continuation in
            Task.detached {
                for c in chunks {
                    try? await Task.sleep(nanoseconds: 75_000_000) // 75ms
                    continuation.yield(c)
                }

                continuation.finish()
            }
        }
    }

    private func cannedText(for area: FocusArea) -> String {
        switch area {
        case .health:
            return """
            Overall: steady momentum.

            Haiku
            Breathe into the day
            Small habits turn the wheel
            Consistency wins

            Do: hydrate, a 20–30 min walk, early protein.
            Avoid: late caffeine, doom-scrolling past midnight.
            """
        case .career:
            return """
            Overall: focus beats intensity.

            Haiku
            One clear next action
            Cuts through the noisy backlog
            Progress feels easy

            Do: time-box one deep-work block, ship a small win.
            Avoid: context-switching and “urgent” slack spirals.
            """
        case .travel:
            return """
            Overall: simplicity brings luck.

            Haiku
            Light bag, open heart
            Leave space in the itinerary
            Serendipity

            Do: pick one anchor activity, explore locally.
            Avoid: over-optimizing every minute.
            """
        case .relationships:
            return """
            Overall: soften the approach.

            Haiku
            Say the gentle thing
            Let curiosity lead first
            Warmth opens the door

            Do: ask one honest question, listen fully.
            Avoid: rehearsing arguments in your head.
            """
        case .wealth:
            return """
            Overall: tighten the feedback loop.

            Haiku
            Numbers tell the truth
            Small trims create breathing room
            Future thanks you

            Do: review subscriptions, automate one transfer.
            Avoid: impulse buys when tired or stressed.
            """
        case .purpose:
            return """
            Overall: clarity through reflection.

            Haiku
            Quiet mind reveals
            What truly lights your spirit
            Path becomes clear

            Do: journal 5 minutes on core values.
            Avoid: distractions that cloud your vision.
            """
        case .education:
            return """
            Overall: steady steps win.

            Haiku
            Daily learning sows
            Seeds of knowledge gently grow
            Wisdom lights the way

            Do: 15 minutes reading or practice.
            Avoid: all-or-nothing study binges.
            """

        }
    }

    private func chunk(_ text: String, size: Int) -> [String] {
        guard size > 0 else { return [text] }
        var result: [String] = []
        var idx = text.startIndex

        while idx < text.endIndex {
            let end = text.index(idx, offsetBy: size, limitedBy: text.endIndex) ?? text.endIndex
            result.append(String(text[idx..<end]))
            idx = end
        }
        return result
    }
}
