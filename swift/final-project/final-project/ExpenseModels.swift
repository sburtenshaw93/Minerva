import Foundation

struct Category: Identifiable, Hashable {
    let id: Int
    let name: String
    let monthlyLimit: Double
}

struct Expense: Identifiable, Hashable {
    let id: Int
    let categoryId: Int
    let merchant: String
    let amount: Double
    let date: Date
    let note: String
}

struct BudgetSummary: Identifiable, Hashable {
    let category: Category
    let spent: Double

    var id: Int { category.id }
    var remaining: Double { category.monthlyLimit - spent }
    var percentUsed: Double {
        guard category.monthlyLimit > 0 else { return 0 }
        return min(spent / category.monthlyLimit, 1)
    }
}

struct RemoteExpense: Identifiable, Decodable, Hashable {
    let id: Int
    let category: String
    let categoryId: Int?
    let merchant: String
    let amount: Double
    let date: String
    let note: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case category
        case categoryId = "category_id"
        case merchant
        case amount
        case date
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        categoryId = try? container.decode(Int.self, forKey: .categoryId)
        category = (try? container.decode(String.self, forKey: .category))
            ?? "Category \(categoryId ?? 0)"
        let decodedNote = try container.decodeIfPresent(String.self, forKey: .note)
        merchant = try container.decodeIfPresent(String.self, forKey: .merchant)
            ?? decodedNote
            ?? "Expense"
        amount = try container.decode(Double.self, forKey: .amount)
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        note = decodedNote
    }

    init(id: Int, category: String, categoryId: Int?, merchant: String, amount: Double, date: String, note: String?) {
        self.id = id
        self.category = category
        self.categoryId = categoryId
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.note = note
    }
}
