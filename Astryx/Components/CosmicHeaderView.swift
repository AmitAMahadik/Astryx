//
//  CosmicHeaderView.swift
//  Astryx
//
//  Created by Codex on 2/12/26.
//

import SwiftUI

struct CosmicHeaderView: View {
    let showsDivider: Bool

    @State private var shimmerPhase: CGFloat = -1

    init(showsDivider: Bool = true) {
        self.showsDivider = showsDivider
    }

    var body: some View {
        VStack(spacing: showsDivider ? 8 : 2) {
            VStack(spacing: 2) {
                shimmerTitle

                Text("AI CELESTIAL GUIDE")
                    .font(CosmicTheme.Typography.smallCaps)
                    .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.70))
                    .tracking(1.6)
                    .accessibilityAddTraits(.isHeader)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            if showsDivider {
                dividerGlowLine
            }
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
            // Slightly smaller than the full-screen header version so it fits comfortably
            // when hosted in a navigation bar's principal toolbar area.
            .font(.system(size: 22, weight: .bold, design: .rounded))
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
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(2.2)
            )
            .accessibilityLabel("ASTRYX")
    }

    private var dividerGlowLine: some View {
        return ZStack {
            Rectangle()
                .fill(CosmicTheme.Colors.accentGlow.opacity(0.18))
                .frame(height: 1)

            Rectangle()
                .fill(CosmicTheme.Colors.accentGlow.opacity(0.12))
                .frame(height: 1)
                .blur(radius: 6)
        }
        .padding(.horizontal, 16)
        .accessibilityHidden(true)
    }
}

