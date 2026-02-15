//
//  CosmicConfirmDialog.swift
//  Astryx
//
//  Created by Codex on 2/14/26.
//

import SwiftUI

struct CosmicConfirmDialog: View {
    let title: String
    let message: String

    let confirmTitle: String
    let cancelTitle: String

    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.92))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(cancelTitle) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .tint(CosmicTheme.Colors.moonSilver.opacity(0.20))
                .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.90))

                Button(confirmTitle, role: .destructive) {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.red.opacity(0.85))
            }
        }
        .padding(16)
        .frame(maxWidth: 340)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CosmicTheme.Constants.CornerRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CosmicTheme.Constants.CornerRadius.card, style: .continuous)
                .stroke(CosmicTheme.Colors.accentGlow.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: CosmicTheme.Constants.Glow.color.opacity(0.18), radius: 26, x: 0, y: 14)
        .accessibilityElement(children: .contain)
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CosmicTheme.Constants.CornerRadius.card, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.92)

            RoundedRectangle(cornerRadius: CosmicTheme.Constants.CornerRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            CosmicTheme.Colors.assistantBubble.opacity(0.65),
                            CosmicTheme.Colors.accentGlow.opacity(0.08),
                            CosmicTheme.Colors.assistantBubble.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.85)
        }
    }
}

