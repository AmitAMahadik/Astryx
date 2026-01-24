//
//  ContentViewModel.swift
//  Astryx
//
//  Created by Mahadik, Amit on 1/24/26.
//


//
//  ContentViewModel.swift
//  Astryx
//
//  Created by Mahadik, Amit on 1/23/26.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class ContentViewModel: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published var errorMessage: String?

    func loadItems(using context: ModelContext) {
        do {
            // Keep ordering stable/predictable for UI.
            let descriptor = FetchDescriptor<Item>(
                sortBy: [SortDescriptor(\Item.timestamp, order: .reverse)]
            )
            items = try context.fetch(descriptor)
            errorMessage = nil
        } catch {
            items = []
            errorMessage = "Failed to load items: \(error.localizedDescription)"
        }
    }

    func addItem(using context: ModelContext) {
        let newItem = Item(timestamp: Date())
        context.insert(newItem)
        loadItems(using: context)
    }

    func deleteItems(using context: ModelContext, offsets: IndexSet) {
        for index in offsets {
            guard items.indices.contains(index) else { continue }
            context.delete(items[index])
        }
        loadItems(using: context)
    }
}
