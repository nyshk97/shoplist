import SwiftUI
import WidgetKit

struct ShoplistEntry: TimelineEntry {
    let date: Date
    let items: [WidgetItem]
    let errorMessage: String?
}

struct WidgetItem: Identifiable {
    let id: String
    let name: String
}

struct ShoplistProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShoplistEntry {
        ShoplistEntry(
            date: .now,
            items: [WidgetItem(id: "1", name: "アイテムを追加しよう")],
            errorMessage: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ShoplistEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            let entry = await fetchEntry(family: context.family)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShoplistEntry>) -> Void) {
        Task {
            let entry = await fetchEntry(family: context.family)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchEntry(family: WidgetFamily) async -> ShoplistEntry {
        let maxItems = family == .systemSmall ? 5 : 10
        do {
            let response = try await WidgetAPIClient.shared.fetchItems()
            let items = response.items
                .filter { !$0.purchased }
                .prefix(maxItems)
                .map { WidgetItem(id: $0.id, name: $0.name) }
            return ShoplistEntry(date: .now, items: Array(items), errorMessage: nil)
        } catch {
            return ShoplistEntry(date: .now, items: [], errorMessage: error.localizedDescription)
        }
    }
}

struct ShoplistWidget: Widget {
    let kind = "ShoplistWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShoplistProvider()) { entry in
            ShoplistWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("買い物リスト")
        .description("未購入アイテムを表示します")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
