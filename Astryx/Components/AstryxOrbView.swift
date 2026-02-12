//
//  AstryxOrbView.swift
//  Astryx
//
//  Created by Codex on 2/12/26.
//

import SwiftUI

struct AstryxOrbView: View {
    let isAnimating: Bool

    /// Visual size of the orb itself (not counting glow).
    var orbSize: CGFloat = 18

    @State private var glowPulse: Bool = false
    @State private var ringPhase: CGFloat = 0

    var body: some View {
        ZStack {
            if isAnimating {
                orbitRing
            }

            orb
        }
        .frame(width: orbSize * 2.0, height: orbSize * 2.0)
        .onAppear {
            // Lightweight, deterministic animations.
            glowPulse = false
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            updateRingAnimation()
        }
        .onChange(of: isAnimating) { _, _ in
            updateRingAnimation()
        }
        .accessibilityHidden(true)
    }

    private var orb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.78, green: 0.60, blue: 1.00), // soft purple
                        Color(red: 0.36, green: 0.47, blue: 0.98), // indigo
                        CosmicTheme.Colors.backgroundEnd
                    ],
                    center: .topLeading,
                    startRadius: 1,
                    endRadius: orbSize
                )
            )
            .frame(width: orbSize, height: orbSize)
            .overlay {
                Circle()
                    .stroke(CosmicTheme.Colors.moonSilver.opacity(0.20), lineWidth: 0.5)
            }
            .shadow(
                color: CosmicTheme.Colors.accentGlow.opacity(glowPulse ? 0.40 : 0.22),
                radius: glowPulse ? 10 : 6,
                x: 0,
                y: 0
            )
            .shadow(
                color: Color.purple.opacity(glowPulse ? 0.22 : 0.14),
                radius: glowPulse ? 14 : 10,
                x: 0,
                y: 0
            )
    }

    private var orbitRing: some View {
        Circle()
            .stroke(
                CosmicTheme.Colors.accentGlow.opacity(0.28),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 4])
            )
            .frame(width: orbSize * 1.8, height: orbSize * 1.8)
            .rotationEffect(.degrees(Double(ringPhase) * 360))
    }

    private func updateRingAnimation() {
        if isAnimating {
            ringPhase = 0
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                ringPhase = 1
            }
        } else {
            ringPhase = 0
        }
    }
}

