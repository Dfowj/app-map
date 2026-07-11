import Foundation

struct Order: Identifiable, Hashable {
    let id: String
    let total: Decimal
    let placedAt: Date
}
