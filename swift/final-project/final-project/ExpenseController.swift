import Foundation
import Observation

@MainActor
@Observable
final class ExpenseController {
    private(set) var categories: [Category] = []
    private(set) var expenses: [Expense] = []
    private(set) var summaries: [BudgetSummary] = []
    private(set) var remoteExpenses: [RemoteExpense] = []
    var errorMessage: String?
    var isLoadingAPI = false

    @ObservationIgnored private let database: ExpenseDatabase
    @ObservationIgnored private let apiService: ExpenseAPIService

    init() {
        database = ExpenseDatabase()
        apiService = ExpenseAPIService()
        loadLocalData()
    }

    init(database: ExpenseDatabase, apiService: ExpenseAPIService) {
        self.database = database
        self.apiService = apiService
        loadLocalData()
    }

    var totalSpent: Double {
        summaries.reduce(0) { $0 + $1.spent }
    }

    var totalLimit: Double {
        summaries.reduce(0) { $0 + $1.category.monthlyLimit }
    }

    var totalRemaining: Double {
        totalLimit - totalSpent
    }

    func loadLocalData() {
        do {
            try database.open()
            categories = try database.categories()
            try repairExpenseCategories()
            try database.removeDuplicateExpenses()
            expenses = try database.expenses()
            summaries = try database.monthlySummaries()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addExpense(categoryId: Int, merchant: String, amount: Double, note: String, date: Date = Date()) {
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMerchant.isEmpty, amount > 0 else {
            errorMessage = "Enter a merchant and an amount greater than zero."
            return
        }

        do {
            try database.addExpense(
                categoryId: categoryId,
                merchant: trimmedMerchant,
                amount: amount,
                date: date,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            expenses = try database.expenses()
            summaries = try database.monthlySummaries()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateBudgetLimit(categoryId: Int, monthlyLimit: Double) {
        guard monthlyLimit > 0 else {
            errorMessage = "Enter a budget amount greater than zero."
            return
        }

        do {
            try database.updateCategoryLimit(categoryId: categoryId, monthlyLimit: monthlyLimit)
            categories = try database.categories()
            summaries = try database.monthlySummaries()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addCategory(name: String, monthlyLimit: Double) {
        guard monthlyLimit > 0 else {
            errorMessage = "Enter a budget amount greater than zero."
            return
        }

        do {
            try database.addCategory(name: name, monthlyLimit: monthlyLimit)
            categories = try database.categories()
            summaries = try database.monthlySummaries()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCategory(categoryId: Int) {
        do {
            try database.deleteCategory(categoryId: categoryId)
            categories = try database.categories()
            expenses = try database.expenses()
            summaries = try database.monthlySummaries()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateExpenseCategory(expenseId: Int, categoryId: Int) {
        do {
            try database.updateExpenseCategory(expenseId: expenseId, categoryId: categoryId)
            expenses = try database.expenses()
            summaries = try database.monthlySummaries()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshFromAPI() async {
        isLoadingAPI = true
        defer { isLoadingAPI = false }

        do {
            let fetchedExpenses = try await apiService.fetchExpenses()
            let resolvedExpenses = fetchedExpenses.map(resolveRemoteExpenseCategory)
            try syncRemoteExpensesIntoLocalDatabase(resolvedExpenses)
            try repairExpenseCategories()
            try database.removeDuplicateExpenses()
            remoteExpenses = resolvedExpenses
            expenses = try database.expenses()
            summaries = try database.monthlySummaries()
            errorMessage = nil
        } catch {
            errorMessage = "Could not reach the Python API at http://127.0.0.1:8000. Start the backend, then tap Sync API again."
        }
    }

    private func resolveRemoteExpenseCategory(_ expense: RemoteExpense) -> RemoteExpense {
        let resolvedCategory = resolvedCategory(for: expense)

        return RemoteExpense(
            id: expense.id,
            category: resolvedCategory?.name ?? expense.category,
            categoryId: resolvedCategory?.id,
            merchant: expense.merchant,
            amount: expense.amount,
            date: expense.date,
            note: expense.note
        )
    }

    private func syncRemoteExpensesIntoLocalDatabase(_ remoteExpenses: [RemoteExpense]) throws {
        let existingKeys = Set(expenses.map(expenseKey))

        for expense in remoteExpenses {
            guard let categoryId = expense.categoryId else { continue }
            let expenseDate = Self.apiDateFormatter.date(from: expense.date) ?? Date()
            let note = expense.note ?? expense.merchant
            let merchant = expense.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate = ExpenseSyncKey(
                merchant: merchant,
                amount: expense.amount,
                date: expense.date
            )

            if existingKeys.contains(candidate) { continue }

            try database.addExpense(
                categoryId: categoryId,
                merchant: merchant,
                amount: expense.amount,
                date: expenseDate,
                note: note
            )
        }
    }

    private func expenseKey(for expense: Expense) -> ExpenseSyncKey {
        ExpenseSyncKey(
            merchant: expense.merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: expense.amount,
            date: Self.apiDateFormatter.string(from: expense.date)
        )
    }

    private struct ExpenseSyncKey: Hashable {
        let merchant: String
        let amount: Double
        let date: String
    }

    private func repairExpenseCategories() throws {
        let currentExpenses = try database.expenses()
        for expense in currentExpenses {
            guard let correctedCategory = resolvedCategory(forMerchant: expense.merchant, note: expense.note) else {
                continue
            }

            if correctedCategory.id != expense.categoryId {
                try database.updateExpenseCategory(expenseId: expense.id, categoryId: correctedCategory.id)
            }
        }
    }

    private func resolvedCategory(for expense: RemoteExpense) -> Category? {
        if let matchedByName = category(named: expense.category) {
            return matchedByName
        }

        if let matchedByMerchant = resolvedCategory(forMerchant: expense.merchant, note: expense.note) {
            return matchedByMerchant
        }

        guard let categoryId = expense.categoryId else { return nil }
        return categories.first(where: { $0.id == categoryId })
    }

    private func resolvedCategory(forMerchant merchant: String, note: String?) -> Category? {
        let haystack = normalized("\(merchant) \(note ?? "")")

        for rule in categoryRules {
            if rule.keywords.contains(where: { haystack.contains($0) }) {
                return category(named: rule.categoryName)
            }
        }

        return nil
    }

    private func category(named name: String) -> Category? {
        let target = normalized(name)
        return categories.first { normalized($0.name) == target }
    }

    private func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let categoryRules: [(categoryName: String, keywords: [String])] = [
        ("Groceries", ["costco", "smiths", "smith's", "trader joe", "whole foods", "harmons", "walmart", "target", "grocery"]),
        ("Dining", ["zupas", "cafe", "coffee", "restaurant", "doordash", "ubereats", "chick-fil-a", "chick fil a", "aubergine"]),
        ("Rent", ["rent", "apartment", "apartments", "property", "mortgage", "northview"]),
        ("Transportation", ["uber", "lyft", "delta", "front runner", "frontrunner", "uta", "gas", "chevron", "shell", "transport", "costco-gas"]),
        ("Utilities", ["utility", "utilities", "electric", "water", "power", "dominion", "orem city", "provo city"]),
        ("School", ["uvu", "tuition", "bookstore", "school", "college", "university"]),
        ("Savings", ["savings", "emergency fund", "credit union", "america first", "transfer"]),
        ("Misc", ["walgreens", "saucony", "hobby lobby", "turbo tax", "turbotax", "concert", "shoes", "lowes", "megaplex", "theater", "The devil wears prada", ])
    ]

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
