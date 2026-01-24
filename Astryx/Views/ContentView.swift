//
//  ContentView.swift
//  Astryx
//
//  Created by Mahadik, Amit on 1/23/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(viewModel.items) { item in
                    NavigationLink {
                        Text(
                            "Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))"
                        )
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete { offsets in
                    withAnimation {
                        viewModel.deleteItems(using: modelContext, offsets: offsets)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button {
                        withAnimation {
                            viewModel.addItem(using: modelContext)
                        }
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .overlay {
                if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Something went wrong",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                }
            }
            .task {
                // `.task` runs on appearance and is cancelable; ideal for initial load.
                viewModel.loadItems(using: modelContext)
            }
        } detail: {
            Text("Select an item")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
