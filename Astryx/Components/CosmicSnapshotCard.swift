//
//  CosmicSnapshotCard.swift
//  Astryx
//
//  Created by Codex on 2/12/26.
//

import SwiftUI

struct CosmicSnapshotCard: View {
    struct ProfileSummary: Equatable {
        var sunSign: String
        var moonSign: String
        var chineseAnimal: String
        var chineseElement: String
    }

    @Environment(\.displayScale) private var displayScale

    let summary: ProfileSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COSMIC SNAPSHOT")
                .font(CosmicTheme.Typography.smallCaps)
                .tracking(1.4)
                .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.70))

            row(
                systemName: "sun.max.fill",
                label: "Sun",
                value: summary.sunSign
            )

            minimalSeparator

            row(
                systemName: "moon.stars.fill",
                label: "Moon",
                value: summary.moonSign
            )

            minimalSeparator

            row(
                systemName: "pawprint.fill",
                label: "Chinese zodiac",
                value: chineseZodiacDisplay
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CosmicTheme.Constants.CornerRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CosmicTheme.Constants.CornerRadius.card, style: .continuous)
                .stroke(CosmicTheme.Colors.accentGlow.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: CosmicTheme.Constants.Glow.color.opacity(0.18), radius: 18, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cosmic snapshot")
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CosmicTheme.Constants.CornerRadius.card, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.88)

            RoundedRectangle(cornerRadius: CosmicTheme.Constants.CornerRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            CosmicTheme.Colors.assistantBubble.opacity(0.80),
                            CosmicTheme.Colors.accentGlow.opacity(0.08),
                            CosmicTheme.Colors.assistantBubble.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.70)
        }
    }

    private func row(systemName: String, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            iconCircle(systemName: systemName)

            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.85))

            Spacer(minLength: 8)

            Text(value.isEmpty ? "—" : value)
                .font(.subheadline)
                .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.88))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
    }

    private func iconCircle(systemName: String) -> some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.90))
            .frame(width: 28, height: 28)
            .background {
                Circle()
                    .fill(CosmicTheme.Colors.backgroundEnd.opacity(0.40))
                    .overlay {
                        Circle()
                            .stroke(CosmicTheme.Colors.moonSilver.opacity(0.12), lineWidth: 1)
                    }
                    .shadow(color: CosmicTheme.Constants.Glow.color.opacity(0.10), radius: 10, x: 0, y: 0)
            }
            .accessibilityHidden(true)
    }

    private var minimalSeparator: some View {
        let hairline = max(1.0 / displayScale, 0.5)
        return Rectangle()
            .fill(CosmicTheme.Colors.moonSilver.opacity(0.10))
            .frame(height: hairline)
            .padding(.leading, 38)
            .accessibilityHidden(true)
    }

    private var chineseZodiacDisplay: String {
        let element = summary.chineseElement.trimmingCharacters(in: .whitespacesAndNewlines)
        let animal = summary.chineseAnimal.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (element.isEmpty, animal.isEmpty) {
        case (false, false): return "\(element) \(animal)"
        case (true, false): return animal
        case (false, true): return element
        default: return "—"
        }
    }
}

