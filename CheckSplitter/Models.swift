import Foundation

struct Person: Identifiable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct BillItem: Identifiable, Hashable {
    let id: UUID
    var name: String
    var price: Decimal
    var assignedPersonIDs: Set<Person.ID>

    init(id: UUID = UUID(), name: String, price: Decimal, assignedPersonIDs: Set<Person.ID> = []) {
        self.id = id
        self.name = name
        self.price = price
        self.assignedPersonIDs = assignedPersonIDs
    }
}

struct PersonTotal: Identifiable {
    let person: Person
    let subtotal: Decimal
    let taxShare: Decimal
    let tipShare: Decimal
    let total: Decimal

    var id: Person.ID { person.id }
}

enum Money {
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func string(_ value: Decimal) -> String {
        formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
