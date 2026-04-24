import Foundation
import SQLite3

final class ExpenseDatabase {
    private var database: OpaquePointer?
    private let databaseURL: URL
    private let calendar = Calendar.current

    init(filename: String = "minerva.sqlite") {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        databaseURL = documents.appendingPathComponent(filename)
    }

    deinit {
        sqlite3_close(database)
    }

    func open() throws {
        if sqlite3_open(databaseURL.path, &database) != SQLITE_OK {
            throw databaseError("Unable to open database")
        }

        try execute("""
        CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            monthly_limit REAL NOT NULL
        );
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS expenses (
            id INTEGER PRIMARY KEY,
            category_id INTEGER NOT NULL,
            merchant TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT NOT NULL,
            FOREIGN KEY(category_id) REFERENCES categories(id)
        );
        """)

        try seedIfNeeded()
        try repairCategoryDataIfNeeded()
    }

    func categories() throws -> [Category] {
        let sql = "SELECT id, name, monthly_limit FROM categories ORDER BY name;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError("Unable to load categories")
        }
        defer { sqlite3_finalize(statement) }

        var results: [Category] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(Category(
                id: Int(sqlite3_column_int(statement, 0)),
                name: String(cString: sqlite3_column_text(statement, 1)),
                monthlyLimit: sqlite3_column_double(statement, 2)
            ))
        }
        return results
    }

    func expenses() throws -> [Expense] {
        let sql = "SELECT id, category_id, merchant, amount, date, note FROM expenses ORDER BY date DESC;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError("Unable to load expenses")
        }
        defer { sqlite3_finalize(statement) }

        var results: [Expense] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let dateText = String(cString: sqlite3_column_text(statement, 4))
            results.append(Expense(
                id: Int(sqlite3_column_int(statement, 0)),
                categoryId: Int(sqlite3_column_int(statement, 1)),
                merchant: String(cString: sqlite3_column_text(statement, 2)),
                amount: sqlite3_column_double(statement, 3),
                date: Self.dateFormatter.date(from: dateText) ?? Date(),
                note: String(cString: sqlite3_column_text(statement, 5))
            ))
        }
        return results
    }

    func addExpense(categoryId: Int, merchant: String, amount: Double, date: Date, note: String) throws {
        let sql = "INSERT INTO expenses (category_id, merchant, amount, date, note) VALUES (?, ?, ?, ?, ?);"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError("Unable to prepare expense insert")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(categoryId))
        sqlite3_bind_text(statement, 2, merchant, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 3, amount)
        sqlite3_bind_text(statement, 4, Self.dateFormatter.string(from: date), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, note, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError("Unable to save expense")
        }
    }

    func addCategory(name: String, monthlyLimit: Double) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw databaseError("Enter a category name.")
        }

        let duplicateSQL = "SELECT COUNT(*) FROM categories WHERE lower(name) = lower(?);"
        var duplicateStatement: OpaquePointer?
        guard sqlite3_prepare_v2(database, duplicateSQL, -1, &duplicateStatement, nil) == SQLITE_OK else {
            throw databaseError("Unable to check category name")
        }
        defer { sqlite3_finalize(duplicateStatement) }

        sqlite3_bind_text(duplicateStatement, 1, trimmedName, -1, SQLITE_TRANSIENT)
        if sqlite3_step(duplicateStatement) == SQLITE_ROW,
           sqlite3_column_int(duplicateStatement, 0) > 0 {
            throw databaseError("That category already exists.")
        }

        let nextId = try scalarInt("SELECT COALESCE(MAX(id), 0) + 1 FROM categories;")
        let insertSQL = "INSERT INTO categories (id, name, monthly_limit) VALUES (?, ?, ?);"
        var insertStatement: OpaquePointer?
        guard sqlite3_prepare_v2(database, insertSQL, -1, &insertStatement, nil) == SQLITE_OK else {
            throw databaseError("Unable to prepare category insert")
        }
        defer { sqlite3_finalize(insertStatement) }

        sqlite3_bind_int(insertStatement, 1, Int32(nextId))
        sqlite3_bind_text(insertStatement, 2, trimmedName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(insertStatement, 3, monthlyLimit)

        guard sqlite3_step(insertStatement) == SQLITE_DONE else {
            throw databaseError("Unable to save category")
        }
    }

    func updateCategoryLimit(categoryId: Int, monthlyLimit: Double) throws {
        let sql = "UPDATE categories SET monthly_limit = ? WHERE id = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError("Unable to prepare budget update")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, monthlyLimit)
        sqlite3_bind_int(statement, 2, Int32(categoryId))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError("Unable to update budget")
        }
    }

    func updateExpenseCategory(expenseId: Int, categoryId: Int) throws {
        let sql = "UPDATE expenses SET category_id = ? WHERE id = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError("Unable to prepare expense category update")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(categoryId))
        sqlite3_bind_int(statement, 2, Int32(expenseId))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError("Unable to update expense category")
        }
    }

    func deleteCategory(categoryId: Int) throws {
        try execute("DELETE FROM expenses WHERE category_id = \(categoryId);")
        try execute("DELETE FROM categories WHERE id = \(categoryId);")
    }

    func removeDuplicateExpenses() throws {
        try execute("""
        DELETE FROM expenses
        WHERE id NOT IN (
            SELECT MIN(id)
            FROM expenses
            GROUP BY merchant, amount, date
        );
        """)
    }

    func monthlySummaries(for date: Date = Date()) throws -> [BudgetSummary] {
        let categories = try categories()
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? date
        let sql = """
        SELECT category_id, SUM(amount)
        FROM expenses
        WHERE date >= ? AND date < ?
        GROUP BY category_id;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError("Unable to load budget summary")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, Self.dateFormatter.string(from: start), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, Self.dateFormatter.string(from: end), -1, SQLITE_TRANSIENT)

        var spentByCategory: [Int: Double] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            spentByCategory[Int(sqlite3_column_int(statement, 0))] = sqlite3_column_double(statement, 1)
        }

        return categories.map { category in
            BudgetSummary(category: category, spent: spentByCategory[category.id, default: 0])
        }
    }

    private func seedIfNeeded() throws {
        let categoryCount = try scalarInt("SELECT COUNT(*) FROM categories;")
        if categoryCount == 0 {
            try execute("""
            INSERT INTO categories (id, name, monthly_limit) VALUES
            (1, 'Groceries', 420.00),
            (2, 'Transportation', 180.00),
            (3, 'Rent', 1250.00),
            (4, 'School', 150.00),
            (5, 'Savings', 300.00),
            (6, 'Dining', 160.00),
            (7, 'Utilities', 300.00),
            (8, 'Misc', 200.00);
            """)
        }

        let expenseCount = try scalarInt("SELECT COUNT(*) FROM expenses;")
        guard expenseCount == 0 else { return }

        try execute("""
        INSERT INTO expenses (id, category_id, merchant, amount, date, note) VALUES
        (1, 1, 'Smiths Marketplace', 86.42, '2026-04-02', 'Weekly groceries'),
        (2, 2, 'UTA FrontRunner', 38.50, '2026-04-03', 'Transit pass'),
        (3, 7, 'Orem City Utilities', 116.18, '2026-04-05', 'Electric and water'),
        (4, 3, 'Northview Apartments', 1250.00, '2026-04-06', 'Monthly rent'),
        (5, 6, 'Aubergine Kitchen', 17.64, '2026-04-07', 'Lunch after class'),
        (6, 4, 'UVU Bookstore', 42.99, '2026-04-10', 'Notebook and lab supplies'),
        (7, 5, 'America First Credit Union', 150.00, '2026-04-12', 'Emergency fund transfer'),
        (8, 1, 'Trader Joes', 54.27, '2026-04-15', 'Produce and snacks'),
        (9, 2, 'Chevron', 44.10, '2026-04-17', 'Gas'),
        (10, 6, 'Cafe Zupas', 13.83, '2026-04-19', 'Dinner'),
        (11, 1, 'Costco', 112.36, '2026-04-21', 'Bulk groceries');
        """)
    }

    private func repairCategoryDataIfNeeded() throws {
        try execute("""
        INSERT INTO categories (id, name, monthly_limit)
        SELECT 7, 'Utilities', 300.00
        WHERE NOT EXISTS (
            SELECT 1
            FROM categories
            WHERE id = 7
        );
        """)

        try execute("""
        INSERT INTO categories (id, name, monthly_limit)
        SELECT 8, 'Misc', 200.00
        WHERE NOT EXISTS (
            SELECT 1
            FROM categories
            WHERE id = 8
        );
        """)

        try execute("""
        UPDATE categories
        SET name = CASE id
            WHEN 3 THEN 'Rent'
            WHEN 7 THEN 'Utilities'
            ELSE name
        END
        WHERE id IN (3, 7);
        """)

        try execute("""
        UPDATE expenses
        SET category_id = 7
        WHERE id = 3
          AND merchant = 'Orem City Utilities'
          AND category_id = 3;
        """)

        try execute("""
        INSERT INTO expenses (category_id, merchant, amount, date, note)
        SELECT 7, 'Orem City Utilities', 116.18, '2026-04-05', 'Electric and water'
        WHERE NOT EXISTS (
            SELECT 1
            FROM expenses
            WHERE category_id = 7
              AND merchant = 'Orem City Utilities'
        );
        """)

        try execute("""
        INSERT INTO expenses (category_id, merchant, amount, date, note)
        SELECT 3, 'Northview Apartments', 1250.00, '2026-04-06', 'Monthly rent'
        WHERE NOT EXISTS (
            SELECT 1
            FROM expenses
            WHERE category_id = 3
              AND merchant = 'Northview Apartments'
        );
        """)
    }

    private func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown database error"
            sqlite3_free(errorMessage)
            throw databaseError(message)
        }
    }

    private func scalarInt(_ sql: String) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError("Unable to prepare count query")
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func databaseError(_ message: String) -> NSError {
        NSError(domain: "MinervaDatabase", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
