import SwiftUI
import WidgetKit

struct ShoplistWidgetView: View {
    let entry: ShoplistEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.bottom, 10)

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
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("買うものなし")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(entry.items) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .strokeBorder(.tertiary, lineWidth: 1.5)
                                .frame(width: 16, height: 16)
                            Text(item.name)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 8) {
            Image("AppIconImage")
                .resizable()
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Text("Shoplist")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            if !entry.items.isEmpty {
                Text("\(entry.items.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}
