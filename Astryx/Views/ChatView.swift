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

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.messages.isEmpty {
                            emptyStateCard
                        }

                        ForEach(viewModel.messages) { message in
                            messageRow(message)
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

            HStack(spacing: 8) {
                TextField("Ask a question...", text: $viewModel.input)
                    .textFieldStyle(.plain)
                    .disabled(viewModel.isStreaming)
                    .onSubmit {
                        syncContextToViewModel()
                        viewModel.sendPrompt()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                    )

                if viewModel.isStreaming {
                    ProgressView()
                        .progressViewStyle(.circular)
                }

                Button(action: {
                    syncContextToViewModel()
                    viewModel.sendPrompt()
                }) {
                    Image(systemName: "paperplane.fill")
                        .rotationEffect(.degrees(45))
                        .padding(10)
                }
                .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.thinMaterial)
            )
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .navigationTitle("Astryx Chat")
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
    private func messageRow(_ message: ChatViewModel.Message) -> some View {
        HStack {
            if message.role == .assistant { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.text.isEmpty ? (message.role == .assistant ? "..." : "") : message.text)
                    .font(message.role == .assistant ? .system(.body, design: .monospaced) : .body)
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(bubbleColor(for: message.role))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(message.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 8)
    }

    private func bubbleColor(for role: ChatViewModel.Role) -> Color {
        switch role {
        case .user:
            return Color.accentColor.opacity(0.18)
        case .assistant:
            return Color.secondary.opacity(0.12)
        case .system:
            return Color.yellow.opacity(0.12)
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
