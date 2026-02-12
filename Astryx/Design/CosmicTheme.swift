//
//  CosmicTheme.swift
//  Astryx
//
//  Created by Codex on 2/12/26.
//

import SwiftUI

enum CosmicTheme {
    enum Colors {
        static let backgroundStart = Color(red: 0.05, green: 0.06, blue: 0.16)
        static let backgroundEnd = Color(red: 0.12, green: 0.09, blue: 0.24)
        static let accentGlow = Color(red: 0.46, green: 0.63, blue: 1.00)
        static let moonSilver = Color(red: 0.82, green: 0.86, blue: 0.94)
        static let goldHighlight = Color(red: 0.95, green: 0.79, blue: 0.39)
        static let userBubble = Color(red: 0.26, green: 0.31, blue: 0.55).opacity(0.42)
        static let assistantBubble = Color(red: 0.72, green: 0.76, blue: 0.89).opacity(0.20)
    }

    enum Typography {
        static let title: Font = .system(size: 30, weight: .bold, design: .rounded)
        static let subtitle: Font = .system(size: 17, weight: .semibold, design: .rounded)
        static let body: Font = .system(size: 16, weight: .regular, design: .default)
        static let smallCaps: Font = .system(size: 12, weight: .semibold, design: .rounded).smallCaps()
    }

    enum Constants {
        enum CornerRadius {
            static let card: CGFloat = 20
            static let bubble: CGFloat = 16
            static let button: CGFloat = 14
        }

        enum Blur {
            // Keep blur values modest to preserve smooth scrolling on older devices.
            static let background: CGFloat = 24
            static let glow: CGFloat = 12
        }

        enum Shadow {
            static let color = Colors.moonSilver.opacity(0.20)
            static let radius: CGFloat = 12
            static let x: CGFloat = 0
            static let y: CGFloat = 4
        }

        enum Glow {
            static let color = Colors.accentGlow.opacity(0.55)
            static let radius: CGFloat = 20
            static let x: CGFloat = 0
            static let y: CGFloat = 0
        }
    }
}
