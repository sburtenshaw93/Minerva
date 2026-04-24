import Foundation

struct ExpenseAPIService {
    var baseURL = URL(string: "http://127.0.0.1:8000")!

    func fetchExpenses() async throws -> [RemoteExpense] {
        let possiblePaths = ["expenses", "expenses/"]
        var lastError: Error?

        for path in possiblePaths {
            do {
                let url = baseURL.appendingPathComponent(path)
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return try JSONDecoder().decode([RemoteExpense].self, from: data)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? URLError(.cannotConnectToHost)
    }
}
