import SwiftUI

struct ContentView: View {
    @State private var viewModel = ItemViewModel()
    @State private var editingItemId: String?
    @State private var editingName: String = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "アイテムがありません",
                        systemImage: "cart",
                        description: Text("買い物リストにアイテムを追加しましょう")
                    )
                } else {
                    listView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("AppIconImage")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("Shoplist")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    addItemBar
                }
            }
            .overlay(alignment: .top) {
                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.red, in: Capsule())
                        .padding(.top, 8)
                        .onTapGesture { viewModel.error = nil }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.default, value: viewModel.error)
        }
        .task {
            await viewModel.loadItems()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task { await viewModel.loadItems() }
            }
        }
    }

    // MARK: - List

    private var listView: some View {
        List {
            if !viewModel.unpurchasedItems.isEmpty {
                Section {
                    ForEach(viewModel.unpurchasedItems) { item in
                        itemRow(item)
                    }
                    .onMove { source, destination in
                        viewModel.moveItem(from: source, to: destination)
                    }
                }
            }

            if !viewModel.purchasedItems.isEmpty {
                Section("購入済み") {
                    ForEach(viewModel.purchasedItems) { item in
                        itemRow(item)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Item Row

    private func itemRow(_ item: Item) -> some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: item.purchased ? .light : .medium).impactOccurred()
                Task { await viewModel.togglePurchased(item) }
            } label: {
                Image(systemName: item.purchased ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.purchased ? .green : .secondary)
            }
            .buttonStyle(.plain)

            if editingItemId == item.id {
                TextField("", text: $editingName)
                    .font(.body)
                    .submitLabel(.done)
                    .onSubmit {
                        let name = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty && name != item.name {
                            Task { await viewModel.updateName(id: item.id, name: name) }
                        }
                        editingItemId = nil
                    }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .strikethrough(item.purchased)
                        .foregroundStyle(item.purchased ? .secondary : .primary)
                    if item.purchased, let purchasedAt = item.purchasedAt {
                        Text(formatPurchasedAt(purchasedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !item.purchased else { return }
                    editingItemId = item.id
                    editingName = item.name
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await viewModel.deleteItem(item) }
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                UIImpactFeedbackGenerator(style: item.purchased ? .light : .medium).impactOccurred()
                Task { await viewModel.togglePurchased(item) }
            } label: {
                Label(
                    item.purchased ? "未購入に戻す" : "購入済み",
                    systemImage: item.purchased ? "arrow.uturn.backward" : "checkmark.circle.fill"
                )
            }
            .tint(.green)
        }
    }

    // MARK: - Add Item

    private var addItemBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .onTapGesture { isInputFocused = true }

            TextField("アイテムを追加", text: $viewModel.newItemName)
                .font(.body)
                .focused($isInputFocused)
                .submitLabel(.done)
                .onSubmit {
                    let name = viewModel.newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if name.isEmpty {
                        isInputFocused = false
                    } else {
                        Task {
                            await viewModel.addItem()
                            isInputFocused = true
                        }
                    }
                }
        }
    }

    // MARK: - Helpers

    private func formatPurchasedAt(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else { return "" }
        let relative = RelativeDateTimeFormatter()
        relative.locale = Locale(identifier: "ja_JP")
        return relative.localizedString(for: date, relativeTo: .now)
    }
}
