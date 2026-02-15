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
    
    // Clearance so the input bar sits above the floating custom tab bar.
    private let floatingTabBarClearance: CGFloat = 120
    @State private var isKeyboardVisible: Bool = false

    @State private var chatContentWidth: CGFloat = 0
    
    // Snapshot fallbacks for first-run (before cached signs are populated).
    @State private var snapshotSunSignFallback: String = "—"
    @State private var snapshotMoonSignFallback: String = "—"
    @State private var isComputingSnapshotMoon: Bool = false
    
    // Coalesce frequent streaming updates to avoid multiple scroll updates per frame.
    @State private var pendingAutoScrollTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            CosmicBackgroundView(variant: .chat)

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    let lastMessageText = viewModel.messages.last?.text ?? ""
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
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ChatContentWidthKey.self, value: geo.size.width)
                        }
                    )
                    .background(Color.clear)
                    .onPreferenceChange(ChatContentWidthKey.self) { newValue in
                        chatContentWidth = newValue
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        // Scroll to bottom on new message
                        if let last = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.18)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: lastMessageText) { _, _ in
                        // While streaming, keep the latest assistant response pinned to the bottom as it grows.
                        guard viewModel.isStreaming, let last = viewModel.messages.last else { return }
                        let targetID = last.id
                        
                        pendingAutoScrollTask?.cancel()
                        pendingAutoScrollTask = Task {
                            // Small delay to batch multiple deltas into a single UI update.
                            try? await Task.sleep(nanoseconds: 80_000_000)
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                // No animation here to minimize layout thrash during streaming.
                                withTransaction(Transaction(animation: nil)) {
                                    proxy.scrollTo(targetID, anchor: .bottom)
                                }
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
                .padding(.bottom, isKeyboardVisible ? 12 : floatingTabBarClearance)
            }

            if showClearChatConfirmation {
                // Custom confirmation UI to match the cosmic visual style.
                Color.black
                    .opacity(0.42)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showClearChatConfirmation = false
                    }

                CosmicConfirmDialog(
                    title: "Clear chat history?",
                    message: "This will remove all messages for the selected profile.",
                    confirmTitle: "Clear Chat",
                    cancelTitle: "Cancel",
                    onConfirm: {
                        showClearChatConfirmation = false
                        viewModel.clearChat()
                        syncContextToViewModel(seedWelcomeIfNeeded: true)
                    },
                    onCancel: {
                        showClearChatConfirmation = false
                    }
                )
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(50)
            }
        }
        .animation(.easeOut(duration: 0.18), value: showClearChatConfirmation)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Let the cosmic background show through the navigation bar area too.
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                CosmicHeaderView(showsDivider: false)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showClearChatConfirmation = true
                } label: {
                    Label("Clear Chat", systemImage: "trash")
                }
            }
        }
        .task {
            viewModel.setService(aiService)
            viewModel.activateProfile(id: selectedProfileID)
            syncContextToViewModel(seedWelcomeIfNeeded: true)
            await computeSnapshotSignsIfNeeded()
        }
        .onChange(of: selectedProfileID) { _, newProfileID in
            viewModel.activateProfile(id: newProfileID)
            syncContextToViewModel(seedWelcomeIfNeeded: true)
            Task { await computeSnapshotSignsIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
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
            if message.role == .assistant { Spacer(minLength: 28) }

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

                            CosmicChatBubble(
                                role: .assistant,
                                text: message.text,
                                maxWidth: maxBubbleWidth(for: .assistant)
                            )
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        CosmicChatBubble(
                            role: .user,
                            text: message.text,
                            maxWidth: maxBubbleWidth(for: .user)
                        )

                        userAvatarIcon
                            .padding(.top, 2)
                    }
                }

                Text(message.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user { Spacer(minLength: 28) }
        }
        .padding(.horizontal, 8)
    }

    private func maxBubbleWidth(for role: CosmicChatBubble.Role) -> CGFloat {
        // Simple, deterministic sizing that still feels responsive on iPhone.
        let w = chatContentWidth > 0 ? chatContentWidth : 390
        switch role {
        case .assistant: return w * 0.74
        case .user: return w * 0.66
        }
    }

    private var userAvatarIcon: some View {
        Image(systemName: "person.crop.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.85))
            .frame(width: 28, height: 28)
            .background {
                Circle()
                    .fill(CosmicTheme.Colors.backgroundEnd.opacity(0.35))
                    .overlay {
                        Circle()
                            .stroke(CosmicTheme.Colors.moonSilver.opacity(0.10), lineWidth: 1)
                    }
                    .shadow(color: CosmicTheme.Constants.Glow.color.opacity(0.10), radius: 10, x: 0, y: 0)
            }
            .accessibilityHidden(true)
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
            sunSign: preferredSunSign,
            moonSign: preferredMoonSign,
            chineseAnimal: zodiac.animal,
            chineseElement: zodiac.element
        )
    }

    private var preferredSunSign: String {
        let cached = state.solarSign.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cached.isEmpty, cached != "—" { return cached }
        return snapshotSunSignFallback
    }

    private var preferredMoonSign: String {
        let cached = state.lunarSignDeterministic.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cached.isEmpty, cached != "—" { return cached }
        return isComputingSnapshotMoon ? "Calculating…" : snapshotMoonSignFallback
    }

    @MainActor
    private func computeSnapshotSignsIfNeeded() async {
        // Sun sign can be derived from DOB for a deterministic first-run fallback.
        snapshotSunSignFallback = westernSunSign(from: state.dob)

        // If we already have the deterministic lunar sign cached, don't compute.
        let cachedMoon = state.lunarSignDeterministic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cachedMoon.isEmpty || cachedMoon == "—" else { return }

        guard !isComputingSnapshotMoon else { return }
        isComputingSnapshotMoon = true
        defer { isComputingSnapshotMoon = false }

        do {
            let computed = try await state.computeDeterministicMoonInfo()
            snapshotMoonSignFallback = computed.sign
        } catch {
            // If we can't compute yet (missing validated birth data), keep fallback as "—".
            snapshotMoonSignFallback = "—"
        }
    }

    private func westernSunSign(from date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let comps = cal.dateComponents([.month, .day], from: date)
        let m = comps.month ?? 1
        let d = comps.day ?? 1

        // Western tropical Sun sign by month/day (time-of-day not required for typical UX).
        switch (m, d) {
        case (3, 21...31), (4, 1...19): return "Aries"
        case (4, 20...30), (5, 1...20): return "Taurus"
        case (5, 21...31), (6, 1...20): return "Gemini"
        case (6, 21...30), (7, 1...22): return "Cancer"
        case (7, 23...31), (8, 1...22): return "Leo"
        case (8, 23...31), (9, 1...22): return "Virgo"
        case (9, 23...30), (10, 1...22): return "Libra"
        case (10, 23...31), (11, 1...21): return "Scorpio"
        case (11, 22...30), (12, 1...21): return "Sagittarius"
        case (12, 22...31), (1, 1...19): return "Capricorn"
        case (1, 20...31), (2, 1...18): return "Aquarius"
        default: return "Pisces" // (2, 19...29), (3, 1...20)
        }
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

private struct ChatContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
