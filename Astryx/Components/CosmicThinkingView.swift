//
//  CosmicThinkingView.swift
//  Astryx
//
//  Created by Codex on 2/12/26.
//

import SwiftUI

struct CosmicThinkingView: View {
    @State private var orbitPhase: CGFloat = 0
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            Text("✨ Calculating planetary alignments…")
                .font(.footnote)
                .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.80))
                .fixedSize(horizontal: false, vertical: true)

            orbitalAnimation
        }
        .opacity(pulse ? 1.0 : 0.72)
        .onAppear {
            pulse = false
            orbitPhase = 0

            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                pulse = true
            }

            // Simple, lightweight orbit: rotate a dot around a thin ring.
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                orbitPhase = 1
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calculating planetary alignments")
    }

    private var orbitalAnimation: some View {
        ZStack {
            Circle()
                .stroke(CosmicTheme.Colors.accentGlow.opacity(0.20), lineWidth: 1)
                .frame(width: 30, height: 30)
                .blur(radius: 0.4)

            Circle()
                .fill(CosmicTheme.Colors.accentGlow.opacity(0.85))
                .frame(width: 4, height: 4)
                .offset(x: 15, y: 0)
                .rotationEffect(.degrees(Double(orbitPhase) * 360))
                .shadow(color: CosmicTheme.Colors.accentGlow.opacity(0.35), radius: 6, x: 0, y: 0)
        }
        .frame(height: 30)
        .accessibilityHidden(true)
    }
}

