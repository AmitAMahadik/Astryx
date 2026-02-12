//
//  CosmicTabBarView.swift
//  Astryx
//
//  Created by Codex on 2/12/26.
//

import SwiftUI

struct CosmicTabBarView: View {
    @Binding var selection: AppTab

    private struct TabItem: Identifiable {
        let id: AppTab
        let title: String
        let systemImage: String
    }

    private let items: [TabItem] = [
        TabItem(id: .profile, title: "Profile", systemImage: "person.crop.circle"),
        TabItem(id: .focus, title: "Focus", systemImage: "sparkles"),
        TabItem(id: .chat, title: "Chat", systemImage: "bubble.left.and.bubble.right")
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(glassCapsule)
        .clipShape(Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(CosmicTheme.Colors.accentGlow.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: CosmicTheme.Constants.Glow.color.opacity(0.18), radius: 18, x: 0, y: 10)
        .padding(.horizontal, 18)
        .accessibilityElement(children: .contain)
    }

    private var glassCapsule: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(.thinMaterial)

            Capsule(style: .continuous)
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
                .opacity(0.75)
        }
    }

    private func tabButton(_ item: TabItem) -> some View {
        let isSelected = selection == item.id
        return Button {
            selection = item.id
        } label: {
            VStack(spacing: 6) {
                Image(systemName: item.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                        ? CosmicTheme.Colors.moonSilver.opacity(0.95)
                        : CosmicTheme.Colors.moonSilver.opacity(0.55)
                    )
                    .shadow(
                        color: isSelected ? CosmicTheme.Constants.Glow.color.opacity(0.35) : .clear,
                        radius: isSelected ? 10 : 0,
                        x: 0,
                        y: 0
                    )

                selectionIndicator(isSelected: isSelected)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func selectionIndicator(isSelected: Bool) -> some View {
        if isSelected {
            // Minimal underline/arc indicator.
            Capsule(style: .continuous)
                .fill(CosmicTheme.Colors.goldHighlight.opacity(0.75))
                .frame(width: 18, height: 2)
                .shadow(color: CosmicTheme.Colors.goldHighlight.opacity(0.25), radius: 6, x: 0, y: 0)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else {
            Color.clear.frame(width: 18, height: 2)
        }
    }
}

