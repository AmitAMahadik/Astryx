//
//  DailyAlignmentMeterView.swift
//  Astryx
//
//  Created by Codex on 2/12/26.
//

import SwiftUI

struct DailyAlignmentMeterView: View {
    let overallScore: Int  // 0...100
    let categories: [(String, Int)]

    @State private var animatedProgress: CGFloat = 0

    var body: some View {
        VStack(spacing: 10) {
            dial

            categoryBars
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CosmicTheme.Constants.CornerRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CosmicTheme.Constants.CornerRadius.card, style: .continuous)
                .stroke(CosmicTheme.Colors.accentGlow.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: CosmicTheme.Constants.Glow.color.opacity(0.14), radius: 16, x: 0, y: 8)
        .onAppear {
            animatedProgress = 0
            withAnimation(.easeOut(duration: 0.9)) {
                animatedProgress = progress
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily Alignment")
        .accessibilityValue("\(clampedScore) percent")
    }

    private var dial: some View {
        ZStack {
            Circle()
                .stroke(CosmicTheme.Colors.moonSilver.opacity(0.12), lineWidth: 10)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            CosmicTheme.Colors.accentGlow.opacity(0.95),
                            CosmicTheme.Colors.goldHighlight.opacity(0.75),
                            CosmicTheme.Colors.accentGlow.opacity(0.95)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: CosmicTheme.Colors.accentGlow.opacity(0.25), radius: 10, x: 0, y: 0)

            VStack(spacing: 4) {
                Text("Daily Alignment")
                    .font(CosmicTheme.Typography.smallCaps)
                    .tracking(1.2)
                    .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.70))

                Text("\(clampedScore)%")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.92))
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)
            }
            .multilineTextAlignment(.center)
        }
        .frame(width: 124, height: 124)
    }

    private var categoryBars: some View {
        VStack(spacing: 8) {
            ForEach(categories.prefix(4), id: \.0) { category, score in
                HStack(spacing: 10) {
                    Text(category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.82))
                        .frame(width: 110, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(CosmicTheme.Colors.moonSilver.opacity(0.10))
                                .frame(height: 6)

                            Capsule()
                                .fill(CosmicTheme.Colors.accentGlow.opacity(0.55))
                                .frame(width: proxy.size.width * barProgress(for: score), height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text("\(clamp(score))")
                        .font(.caption2)
                        .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.70))
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
    }

    private var clampedScore: Int { clamp(overallScore) }
    private var progress: CGFloat { CGFloat(clampedScore) / 100.0 }

    private func clamp(_ value: Int) -> Int { min(100, max(0, value)) }
    private func barProgress(for value: Int) -> CGFloat { CGFloat(clamp(value)) / 100.0 }
}

