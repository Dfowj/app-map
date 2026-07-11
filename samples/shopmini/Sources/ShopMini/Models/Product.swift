import Foundation

struct Product: Identifiable, Hashable {
    let id: String
    let name: String
    let price: Decimal
    let blurb: String
}
