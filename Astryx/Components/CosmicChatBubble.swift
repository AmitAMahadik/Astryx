//
//  CosmicChatBubble.swift
//  Astryx
//
//  Created by Codex on 2/12/26.
//

import SwiftUI

struct CosmicChatBubble: View {
    enum Role {
        case user
        case assistant
    }

    let role: Role
    let text: String

    private let cornerRadius: CGFloat = 22
    private let contentPadding: CGFloat = 12

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            bubbleBackground

            if role == .assistant {
                // Optional zodiac watermark (placeholder symbol for now).
                Image(systemName: "sparkles")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.03))
                    .padding(10)
                    .rotationEffect(.degrees(-10))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            Text(displayText)
                .font(role == .assistant ? .system(.body, design: .monospaced) : .body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(role == .user ? .trailing : .leading)
                .padding(contentPadding)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .compositingGroup()
    }

    private var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return role == .assistant ? "..." : ""
        }
        return text
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        switch role {
        case .assistant:
            assistantBackground
        case .user:
            userBackground
        }
    }

    private var assistantBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.82)

            // A gentle gradient tint to keep the glass feeling "cosmic" rather than gray.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            CosmicTheme.Colors.assistantBubble.opacity(0.85),
                            CosmicTheme.Colors.accentGlow.opacity(0.10),
                            CosmicTheme.Colors.assistantBubble.opacity(0.70)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.65)

            // Inner glow: a subtle border + soft glow.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(CosmicTheme.Colors.accentGlow.opacity(0.18), lineWidth: 1)
                .shadow(color: CosmicTheme.Constants.Glow.color.opacity(0.18), radius: 10, x: 0, y: 0)
        }
    }

    private var userBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            CosmicTheme.Colors.backgroundEnd.opacity(0.92),
                            CosmicTheme.Colors.backgroundStart.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(CosmicTheme.Colors.moonSilver.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 4)
    }
}

