//
//  CosmicInputBar.swift
//  Astryx
//
//  Created by Codex on 2/12/26.
//

import SwiftUI

struct CosmicInputBar: View {
    @Binding var text: String

    let isStreaming: Bool
    let onSubmit: () -> Void
    let onSend: () -> Void

    private let cornerRadius: CGFloat = 18

    @State private var streakPhase: CGFloat = 0
    @State private var showStreak: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            constellationIcon

            TextField("Ask the stars…", text: $text)
                .textFieldStyle(.plain)
                .disabled(isStreaming)
                .onSubmit(onSubmit)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(CosmicTheme.Colors.moonSilver.opacity(0.06))
                )

            if isStreaming {
                CosmicThinkingView()
            }

            Button {
                playShootingStarAnimation()
                onSend()
            } label: {
                shootingStarIcon
            }
            .disabled(isSendDisabled)
            .accessibilityLabel("Send")
        }
        .padding(12)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(CosmicTheme.Colors.accentGlow.opacity(0.16), lineWidth: 1)
                .shadow(color: CosmicTheme.Constants.Glow.color.opacity(0.12), radius: 10, x: 0, y: 0)
        }
    }

    private var isSendDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming
    }

    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thinMaterial)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            CosmicTheme.Colors.assistantBubble.opacity(0.55),
                            CosmicTheme.Colors.accentGlow.opacity(0.06),
                            CosmicTheme.Colors.assistantBubble.opacity(0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.70)
        }
    }

    private var constellationIcon: some View {
        Image(systemName: "sparkles")
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.85))
            .frame(width: 30, height: 30)
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

    private var shootingStarIcon: some View {
        ZStack {
            if showStreak {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                CosmicTheme.Colors.goldHighlight.opacity(0.55),
                                CosmicTheme.Colors.accentGlow.opacity(0.35),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 26, height: 2)
                    .offset(x: -10 + (streakPhase * 18), y: 8)
                    .opacity(0.85 - (streakPhase * 0.35))
                    .blur(radius: 0.6)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            Image(systemName: "paperplane.fill")
                .rotationEffect(.degrees(45))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(isSendDisabled ? 0.45 : 0.90))
                .padding(10)
        }
    }

    private func playShootingStarAnimation() {
        guard !isSendDisabled else { return }

        showStreak = true
        streakPhase = 0

        withAnimation(.easeOut(duration: 0.28)) {
            streakPhase = 1
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 340_000_000)
            showStreak = false
            streakPhase = 0
        }
    }
}

