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

    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding()
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
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding([.horizontal, .bottom], 8)
            }

            HStack(spacing: 8) {
                TextField("Ask a question...", text: $viewModel.input)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isStreaming)
                    .onSubmit {
                        viewModel.sendPrompt()
                    }

                if viewModel.isStreaming {
                    ProgressView()
                        .progressViewStyle(.circular)
                }

                Button(action: {
                    viewModel.sendPrompt()
                }) {
                    Image(systemName: "paperplane.fill")
                        .rotationEffect(.degrees(45))
                        .padding(8)
                }
                .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
            }
            .padding()
            .background(.thinMaterial)
        }
        .navigationTitle("Chat")
        .task {
            viewModel.setService(aiService)
        }
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
                    .cornerRadius(12)

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
            return Color.accentColor.opacity(0.15)
        case .assistant:
            return Color.secondary.opacity(0.12)
        case .system:
            return Color.yellow.opacity(0.12)
        }
    }
}
