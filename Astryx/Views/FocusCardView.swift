//
//  FocusCard.swift
//  AstryX
//
//  Created by Assistant on 12/23/25.
//

import SwiftUI
import Combine

struct FocusCardView: View {
    let area: FocusArea
    let isSelected: Bool
    let isFlipped: Bool
    let backText: String
    let isExpanded: Bool

    @State private var ellipsisPhase: Int = 0
    private let ellipsisTimer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    init(
        area: FocusArea,
        isSelected: Bool,
        isFlipped: Bool = false,
        backText: String = "—",
        isExpanded: Bool = false
    ) {
        self.area = area
        self.isSelected = isSelected
        self.isFlipped = isFlipped
        self.backText = backText
        self.isExpanded = isExpanded
    }

    private var animatedEllipsis: String {
        guard ellipsisPhase > 0 else { return "" }
        return " " + String(repeating: "·", count: ellipsisPhase) // " ·", " ··", " ···"
    }

    private var isWaitingPlaceholder: Bool {
        let normalized = backText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: ".", with: "")
            .lowercased()
        return normalized.hasPrefix("reaching for the stars")
    }


    private var visibleBackText: String {
        if isWaitingPlaceholder {
            return "Reaching for the stars" + animatedEllipsis
        }
        return backText
    }

    // MARK: - Streaming Text Formatting

    private enum FocusSection: String {
        case theme = "THEME"
        case haiku = "HAIKU"
        case `do` = "DO"
        case avoid = "AVOID"
    }

    private struct ParsedFocusSummary {
        var theme: String = ""
        var haikuLines: [String] = []
        var doLine: String = ""
        var avoidLine: String = ""

        var hasAnyContent: Bool {
            !theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !haikuLines.joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !doLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !avoidLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Parses streamed text in the format:
    /// THEME: ...
    /// HAIKU: line1
    /// line2
    /// line3
    /// DO: ...
    /// AVOID: ...
    ///
    /// Works even when the text is partial (streaming).
    private func parseSummary(_ text: String) -> ParsedFocusSummary {
        let normalized = text
            .replacingOccurrences(of: "\r", with: "")

        let lines = normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }

        var parsed = ParsedFocusSummary()
        var current: FocusSection? = nil

        func assign(_ section: FocusSection, content: String) {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            switch section {
            case .theme:
                parsed.theme = parsed.theme.isEmpty ? trimmed : (parsed.theme + " " + trimmed)
            case .haiku:
                parsed.haikuLines.append(trimmed)
            case .do:
                parsed.doLine = parsed.doLine.isEmpty ? trimmed : (parsed.doLine + " " + trimmed)
            case .avoid:
                parsed.avoidLine = parsed.avoidLine.isEmpty ? trimmed : (parsed.avoidLine + " " + trimmed)
            }
        }

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }

            if let range = trimmedLine.range(of: ":") {
                let head = String(trimmedLine[..<range.lowerBound]).uppercased()
                let tail = String(trimmedLine[range.upperBound...]).trimmingCharacters(in: .whitespaces)

                if head == FocusSection.theme.rawValue {
                    current = .theme
                    if !tail.isEmpty { assign(.theme, content: tail) }
                    continue
                }
                if head == FocusSection.haiku.rawValue {
                    current = .haiku
                    if !tail.isEmpty { assign(.haiku, content: tail) }
                    continue
                }
                if head == FocusSection.do.rawValue {
                    current = .do
                    if !tail.isEmpty { assign(.do, content: tail) }
                    continue
                }
                if head == FocusSection.avoid.rawValue {
                    current = .avoid
                    if !tail.isEmpty { assign(.avoid, content: tail) }
                    continue
                }
            }

            if let current {
                assign(current, content: trimmedLine)
            }
        }

        if parsed.haikuLines.count == 1, parsed.haikuLines[0].contains(",") {
            let parts = parsed.haikuLines[0]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 3 {
                parsed.haikuLines = Array(parts.prefix(3))
            }
        }

        if parsed.haikuLines.count > 3 {
            parsed.haikuLines = Array(parsed.haikuLines.prefix(3))
        }

        return parsed
    }

    @ViewBuilder
    private func formattedSummaryView(_ text: String, isCompact: Bool) -> some View {
        let responseFont: Font = isCompact
        ? .system(.caption2, design: .monospaced)
        : .system(.callout, design: .monospaced)

        if isWaitingPlaceholder {
            Text("Reaching for the stars" + animatedEllipsis)
                .font(responseFont)
                .foregroundStyle(.secondary)
                .lineSpacing(isCompact ? 2 : 6)
        } else {
            let parsed = parseSummary(text)

            if !parsed.hasAnyContent {
                Text(text)
                    .font(responseFont)
                    .foregroundStyle(.primary)
                    .lineSpacing(isCompact ? 2 : 6)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: isCompact ? 6 : 12) {
                    if !parsed.theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("THEME")
                                .font(isCompact ? .caption.bold() : .headline)
                                .foregroundStyle(.secondary)
                            Text(parsed.theme)
                                .font(responseFont)
                                .foregroundStyle(.primary)
                        }
                    }

                    if parsed.haikuLines.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HAIKU")
                                .font(isCompact ? .caption.bold() : .headline)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(parsed.haikuLines.indices, id: \.self) { idx in
                                    Text(parsed.haikuLines[idx])
                                        .font(responseFont)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }

                    if !parsed.doLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DO")
                                .font(isCompact ? .caption.bold() : .headline)
                                .foregroundStyle(.secondary)
                            Text(parsed.doLine)
                                .font(responseFont)
                                .foregroundStyle(.primary)
                        }
                    }

                    if !parsed.avoidLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AVOID")
                                .font(isCompact ? .caption.bold() : .headline)
                                .foregroundStyle(.secondary)
                            Text(parsed.avoidLine)
                                .font(responseFont)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .lineSpacing(isCompact ? 2 : 6)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var iconName: String {
        switch area {
        case .purpose: return "focus_purpose"
        case .career: return "focus_career"
        case .relationships: return "focus_relationships"
        case .wealth: return "focus_finances"
        case .health: return "focus_health"
        case .travel: return "focus_travel"
        case .education: return "focus_education"
        }
    }
    private struct CardChrome: ViewModifier {
        let isSelected: Bool

        func body(content: Content) -> some View {
            let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

            return content
                .background(
                    ZStack {
                        // Base: deep, slightly translucent card surface
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.40),
                                Color.black.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(shape)

                        // Soft “glass” sheen
                        shape
                            .fill(.ultraThinMaterial)
                            .opacity(0.18)
                    }
                )
                .clipShape(shape)
                // Subtle border for all cards
                .overlay(
                    shape.stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                // Selected: sleek glow ring + slight lift (no chunky stroke)
                .overlay(
                    Group {
                        if isSelected {
                            shape
                                .stroke(Color.accentColor.opacity(0.95), lineWidth: 2)
                                .shadow(color: Color.accentColor.opacity(0.55), radius: 14, x: 0, y: 0)
                                .shadow(color: Color.accentColor.opacity(0.35), radius: 28, x: 0, y: 0)
                                .transition(.opacity)
                        }
                    }
                )
                // Halo-only selection: no scale, just a gentle lift via shadow
                .shadow(
                    color: Color.black.opacity(isSelected ? 0.70 : 0.55),
                    radius: isSelected ? 22 : 18,
                    x: 0,
                    y: isSelected ? 14 : 10
                )
                .shadow(
                    color: Color.black.opacity(isSelected ? 0.42 : 0.35),
                    radius: isSelected ? 8 : 6,
                    x: 0,
                    y: isSelected ? 4 : 3
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isSelected)
        }
    }
    var body: some View {
        ZStack {
            frontFace
                .opacity(isFlipped ? 0.0 : 1.0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )

            backFace
                .opacity(isFlipped ? 1.0 : 0.0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: isFlipped)
        .onReceive(ellipsisTimer) { _ in
            guard isFlipped, isWaitingPlaceholder else {
                ellipsisPhase = 0
                return
            }
            ellipsisPhase = (ellipsisPhase % 3) + 1 // cycles 1,2,3 -> "·", "··", "···"
        }
        .onDisappear { }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityLabel(Text(area.rawValue))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var frontFace: some View {
        Group {
            if isExpanded {
                VStack(spacing: 16) {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)

                    Text(area.rawValue)
                        .font(.title2).bold()
                        .foregroundStyle(.primary)

                    Text("Tap to reveal your haiku")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .padding(12)
            }
        }
        .modifier(CardChrome(isSelected: isSelected))
    }

    private var backFace: some View {
        Group {
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .accessibilityHidden(true)
                            .padding(.top, 8)
                            .opacity(isFlipped ? 1.0 : 0.0)
                            .shadow(color: Color.accentColor.opacity(0.35), radius: 12, x: 0, y: 0)
                            .animation(
                                .easeOut(duration: 0.35).delay(0.15),
                                value: isFlipped
                            )

                        Spacer()
                    }
                    .padding(.top, 8)

                    formattedSummaryView(visibleBackText, isCompact: false)
                        .animation(.easeInOut(duration: 0.20), value: ellipsisPhase)

                    Spacer(minLength: 0)

                    Text("Tap again to close")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(area.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    formattedSummaryView(visibleBackText, isCompact: true)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .minimumScaleFactor(0.85)
                        .animation(.easeInOut(duration: 0.20), value: ellipsisPhase)

                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(width: 96, height: 96)
            }
        }
        .modifier(CardChrome(isSelected: isSelected))
    }
}

#Preview("FocusCardView – Compact") {
    VStack {
        FocusCardView(area: .health, isSelected: true, isFlipped: false, backText: "—", isExpanded: false)
        FocusCardView(area: .travel, isSelected: false, isFlipped: true, backText: "A short haiku appears here.", isExpanded: false)
    }
    .padding()
}

#Preview("FocusCardView – Expanded Back") {
    FocusCardView(area: .career, isSelected: true, isFlipped: true, backText: "Overall theme\n\nHaiku line 1\nHaiku line 2\nHaiku line 3\n\nDo: ...\nAvoid: ...", isExpanded: true)
        .padding()
}
