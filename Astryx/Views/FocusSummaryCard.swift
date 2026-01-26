//
//  FocusSummaryCard.swift
//  Astryx
//
//  Created by Mahadik, Amit on 1/25/26.
//
import SwiftUI

private struct FocusSummaryCard: View {
    let selected: FocusArea?
    let summary: String?
    let isLoading: Bool
    let errorText: String?

    private var title: String {
        selected?.rawValue ?? "Select a focus area"
    }

    private var defaultSubtitle: String {
        "Pick one of the focus areas above to tailor your weekly predictions."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(title)
                    .font(.headline)

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else if let summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(defaultSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
