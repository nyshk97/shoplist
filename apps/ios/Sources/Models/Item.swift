import Foundation

struct Item: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var purchased: Bool
    var position: Int
    let purchasedAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, purchased, position
        case purchasedAt = "purchased_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ItemsResponse: Codable {
    let items: [Item]
}
