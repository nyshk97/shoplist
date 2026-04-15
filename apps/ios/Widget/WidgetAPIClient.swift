import Foundation

struct WidgetItemResponse: Codable {
    let id: String
    let name: String
    let purchased: Bool
}

struct WidgetItemsResponse: Codable {
    let items: [WidgetItemResponse]
}

actor WidgetAPIClient {
    static let shared = WidgetAPIClient()

    private let baseURL = "https://shoplist-api.d0ne1s-todo.workers.dev"
    private let secret = Secrets.apiSecret

    func fetchItems() async throws -> WidgetItemsResponse {
        var req = URLRequest(url: URL(string: "\(baseURL)/items")!)
        req.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(WidgetItemsResponse.self, from: data)
    }
}
