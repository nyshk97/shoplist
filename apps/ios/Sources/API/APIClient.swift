import Foundation

actor APIClient {
    static let shared = APIClient()

    private let baseURL = "https://shoplist-api.d0ne1s-todo.workers.dev"
    private let secret = Secrets.apiSecret

    private let decoder = JSONDecoder()

    private func request(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> Data {
        let url = URL(string: "\(baseURL)\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")

        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let http = response as? HTTPURLResponse
            throw APIError.httpError(statusCode: http?.statusCode ?? 0)
        }
        return data
    }

    func fetchItems() async throws -> ItemsResponse {
        let data = try await request("/items")
        return try decoder.decode(ItemsResponse.self, from: data)
    }

    func createItem(name: String) async throws -> Item {
        let data = try await request("/items", method: "POST", body: ["name": name])
        return try decoder.decode(Item.self, from: data)
    }

    func updateItem(id: String, name: String? = nil, purchased: Bool? = nil) async throws -> Item {
        var body: [String: AnyCodable] = [:]
        if let name { body["name"] = AnyCodable(name) }
        if let purchased { body["purchased"] = AnyCodable(purchased) }
        let data = try await request("/items/\(id)", method: "PATCH", body: body)
        return try decoder.decode(Item.self, from: data)
    }

    func deleteItem(id: String) async throws {
        _ = try await request("/items/\(id)", method: "DELETE")
    }

    func reorderItems(items: [(id: String, position: Int)]) async throws {
        let body = ReorderBody(items: items.map { ReorderEntry(id: $0.id, position: $0.position) })
        _ = try await request("/items", method: "PATCH", body: body)
    }
}

enum APIError: LocalizedError {
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .httpError(let code):
            return "HTTP Error: \(code)"
        }
    }
}

// MARK: - Helpers

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let v = value as? Bool { try container.encode(v) }
        else if let v = value as? String { try container.encode(v) }
        else if let v = value as? Int { try container.encode(v) }
        else if let v = value as? Double { try container.encode(v) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else { value = "" }
    }
}

struct ReorderBody: Codable {
    let items: [ReorderEntry]
}

struct ReorderEntry: Codable {
    let id: String
    let position: Int
}
