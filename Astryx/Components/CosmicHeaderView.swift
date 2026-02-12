//
//  CosmicHeaderView.swift
//  Astryx
//
//  Created by Codex on 2/12/26.
//

import SwiftUI

struct CosmicHeaderView: View {
    @Environment(\.displayScale) private var displayScale

    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                iconChrome(systemName: "moon.stars.fill")
                    .accessibilityLabel("Moon")

                Spacer(minLength: 0)

                VStack(spacing: 2) {
                    shimmerTitle

                    Text("AI CELESTIAL GUIDE")
                        .font(CosmicTheme.Typography.smallCaps)
                        .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.70))
                        .tracking(1.6)
                        .accessibilityAddTraits(.isHeader)
                }
                .multilineTextAlignment(.center)

                Spacer(minLength: 0)

                iconChrome(systemName: "slider.horizontal.3")
                    .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            dividerGlowLine
        }
        .onAppear {
            // A single lightweight repeating animation; shimmer is masked to the title only.
            shimmerPhase = -1
            withAnimation(.linear(duration: 3.8).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }

    private var shimmerTitle: some View {
        Text("ASTRYX")
            .font(CosmicTheme.Typography.title)
            .tracking(2.2)
            .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.92))
            .overlay {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let x = (shimmerPhase * w) - (w * 0.5)

                    LinearGradient(
                        colors: [
                            .clear,
                            CosmicTheme.Colors.accentGlow.opacity(0.22),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: max(1, w * 0.8), height: proxy.size.height * 2)
                    .rotationEffect(.degrees(18))
                    .offset(x: x)
                    .blendMode(.screen)
                    .opacity(0.75)
                }
            }
            .mask(
                Text("ASTRYX")
                    .font(CosmicTheme.Typography.title)
                    .tracking(2.2)
            )
            .accessibilityLabel("ASTRYX")
    }

    private func iconChrome(systemName: String) -> some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.90))
            .frame(width: 36, height: 36)
            .background {
                Circle()
                    .fill(.thinMaterial)
                    .overlay {
                        Circle()
                            .stroke(CosmicTheme.Colors.accentGlow.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: CosmicTheme.Constants.Glow.color.opacity(0.35), radius: 10, x: 0, y: 0)
            }
    }

    private var dividerGlowLine: some View {
        let hairline = max(1.0 / displayScale, 0.5)
        return ZStack {
            Rectangle()
                .fill(CosmicTheme.Colors.accentGlow.opacity(0.18))
                .frame(height: hairline)

            Rectangle()
                .fill(CosmicTheme.Colors.accentGlow.opacity(0.12))
                .frame(height: hairline)
                .blur(radius: 6)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .accessibilityHidden(true)
    }
}

