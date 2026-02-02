//
//  ChatViewModel.swift
//  Astryx
//
//  Updated to support ChatView.swift
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    enum Role: String, Codable {
        case user, assistant, system
    }

    struct Message: Identifiable, Codable {
        let id: UUID
        let role: Role
        var text: String
        let date: Date

        init(id: UUID = .init(), role: Role, text: String, date: Date = .init()) {
            self.id = id
            self.role = role
            self.text = text
            self.date = date
        }
    }

    @Published var messages: [Message] = []
    @Published var input: String = ""
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String? = nil

    private var aiService: any AIInsightService = AIInsightServiceFactory.make()

    // Profile + astrology context injected by the UI (AppState-backed).
    private var profileContext: String = ""
    private var focusHint: String = ""
    private var lunarSign: String = "—"
    private var solarSign: String = "—"
    private var chineseSign: String = "—"

    private var currentSendTask: Task<Void, Never>?

    deinit {
        currentSendTask?.cancel()
    }

    func setService(_ service: any AIInsightService) {
        self.aiService = service
    }

    /// Sets the free-form user profile context (e.g., name/DOB/TOB/place/timezone + any notes).
    /// This is safe to call repeatedly (e.g., before each send) to keep the model grounded.
    func setProfileContext(_ context: String) {
        self.profileContext = context
    }

    /// Sets the current astrology/sign context used to ground chat responses.
    func setAstrologyContext(
        focusHint: String = "",
        lunarSign: String,
        solarSign: String,
        chineseSign: String
    ) {
        self.focusHint = focusHint
        self.lunarSign = lunarSign
        self.solarSign = solarSign
        self.chineseSign = chineseSign
    }

    func seedIfNeeded(profile: String, focusHint: String, lunarSign: String, solarSign: String, chineseSign: String) {
        guard messages.isEmpty else { return }

        setProfileContext(profile)
        setAstrologyContext(
            focusHint: focusHint,
            lunarSign: lunarSign,
            solarSign: solarSign,
            chineseSign: chineseSign
        )

        let nameLine: String = {
            if let line = profile.split(separator: "\n").first(where: { $0.starts(with: "Name:") }) {
                let fullName = line.replacingOccurrences(of: "Name:", with: "").trimmingCharacters(in: .whitespaces)
                let firstName = fullName.split(separator: " ").first.map(String.init) ?? ""
                if !firstName.isEmpty && firstName != "Unknown" {
                    return "Hello, \(firstName)."
                }
            }
            return "Hello."
        }()

        messages.append(.init(role: .assistant, text: """
            \(nameLine) I’m your astrologer guide. Ask a specific question and I’ll tailor the answer to your profile and focus area.
            """))
    }

    func sendPrompt() {
        currentSendTask?.cancel()
        currentSendTask = Task { [weak self] in
            guard let self else { return }
            await self.send()
        }
    }

    private func send() async {
        errorMessage = nil
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        // Append user message
        let userMsg = Message(role: .user, text: trimmed)
        messages.append(userMsg)
        input = ""

        // Append placeholder assistant message
        let assistantMsg = Message(role: .assistant, text: "")
        let assistantID = assistantMsg.id
        messages.append(assistantMsg)

        isStreaming = true
        defer { isStreaming = false }

        do {
            // Optionally include profile/system context
            let system = """
\(ChatViewPrompts.system)

Current date: \(DateFormatter.exAstraISO.string(from: Date()))

User Profile:
\(profileContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(not provided)" : profileContext)

Signs:
- Lunar (Sidereal): \(lunarSign)
- Sun (Western): \(solarSign)
- Chinese: \(chineseSign)

Focus Guidance:
\(focusHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(none)" : focusHint)
"""

            // Build transcript excluding the placeholder assistant message.
            let transcriptLines: [String] = messages
                .filter { $0.id != assistantID }
                .map { message in
                    switch message.role {
                    case .user:
                        return "User: \(message.text)"
                    case .assistant:
                        return "Assistant: \(message.text)"
                    case .system:
                        return "System: \(message.text)"
                    }
                }

            let transcript = transcriptLines.joined(separator: "\n")

            let combinedPrompt = """
SYSTEM:
\(system)

CONVERSATION:
\(transcript)

INSTRUCTIONS:
- Continue the conversation as the Assistant.
- Do not repeat the system prompt.
- Be concise and specific.
"""

            // Stream response using AIProxy-backed service.
            let stream = try await aiService.streamText(prompt: combinedPrompt, secondsToWait: 60)
            for try await delta in stream {
                try Task.checkCancellation()
                guard !delta.isEmpty else { continue }
                if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                    messages[idx].text += delta
                }
            }

            if let idx = messages.firstIndex(where: { $0.id == assistantID }),
               messages[idx].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages[idx].text = "I couldn’t generate a response."
            }
        } catch {
            // Remove placeholder if empty
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                if messages[idx].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    messages.remove(at: idx)
                } else {
                    messages[idx].text = "Sorry — something went wrong."
                }
            }
            errorMessage = error.localizedDescription
        }
    }
}

private extension DateFormatter {
    static let exAstraISO: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
