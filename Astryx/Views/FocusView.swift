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
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var focusGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(gridAreas) { area in
                focusCardCell(area)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                purposeTopCard
                focusGrid
            }

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
        .onChange(of: state.focusArea) { _, newValue in
            if newValue == nil {
                collapseExpanded()
                return
            }

            guard let area = newValue else { return }

            let context = FocusSummaryContext(
                date: Date(),
                timezoneIdentifier: TimeZone.current.identifier
            )

            Task { @MainActor in
                await vm.streamSummary(for: area, context: context)
            }
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
