//
//  ChatView.swift
//  Astryx
//
//  Created by Mahadik, Amit on 1/24/26.
//

// swift
// ChatView (put in `ChatView.swift`)
import SwiftUI

struct ChatView: View {
    @Environment(\.aiInsightService) private var aiService
    @EnvironmentObject private var state: AppState
    @AppStorage("selectedProfileID") private var selectedProfileID: String = ""

    @StateObject private var viewModel = ChatViewModel()
    @State private var showClearChatConfirmation = false
    @State private var showSnapshotCardThisSession = true

    var body: some View {
        ZStack {
            CosmicBackgroundView(variant: .chat)

            VStack(spacing: 0) {
                CosmicHeaderView()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if viewModel.messages.isEmpty {
                                emptyStateCard
                            }

                            let firstAssistantIndex = viewModel.messages.firstIndex(where: { $0.role == .assistant })
                            ForEach(viewModel.messages.indices, id: \.self) { idx in
                                let message = viewModel.messages[idx]

                                if shouldShowSnapshotCard, let firstAssistantIndex, idx == firstAssistantIndex {
                                    CosmicSnapshotCard(summary: makeProfileSummary())
                                }

                                messageRow(message, at: idx)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.clear)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        // Scroll to bottom on new message
                        if let last = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.18)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                CosmicInputBar(
                    text: $viewModel.input,
                    isStreaming: viewModel.isStreaming,
                    onSubmit: {
                        syncContextToViewModel()
                        viewModel.sendPrompt()
                    },
                    onSend: {
                        syncContextToViewModel()
                        viewModel.sendPrompt()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 80) // Extra bottom padding to account for the tab bar and safe area
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showClearChatConfirmation = true
                } label: {
                    Label("Clear Chat", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Clear chat history?",
            isPresented: $showClearChatConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Chat", role: .destructive) {
                viewModel.clearChat()
                syncContextToViewModel(seedWelcomeIfNeeded: true)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all messages for the selected profile.")
        }
        .task {
            viewModel.setService(aiService)
            viewModel.activateProfile(id: selectedProfileID)
            syncContextToViewModel(seedWelcomeIfNeeded: true)
        }
        .onChange(of: selectedProfileID) { _, newProfileID in
            viewModel.activateProfile(id: newProfileID)
            syncContextToViewModel(seedWelcomeIfNeeded: true)
        }
    }

    private var emptyStateCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .symbolRenderingMode(.hierarchical)
            Text("Your previous conversation for this profile appears here. Ask a question to begin.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func messageRow(_ message: ChatViewModel.Message, at index: Int) -> some View {
        HStack {
            if message.role == .assistant { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                if message.role == .assistant {
                    HStack(alignment: .top, spacing: 10) {
                        AstryxOrbView(isAnimating: isGeneratingAssistantMessage(message))
                            // Nudges the orb down slightly so it aligns with the first text line cap-height.
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 8) {
                            if shouldShowDailyAlignmentMeter(forAssistantAt: index) {
                                DailyAlignmentMeterView(
                                    overallScore: dailyAlignmentData(forAssistantAt: index).overall,
                                    categories: dailyAlignmentData(forAssistantAt: index).categories
                                )
                            }

                            CosmicChatBubble(role: .assistant, text: message.text)
                        }
                    }
                } else {
                    CosmicChatBubble(
                        role: message.role == .user ? .user : .assistant,
                        text: message.text
                    )
                }

                Text(message.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 8)
    }

    private func isGeneratingAssistantMessage(_ message: ChatViewModel.Message) -> Bool {
        guard message.role == .assistant else { return false }
        return viewModel.isStreaming && message.id == viewModel.messages.last?.id
    }

    private func shouldShowDailyAlignmentMeter(forAssistantAt index: Int) -> Bool {
        guard index < viewModel.messages.count else { return false }
        guard viewModel.messages[index].role == .assistant else { return false }
        guard let userText = previousUserText(before: index) else { return false }
        return isDayQuestion(userText)
    }

    private func previousUserText(before index: Int) -> String? {
        guard index > 0 else { return nil }
        for i in stride(from: index - 1, through: 0, by: -1) {
            if viewModel.messages[i].role == .user {
                return viewModel.messages[i].text
            }
        }
        return nil
    }

    private func isDayQuestion(_ text: String) -> Bool {
        let tokens = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return tokens.contains("today") || tokens.contains("day")
    }

    private func dailyAlignmentData(forAssistantAt index: Int) -> (overall: Int, categories: [(String, Int)]) {
        // Deterministic placeholder values derived from profile + day-of-year + prompt text.
        // This is UI-only and does not change any back-end AI behavior.
        let userText = previousUserText(before: index) ?? ""
        let seedString = "\(selectedProfileID)|\(state.name)|\(dayOfYearUTC())|\(userText)"
        var rng = StableRNG(seed: stableHash64(seedString))

        let career = rng.nextInt(in: 35...98)
        let love = rng.nextInt(in: 35...98)
        let communication = rng.nextInt(in: 35...98)
        let creativity = rng.nextInt(in: 35...98)

        let overall = (career + love + communication + creativity) / 4
        return (
            overall: overall,
            categories: [
                ("Career", career),
                ("Love", love),
                ("Communication", communication),
                ("Creativity", creativity)
            ]
        )
    }

    private func dayOfYearUTC() -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return cal.ordinality(of: .day, in: .year, for: Date()) ?? 0
    }

    private func stableHash64(_ string: String) -> UInt64 {
        // FNV-1a 64-bit
        let bytes = Array(string.utf8)
        var hash: UInt64 = 14695981039346656037
        for b in bytes {
            hash ^= UInt64(b)
            hash &*= 1099511628211
        }
        return hash
    }

    private struct StableRNG {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed == 0 ? 0xD1B5_D00D_CAFE_F00D : seed
        }

        mutating func nextUInt64() -> UInt64 {
            // xorshift64*
            var x = state
            x ^= x >> 12
            x ^= x << 25
            x ^= x >> 27
            state = x
            return x &* 2685821657736338717
        }

        mutating func nextInt(in range: ClosedRange<Int>) -> Int {
            let lower = range.lowerBound
            let upper = range.upperBound
            guard upper >= lower else { return lower }
            let span = UInt64(upper - lower + 1)
            let value = nextUInt64() % span
            return lower + Int(value)
        }
    }

    private var shouldShowSnapshotCard: Bool {
        showSnapshotCardThisSession
        && stateHasProfileData
        && viewModel.messages.contains(where: { $0.role == .assistant })
    }

    private var stateHasProfileData: Bool {
        !state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || state.solarSign != "—"
        || state.lunarSignDeterministic != "—"
        || state.chineseSign != "—"
    }

    private func makeProfileSummary() -> CosmicSnapshotCard.ProfileSummary {
        let birthMomentUTC = (try? state.birthMomentUTC()) ?? state.dob
        let zodiac = ChineseZodiac.zodiac(for: birthMomentUTC)

        return CosmicSnapshotCard.ProfileSummary(
            sunSign: state.solarSign,
            moonSign: state.lunarSignDeterministic,
            chineseAnimal: zodiac.animal,
            chineseElement: zodiac.element
        )
    }

    private func syncContextToViewModel(seedWelcomeIfNeeded: Bool = false) {
        let profileContext = makeProfileContext()
        viewModel.setProfileContext(profileContext)
        viewModel.setAstrologyContext(
            focusHint: "",
            lunarSign: state.lunarSignDeterministic,
            solarSign: state.solarSign,
            chineseSign: state.chineseSign
        )

        if seedWelcomeIfNeeded {
            viewModel.seedIfNeeded(
                profile: profileContext,
                focusHint: "",
                lunarSign: state.lunarSignDeterministic,
                solarSign: state.solarSign,
                chineseSign: state.chineseSign
            )
        }
    }

    private func makeProfileContext() -> String {
        let dob = state.dob.formatted(date: .abbreviated, time: .omitted)
        let tob = String(format: "%02d:%02d:%02d", state.tobHour, state.tobMinute, state.tobSecond)
        let tz = state.birthTimeZoneIdentifier ?? ""

        // Prefer the cached deterministic lunar sign when available.
        let lunar = state.lunarSignDeterministic

        return """
        Name: \(state.name)
        Gender: \(state.gender.rawValue)
        DOB: \(dob)
        TOB: \(tob)
        Place: \(state.placeOfBirth)
        Timezone: \(tz)

        Solar sign (Western): \(state.solarSign)
        Lunar sign (Sidereal): \(lunar)
        Chinese sign: \(state.chineseSign)
        """
    }
}
