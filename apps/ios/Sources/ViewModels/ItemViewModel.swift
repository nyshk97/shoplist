import Foundation
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class ItemViewModel {
    var items: [Item] = []
    var isLoading: Bool = false
    var error: String?
    var newItemName: String = ""

    private let api = APIClient.shared

    var unpurchasedItems: [Item] {
        items.filter { !$0.purchased }
    }

    var purchasedItems: [Item] {
        items.filter { $0.purchased }
    }

    func loadItems() async {
        isLoading = true
        error = nil
        do {
            let response = try await api.fetchItems()
            items = response.items
            reloadWidget()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func addItem() async {
        let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        newItemName = ""
        do {
            let item = try await api.createItem(name: name)
            items.append(item)
            reloadWidget()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func togglePurchased(_ item: Item) async {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        let original = items[i]
        items[i].purchased = !item.purchased
        do {
            let updated = try await api.updateItem(id: item.id, purchased: !item.purchased)
            if let j = items.firstIndex(where: { $0.id == item.id }) {
                items[j] = updated
            }
            reloadWidget()
        } catch {
            if let j = items.firstIndex(where: { $0.id == item.id }) {
                items[j] = original
            }
            self.error = error.localizedDescription
        }
    }

    func updateName(id: String, name: String) async {
        do {
            let updated = try await api.updateItem(id: id, name: name)
            if let i = items.firstIndex(where: { $0.id == id }) {
                items[i] = updated
            }
            reloadWidget()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteItem(_ item: Item) async {
        do {
            try await api.deleteItem(id: item.id)
            items.removeAll { $0.id == item.id }
            reloadWidget()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        var unpurchased = unpurchasedItems
        unpurchased.move(fromOffsets: source, toOffset: destination)
        items = unpurchased + purchasedItems
        syncReorder()
    }

    func syncReorder() {
        let unpurchased = unpurchasedItems
        Task {
            let reorderItems = unpurchased.enumerated().map { (i, item) in
                (id: item.id, position: i)
            }
            do {
                try await api.reorderItems(items: reorderItems)
                reloadWidget()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
