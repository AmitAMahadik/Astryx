//
//  FocusView.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//

import SwiftUI
import UIKit

struct FocusView: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var vm: FocusSummaryViewModel = .init()
    @Namespace private var cardNamespace
    @State private var expandedArea: FocusArea? = nil
    @State private var isExpandedFlipped: Bool = false

    private var gridColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var gridAreas: [FocusArea] {
        FocusArea.allCases.filter { $0 != .purpose }
    }

    @ViewBuilder
    private func focusCardCell(_ area: FocusArea) -> some View {
        VStack(spacing: 6) {
            ZStack {
                FocusCardView(
                    area: area,
                    isSelected: state.focusArea == area,
                    isFlipped: false,
                    backText: vm.backText(for: area),
                    isExpanded: false
                )
                .matchedGeometryEffect(
                    id: area.rawValue,
                    in: cardNamespace,
                    isSource: expandedArea != area
                )
                .opacity(expandedArea == area ? 0 : 1)
            }

            Text(area.rawValue)
                .font(CosmicTheme.Typography.smallCaps)
                .tracking(1.1)
                .foregroundStyle(CosmicTheme.Colors.moonSilver.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityHidden(true)
        }
        .onTapGesture {
            lightHaptic()
            if expandedArea == area {
                collapseExpanded()
            } else {
                withAnimation(.interactiveSpring(response: 0.55, dampingFraction: 0.92, blendDuration: 0.15)) {
                    expand(area)
                }
            }
        }
    }

    private var purposeTopCard: some View {
        HStack {
            Spacer()
            focusCardCell(.purpose)
                .frame(maxWidth: 220) // keep visual balance above grid
            Spacer()
        }
        .padding(.top, -60)
        .padding(.bottom, 10)
    }

    private var focusGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(gridAreas) { area in
                focusCardCell(area)
            }
        }
        .padding(.top, 0)
        .padding(.horizontal, 16)
    }

    var body: some View {
        ZStack {
            CosmicBackgroundView(variant: .focus)

            VStack(alignment: .leading, spacing: 0) {
                purposeTopCard
                focusGrid
            }
            .padding(.top, -12)

            if let expanded = expandedArea {
                Color.black
                    .opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        lightHaptic()
                        collapseExpanded()
                    }

                GeometryReader { geo in
                    FocusCardView(
                        area: expanded,
                        isSelected: true,
                        isFlipped: isExpandedFlipped,
                        backText: vm.backText(for: expanded),
                        isExpanded: true
                    )
                    .matchedGeometryEffect(
                        id: expanded.rawValue,
                        in: cardNamespace,
                        isSource: true
                    )
                    .frame(
                        width: geo.size.width - 36,
                        height: geo.size.height * 0.70
                    )
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .zIndex(10)
                    .onTapGesture {
                        lightHaptic()
                        collapseExpanded()
                    }
                }
                .ignoresSafeArea()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Cosmic UI is designed for a dark backdrop; enforce for readability in system Light Mode.
        .preferredColorScheme(.dark)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                CosmicHeaderView(showsDivider: false)
            }
        }
        .task(id: state.focusArea) {
            // If the selection was cleared, collapse the expanded card and stop.
            guard let area = state.focusArea else {
                await MainActor.run { collapseExpanded() }
                return
            }

            // Prefer the cached deterministic lunar sign, but compute it on-demand if needed.
            var lunar = await MainActor.run { state.lunarSignDeterministic }
            if lunar == "—" {
                if let computed = try? await state.computeDeterministicMoonInfo() {
                    lunar = computed.sign
                }
            }

            // Build a lightweight profile context for the model.
            let dob = await MainActor.run { state.dob.formatted(date: .abbreviated, time: .omitted) }
            let tob = await MainActor.run { String(format: "%02d:%02d:%02d", state.tobHour, state.tobMinute, state.tobSecond) }
            let tz = await MainActor.run { state.birthTimeZoneIdentifier ?? "" }

            let name = await MainActor.run { state.name }
            let gender = await MainActor.run { state.gender.rawValue }
            let pob = await MainActor.run { state.placeOfBirth }
            let solar = await MainActor.run { state.solarSign }
            let chinese = await MainActor.run { state.chineseSign }

            let profileText = """
            Name: \(name)
            Gender: \(gender)
            DOB: \(dob)
            TOB: \(tob)
            Place: \(pob)
            Timezone: \(tz)
            """

            let context = FocusSummaryContext(
                date: Date(),
                timezoneIdentifier: TimeZone.current.identifier,
                lunarSign: lunar,
                solarSign: solar,
                chineseSign: chinese,
                profile: profileText
            )

            await vm.streamSummary(for: area, context: context)
        }
    }

    private func expand(_ area: FocusArea) {
        state.focusArea = area
        expandedArea = area
        isExpandedFlipped = false

        Task { @MainActor in
            // Small delay so the matched-geometry expansion reads as a tap before the flip.
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.easeInOut(duration: 0.28)) {
                isExpandedFlipped = true
            }
        }
    }

    private func collapseExpanded() {
        // Flip back first, then collapse.
        withAnimation(.easeInOut(duration: 0.22)) {
            isExpandedFlipped = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.interactiveSpring(response: 0.55, dampingFraction: 0.92, blendDuration: 0.15)) {
                expandedArea = nil
            }
        }
    }
    
    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}

#Preview("FocusView – Empty") {
    NavigationStack {
        FocusView()
            .environmentObject(AppState())
    }
}

#Preview("FocusView – With Selection") {
    let state = AppState()
    state.focusArea = .health
    return NavigationStack {
        FocusView()
            .environmentObject(state)
    }
}
