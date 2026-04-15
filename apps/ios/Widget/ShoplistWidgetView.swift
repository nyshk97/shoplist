import SwiftUI
import WidgetKit

struct ShoplistWidgetView: View {
    let entry: ShoplistEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.bottom, 8)

            if let error = entry.errorMessage {
                Spacer()
                HStack {
                    Spacer()
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                Spacer()
            } else if entry.items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("買うものなし")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.items) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text(item.name)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, -4)
    }

    private var headerView: some View {
        HStack {
            Label("買い物リスト", systemImage: "cart")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            Text("\(entry.items.count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
