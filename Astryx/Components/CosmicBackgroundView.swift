//
//  CosmicBackgroundView.swift
//  Astryx
//
//  Created by Codex on 2/12/26.
//

import SwiftUI

struct CosmicBackgroundView: View {
    enum Variant {
        case chat
        case profile
        case focus
    }

    private struct Star: Sendable {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
        let driftX: CGFloat
        let driftY: CGFloat
    }

    private struct VariantConfig {
        let glowOpacity: Double
        let starOpacityMultiplier: Double
        let driftMultiplier: CGFloat
    }

    let variant: Variant

    @State private var stars: [Star]
    @State private var startDate = Date()

    init(variant: Variant) {
        self.variant = variant
        _stars = State(initialValue: Self.makeStars(seed: Self.seed(for: variant), count: 120))
    }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    CosmicTheme.Colors.backgroundStart,
                    CosmicTheme.Colors.backgroundEnd
                ],
                center: .topLeading,
                startRadius: 24,
                endRadius: 820
            )

            RadialGradient(
                colors: [
                    CosmicTheme.Colors.accentGlow.opacity(config.glowOpacity),
                    .clear
                ],
                center: .top,
                startRadius: 16,
                endRadius: 360
            )
            .blur(radius: CosmicTheme.Constants.Blur.glow)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(startDate)
                    let elapsedSeconds = CGFloat(elapsed)
                    for star in stars {
                        let x = wrapped(star.x + (star.driftX * config.driftMultiplier * elapsedSeconds))
                        let y = wrapped(star.y + (star.driftY * config.driftMultiplier * elapsedSeconds))
                        let rect = CGRect(
                            x: x * size.width,
                            y: y * size.height,
                            width: star.size,
                            height: star.size
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(CosmicTheme.Colors.moonSilver.opacity(star.opacity * config.starOpacityMultiplier))
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .ignoresSafeArea()
        .onAppear {
            // Keep animation time origin stable for deterministic drift while visible.
            startDate = Date()
        }
    }

    private var config: VariantConfig {
        switch variant {
        case .chat:
            return VariantConfig(glowOpacity: 0.16, starOpacityMultiplier: 1.00, driftMultiplier: 1.00)
        case .profile:
            return VariantConfig(glowOpacity: 0.12, starOpacityMultiplier: 0.90, driftMultiplier: 0.85)
        case .focus:
            return VariantConfig(glowOpacity: 0.20, starOpacityMultiplier: 1.12, driftMultiplier: 1.10)
        }
    }

    private static func seed(for variant: Variant) -> UInt64 {
        switch variant {
        case .chat: return 0xA57A_2026
        case .profile: return 0xB0B0_2026
        case .focus: return 0xF0C0_2026
        }
    }

    private func wrapped(_ value: CGFloat) -> CGFloat {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder >= 0 ? remainder : remainder + 1
    }

    private static func makeStars(seed: UInt64, count: Int) -> [Star] {
        var generator = SeededGenerator(seed: seed)
        return (0..<count).map { _ in
            let size = CGFloat.random(in: 1.0...2.0, using: &generator)
            return Star(
                x: CGFloat.random(in: 0...1, using: &generator),
                y: CGFloat.random(in: 0...1, using: &generator),
                size: size,
                opacity: Double.random(in: 0.06...0.18, using: &generator),
                driftX: CGFloat.random(in: -0.003...0.003, using: &generator),
                driftY: CGFloat.random(in: -0.002...0.002, using: &generator)
            )
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
