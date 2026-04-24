import SwiftUI
import PhotosUI
import Observation
import UIKit

struct ContentView: View {
    @State private var controller = ExpenseController()
    @State private var henryWorkspace = HenryWorkspace()
    @State private var selectedTab = AppTab.home
    @State private var showingAddExpense = false
    @State private var selectedCategoryFilter: Int?
    @AppStorage("minervaUsesDarkAppearance") private var usesDarkAppearance = true

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            TabView(selection: $selectedTab) {
                HomeScreen(
                    controller: controller,
                    selectedCategoryFilter: $selectedCategoryFilter,
                    selectedTab: $selectedTab
                )
                .tag(AppTab.home)

                HistoryScreen(
                    controller: controller,
                    selectedCategoryFilter: $selectedCategoryFilter,
                    selectedTab: $selectedTab
                )
                    .tag(AppTab.history)

                BudgetScreen(
                    controller: controller,
                    selectedCategoryFilter: $selectedCategoryFilter,
                    selectedTab: $selectedTab
                )
                    .tag(AppTab.budget)

                HenryAssistantScreen(
                    controller: controller,
                    workspace: henryWorkspace,
                    openAddExpense: { showingAddExpense = true },
                    selectedTab: $selectedTab
                )
                    .tag(AppTab.insights)

                MoreScreen(controller: controller, usesDarkAppearance: $usesDarkAppearance)
                    .tag(AppTab.more)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(.keyboard, edges: .bottom)

            GlassTabBar(selectedTab: $selectedTab, showingAddExpense: $showingAddExpense)
        }
        .foregroundStyle(Color.minervaText)
        .tint(Color.minervaOrange)
        .preferredColorScheme(usesDarkAppearance ? .dark : .light)
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseSheet(controller: controller, workspace: henryWorkspace)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await controller.refreshFromAPI()
            henryWorkspace.refreshCategories(controller.categories)
            henryWorkspace.refreshBudgetSignals(controller.summaries)
        }
    }
}

private enum AppTab: String, CaseIterable {
    case home = "Home"
    case history = "History"
    case budget = "Budget"
    case insights = "Henry"
    case more = "More"

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .history: "clock.arrow.circlepath"
        case .budget: "chart.pie.fill"
        case .insights: "henry-icon"
        case .more: "ellipsis.circle"
        }
    }

    var usesAssetIcon: Bool {
        self == .insights
    }
}

private struct HomeScreen: View {
    let controller: ExpenseController
    @Binding var selectedCategoryFilter: Int?
    @Binding var selectedTab: AppTab
    @AppStorage("minervaBudgetChartStyle") private var chartStyle = BudgetChartStyle.donut.rawValue
    @AppStorage("minervaBudgetPalette") private var paletteStyle = BudgetPalette.earth.rawValue
    @State private var showingAlerts = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                BudgetHeroCard(controller: controller) {
                    showingAlerts = true
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle(title: "Spending by Category", actionTitle: "View budgets") {
                            selectedTab = .budget
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            homeChart
                                .frame(maxWidth: .infinity, alignment: .center)

                            VStack(spacing: 12) {
                                ForEach(controller.summaries) { summary in
                                    Button {
                                        selectedCategoryFilter = summary.category.id
                                        selectedTab = .history
                                    } label: {
                                        CategoryAmountRow(summary: summary, palette: activePalette)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(title: "Recent Transactions", actionTitle: "See all") {
                            selectedCategoryFilter = nil
                            selectedTab = .history
                        }

                        ForEach(controller.expenses.prefix(4)) { expense in
                            ExpenseRow(expense: expense, categoryName: categoryName(for: expense.categoryId))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            PinnedBrandHeader(title: "MINERVA", subtitle: "Welcome back, Sarah") {
                selectedTab = .more
            }
        }
        .sheet(isPresented: $showingAlerts) {
            AlertsSheet(alerts: currentAlerts)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func categoryName(for id: Int) -> String {
        controller.categories.first { $0.id == id }?.name ?? "Uncategorized"
    }

    private var activePalette: BudgetPalette {
        BudgetPalette(rawValue: paletteStyle) ?? .earth
    }

    private var currentAlerts: [FinancialAlert] {
        var alerts: [FinancialAlert] = []

        let watchedSummaries = controller.summaries
            .filter { $0.percentUsed >= 0.75 }
            .sorted { $0.percentUsed > $1.percentUsed }

        for summary in watchedSummaries.prefix(3) {
            if summary.remaining < 0 {
                alerts.append(
                    FinancialAlert(
                        title: "\(summary.category.name) is over budget",
                        message: "You are \(abs(summary.remaining).formatted(.currency(code: "USD"))) over your limit in \(summary.category.name).",
                        tone: .danger,
                        symbol: "exclamationmark.triangle.fill"
                    )
                )
            } else {
                alerts.append(
                    FinancialAlert(
                        title: "\(summary.category.name) is close to its limit",
                        message: "\(summary.remaining.formatted(.currency(code: "USD"))) left in this category for the month.",
                        tone: .warning,
                        symbol: "bell.badge.fill"
                    )
                )
            }
        }

        if let largestExpense = controller.expenses.max(by: { $0.amount < $1.amount }) {
            alerts.append(
                FinancialAlert(
                    title: "Largest recent expense",
                    message: "\(largestExpense.merchant) posted for \(largestExpense.amount.formatted(.currency(code: "USD"))).",
                    tone: .info,
                    symbol: "creditcard.fill"
                )
            )
        }

        if alerts.isEmpty {
            alerts.append(
                FinancialAlert(
                    title: "No alerts right now",
                    message: "Your current budgets are stable and there are no spending warnings to review.",
                    tone: .success,
                    symbol: "checkmark.seal.fill"
                )
            )
        }

        return alerts
    }

    @ViewBuilder
    private var homeChart: some View {
        switch BudgetChartStyle(rawValue: chartStyle) ?? .donut {
        case .bar:
            SpendingBarChart(summaries: controller.summaries, palette: activePalette)
                .frame(height: 160)
                .frame(maxWidth: .infinity)
        case .donut:
            SpendingRingView(summaries: controller.summaries, palette: activePalette)
                .frame(width: 158, height: 158)
        }
    }
}

private struct HistoryScreen: View {
    let controller: ExpenseController
    @Binding var selectedCategoryFilter: Int?
    @Binding var selectedTab: AppTab
    @State private var editingExpense: Expense?

    private var filteredExpenses: [Expense] {
        guard let selectedCategoryFilter else { return controller.expenses }
        return controller.expenses.filter { $0.categoryId == selectedCategoryFilter }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if let errorMessage = controller.errorMessage {
                    InsightBanner(message: errorMessage)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(title: "Expenses", actionTitle: nil, action: nil)

                        ForEach(filteredExpenses) { expense in
                            Button {
                                editingExpense = expense
                            } label: {
                                ExpenseRow(expense: expense, categoryName: categoryName(for: expense.categoryId))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                PinnedBrandHeader(title: "MINERVA", subtitle: "Expense History") {
                    selectedTab = .more
                }

                PinnedHistoryFilters(
                    categories: controller.categories,
                    selectedCategoryFilter: $selectedCategoryFilter
                )
            }
        }
        .sheet(item: $editingExpense) { expense in
            EditExpenseCategorySheet(
                expense: expense,
                categories: controller.categories
            ) { newCategoryId in
                controller.updateExpenseCategory(expenseId: expense.id, categoryId: newCategoryId)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func categoryName(for id: Int) -> String {
        controller.categories.first { $0.id == id }?.name ?? "Uncategorized"
    }
}

private struct EditExpenseCategorySheet: View {
    let expense: Expense
    let categories: [Category]
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategoryId: Int

    init(expense: Expense, categories: [Category], onSave: @escaping (Int) -> Void) {
        self.expense = expense
        self.categories = categories
        self.onSave = onSave
        _selectedCategoryId = State(initialValue: expense.categoryId)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        BrandHeader(title: "MINERVA", subtitle: "Move Transaction")

                        GlassCard {
                            VStack(alignment: .leading, spacing: 18) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(expense.merchant)
                                        .font(.title3.weight(.bold))
                                    Text(expense.amount, format: .currency(code: "USD"))
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(Color.minervaDanger)
                                    Text(expense.date, format: .dateTime.month(.wide).day().year())
                                        .font(.subheadline)
                                        .foregroundStyle(Color.minervaSubtext)
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Category")

                                    LazyVGrid(
                                        columns: [
                                            GridItem(.flexible(), spacing: 10),
                                            GridItem(.flexible(), spacing: 10)
                                        ],
                                        spacing: 10
                                    ) {
                                        ForEach(categories) { category in
                                            CategoryChip(
                                                title: category.name,
                                                isSelected: selectedCategoryId == category.id
                                            ) {
                                                selectedCategoryId = category.id
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            onSave(selectedCategoryId)
                            dismiss()
                        } label: {
                            Label("Save Category", systemImage: "arrow.right")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.minervaOrange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.minervaSubtext)
                }
            }
        }
    }
}

private struct PinnedHistoryFilters: View {
    let categories: [Category]
    @Binding var selectedCategoryFilter: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "All", isSelected: selectedCategoryFilter == nil) {
                    selectedCategoryFilter = nil
                }

                ForEach(categories) { category in
                    FilterChip(title: category.name, isSelected: selectedCategoryFilter == category.id) {
                        selectedCategoryFilter = category.id
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.minervaGlass.opacity(0.45))
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.8)
        }
    }
}

private struct BudgetScreen: View {
    let controller: ExpenseController
    @Binding var selectedCategoryFilter: Int?
    @Binding var selectedTab: AppTab
    @AppStorage("minervaBudgetChartStyle") private var chartStyle = BudgetChartStyle.donut.rawValue
    @AppStorage("minervaBudgetPalette") private var paletteStyle = BudgetPalette.earth.rawValue
    @State private var editingSummary: BudgetSummary?
    @State private var showingStyleEditor = false
    @State private var showingNewCategory = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                GlassCard {
                    VStack(alignment: .center, spacing: 14) {
                        Text(controller.totalRemaining, format: .currency(code: "USD"))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.minervaSuccess)
                        Text("Left this month")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.minervaSubtext)
                        HStack(spacing: 12) {
                            budgetMetric(title: "Budget\nLimit", icon: "target", value: controller.totalLimit)
                            budgetMetric(title: "Spent", icon: "creditcard.fill", value: controller.totalSpent)
                            budgetMetric(title: "Left", icon: "wallet.pass.fill", value: controller.totalRemaining)
                        }
                        selectedChart
                        Button {
                            showingStyleEditor = true
                        } label: {
                            Label("Edit Style", systemImage: "slider.horizontal.3")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.minervaOrange)
                    }
                    .frame(maxWidth: .infinity)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Projection", systemImage: projectionIcon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(projectionTone)
                        Text(projectionTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.minervaText)
                        Text(projectionMessage)
                            .font(.subheadline)
                            .foregroundStyle(Color.minervaSubtext)
                    }
                }

                if !budgetAlerts.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Alerts", systemImage: "exclamationmark.triangle")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.minervaDanger)

                            ForEach(budgetAlerts) { alert in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(alert.title)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(Color.minervaText)
                                    Text(alert.message)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.minervaSubtext)
                                }
                                .padding(.bottom, alert.id == budgetAlerts.last?.id ? 0 : 8)
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Spending vs Goal")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.minervaText)
                            Spacer()
                            Button {
                                showingNewCategory = true
                            } label: {
                                Label("New Category", systemImage: "plus")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.minervaOrange)
                        }

                        ForEach(controller.summaries) { summary in
                            Button {
                                selectedCategoryFilter = summary.category.id
                                editingSummary = summary
                            } label: {
                                BudgetProgressRow(summary: summary, palette: activePalette)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            PinnedBrandHeader(title: "MINERVA", subtitle: "Budget Summary") {
                selectedTab = .more
            }
        }
        .sheet(item: $editingSummary) { summary in
            EditBudgetSheet(
                summary: summary,
                onSave: { newLimit in
                    controller.updateBudgetLimit(categoryId: summary.category.id, monthlyLimit: newLimit)
                    editingSummary = nil
                },
                onDelete: {
                    controller.deleteCategory(categoryId: summary.category.id)
                    editingSummary = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingStyleEditor) {
            BudgetStyleSheet(chartStyle: $chartStyle, paletteStyle: $paletteStyle)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNewCategory) {
            NewCategorySheet { name, limit in
                controller.addCategory(name: name, monthlyLimit: limit)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var activePalette: BudgetPalette {
        BudgetPalette(rawValue: paletteStyle) ?? .earth
    }

    private func budgetMetric(title: String, icon: String, value: Double) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.minervaOrange)
                .frame(width: 28, height: 28)
                .background(Color.minervaGlass, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.minervaSubtext)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)

            Text(value, format: .currency(code: "USD"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.minervaText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 132)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(Color.minervaPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var projectionTone: Color {
        projectedFinishAmount <= controller.totalLimit ? .minervaSuccess : .minervaWarning
    }

    private var projectionIcon: String {
        projectedFinishAmount <= controller.totalLimit ? "checkmark.seal.fill" : "chart.line.uptrend.xyaxis"
    }

    private var projectionTitle: String {
        projectedFinishAmount <= controller.totalLimit ? "On Track" : "Spending Fast"
    }

    private var projectionMessage: String {
        let difference = abs(projectedFinishAmount - controller.totalLimit)
        if projectedFinishAmount <= controller.totalLimit {
            return "At this pace, you should finish about \(difference.formatted(.currency(code: "USD"))) under budget this month."
        }
        return "At this pace, you may finish about \(difference.formatted(.currency(code: "USD"))) over budget this month."
    }

    private var projectedFinishAmount: Double {
        guard let lastExpenseDate = controller.expenses.map(\.date).max() else { return controller.totalSpent }
        let calendar = Calendar.current
        let day = max(calendar.component(.day, from: lastExpenseDate), 1)
        let daysInMonth = calendar.range(of: .day, in: .month, for: lastExpenseDate)?.count ?? 30
        let dailyAverage = controller.totalSpent / Double(day)
        return dailyAverage * Double(daysInMonth)
    }

    private var budgetAlerts: [BudgetAlert] {
        controller.summaries.compactMap { summary in
            if summary.remaining < 0 {
                return BudgetAlert(
                    title: "\(summary.category.name) Alert",
                    message: "This category is \(abs(summary.remaining).formatted(.currency(code: "USD"))) over budget."
                )
            }
            if summary.percentUsed >= 0.9 && summary.remaining > 0 {
                return BudgetAlert(
                    title: "\(summary.category.name) Alert",
                    message: "You have used \(Int(summary.percentUsed * 100))% of this budget with \(summary.remaining.formatted(.currency(code: "USD"))) left."
                )
            }
            return nil
        }
    }

    @ViewBuilder
    private var selectedChart: some View {
        switch BudgetChartStyle(rawValue: chartStyle) ?? .donut {
        case .bar:
            SpendingBarChart(summaries: controller.summaries, palette: activePalette)
                .frame(height: 160)
                .frame(maxWidth: .infinity)
        case .donut:
            SpendingRingView(summaries: controller.summaries, palette: activePalette)
                .frame(width: 158, height: 158)
        }
    }
}

private struct BudgetAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct NewCategorySheet: View {
    let onSave: (String, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var categoryName = ""
    @State private var limitText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        BrandHeader(title: "MINERVA", subtitle: "New Budget Category")

                        GlassCard {
                            VStack(alignment: .leading, spacing: 18) {
                                VStack(spacing: 6) {
                                    Text("MONTHLY LIMIT")
                                        .font(.caption.weight(.heavy))
                                        .tracking(1.4)
                                        .foregroundStyle(Color.minervaSubtext)

                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text("$")
                                            .font(.title.weight(.bold))
                                            .foregroundStyle(Color.minervaSuccess)
                                        TextField("0.00", text: $limitText)
                                            .font(.system(size: 44, weight: .bold, design: .rounded))
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.center)
                                    }

                                    Text("Set the starting limit for this new category.")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.minervaSubtext)
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Category Name")
                                    TextField("Example: Health, Pets, Travel", text: $categoryName)
                                        .textFieldStyle(MinervaTextFieldStyle())
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Monthly Limit")
                                    TextField("Budget limit", text: $limitText)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(MinervaTextFieldStyle())
                                }
                            }
                        }

                        Button {
                            saveCategory()
                        } label: {
                            Label("Create Category", systemImage: "arrow.right")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.minervaOrange)
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.55)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.minervaSubtext)
                }
            }
        }
    }

    private var limitValue: Double? {
        Double(limitText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canSave: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (limitValue ?? 0) > 0
    }

    private func saveCategory() {
        guard let newLimit = limitValue, newLimit > 0 else { return }
        onSave(categoryName.trimmingCharacters(in: .whitespacesAndNewlines), newLimit)
        dismiss()
    }
}

private struct BudgetStyleSheet: View {
    @Binding var chartStyle: String
    @Binding var paletteStyle: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        BrandHeader(title: "MINERVA", subtitle: "Chart Style")

                        GlassCard {
                            VStack(alignment: .leading, spacing: 18) {
                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Chart Type")
                                    Picker("Chart Type", selection: $chartStyle) {
                                        ForEach(BudgetChartStyle.allCases) { style in
                                            Text(style.title).tag(style.rawValue)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Color Theme")
                                    HStack(spacing: 10) {
                                        ForEach(BudgetPalette.allCases) { palette in
                                            PaletteSwatch(
                                                palette: palette,
                                                isSelected: paletteStyle == palette.rawValue
                                            ) {
                                                paletteStyle = palette.rawValue
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.minervaOrange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private enum BudgetChartStyle: String, CaseIterable, Identifiable {
    case bar
    case donut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bar: "Bar"
        case .donut: "Doughnut"
        }
    }
}

private struct HenryAssistantScreen: View {
    let controller: ExpenseController
    let workspace: HenryWorkspace
    let openAddExpense: () -> Void
    @Binding var selectedTab: AppTab

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            HStack(spacing: 12) {
                                HenryMark()
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Henry Assistant")
                                        .font(.headline.weight(.bold))
                                    Text(workspace.primaryStatusLine)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.minervaSubtext)
                                }
                            }
                            Spacer()
                            Button("Open Draft") {
                                openAddExpense()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.minervaOrange)
                        }

                        if let draft = workspace.draft, draft.receiptAttached || !draft.merchant.isEmpty {
                            HenryInsightCard(
                                title: "Receipt Import",
                                subtitle: workspace.receiptSummaryLine,
                                tone: .info,
                                actionTitle: "Use in Add Expense",
                                action: openAddExpense
                            )
                        }

                        if let suggestedCategory = workspace.suggestedCategory {
                            HenryInsightCard(
                                title: "Suggested Category",
                                subtitle: "\(suggestedCategory.name) • \(workspace.categoryReason)",
                                tone: .success,
                                actionTitle: "Apply Draft",
                                action: openAddExpense
                            )
                        }

                        if let budgetMessage = workspace.budgetWarningLine {
                            HenryInsightCard(
                                title: "Budget Watch",
                                subtitle: budgetMessage,
                                tone: .warning,
                                actionTitle: "View Budget",
                                action: nil
                            )
                        }

                        if !workspace.recommendedPrompts.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Recommended Actions")
                                    .font(.headline.weight(.bold))
                                ForEach(workspace.recommendedPrompts, id: \.self) { prompt in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(Color.minervaMint300)
                                            .frame(width: 8, height: 8)
                                            .padding(.top, 6)
                                        Text(prompt)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.minervaSubtext)
                                    }
                                }
                            }
                        }

                        Text("Henry uses your receipt draft and current budget pressure to guide the next action.")
                            .font(.subheadline)
                            .foregroundStyle(Color.minervaSubtext)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            PinnedBrandHeader(title: "MINERVA", subtitle: "Henry") {
                selectedTab = .more
            }
        }
    }
}

private struct EditBudgetSheet: View {
    let summary: BudgetSummary
    let onSave: (Double) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var limitText: String
    @State private var showingDeleteConfirmation = false

    init(summary: BudgetSummary, onSave: @escaping (Double) -> Void, onDelete: @escaping () -> Void) {
        self.summary = summary
        self.onSave = onSave
        self.onDelete = onDelete
        _limitText = State(initialValue: String(format: "%.2f", summary.category.monthlyLimit))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        BrandHeader(title: "MINERVA", subtitle: "Edit Budget")

                        GlassCard {
                            VStack(alignment: .leading, spacing: 18) {
                                VStack(spacing: 6) {
                                    Text("MONTHLY LIMIT")
                                        .font(.caption.weight(.heavy))
                                        .tracking(1.4)
                                        .foregroundStyle(Color.minervaSubtext)

                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text("$")
                                            .font(.title.weight(.bold))
                                            .foregroundStyle(Color.minervaSuccess)
                                        TextField("0.00", text: $limitText)
                                            .font(.system(size: 44, weight: .bold, design: .rounded))
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.center)
                                    }

                                    Text(summary.category.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.minervaSubtext)
                                }

                                GlassCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Budget Summary")
                                                .font(.headline.weight(.bold))
                                            Text("Update the monthly limit for \(summary.category.name).")
                                                .font(.subheadline)
                                                .foregroundStyle(Color.minervaSubtext)
                                        }
                                        Spacer()
                                        Circle()
                                            .fill(color(for: summary.category.id))
                                            .frame(width: 14, height: 14)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Category")
                                    Text(summary.category.name)
                                        .font(.headline.weight(.semibold))
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.minervaPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Monthly Limit")
                                    TextField("Budget limit", text: $limitText)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(MinervaTextFieldStyle())
                                }
                            }
                        }

                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Budget Impact")
                                        .font(.headline.weight(.bold))
                                    Text("You have spent \(summary.spent, format: .currency(code: "USD")) and will have \(remainingAfterSave, format: .currency(code: "USD")) left after this change.")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.minervaSubtext)
                                }
                                Spacer()
                                Text(limitValue ?? 0, format: .currency(code: "USD"))
                                    .font(.title3.weight(.bold))
                            }
                        }

                        Button {
                            saveBudget()
                        } label: {
                            Label("Save Budget", systemImage: "arrow.right")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.minervaOrange)
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.55)

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Category", systemImage: "trash")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.minervaSubtext)
                }
            }
            .alert("Delete Category?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove \(summary.category.name) and all transactions currently assigned to it.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var limitValue: Double? {
        Double(limitText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canSave: Bool {
        (limitValue ?? 0) > 0
    }

    private var remainingAfterSave: Double {
        max((limitValue ?? 0) - summary.spent, 0)
    }

    private func saveBudget() {
        guard let newLimit = limitValue, newLimit > 0 else { return }
        onSave(newLimit)
        dismiss()
    }
}

private struct PaletteSwatch: View {
    let palette: BudgetPalette
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(Array(palette.colors.prefix(4).enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 12, height: 12)
                    }
                }
                Text(palette.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.minervaSubtext)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(isSelected ? Color.minervaMint200 : Color.minervaPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.minervaClay : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MoreScreen: View {
    let controller: ExpenseController
    @Binding var usesDarkAppearance: Bool
    @AppStorage("minervaProfileName") private var profileName = "Sarah Burtenshaw"
    @AppStorage("minervaProfileEmail") private var profileEmail = "sarah@example.com"
    @AppStorage("minervaProfileBio") private var profileBio = "Minerva personal finance tracker"
    @AppStorage("minervaProfileImageBase64") private var profileImageBase64 = ""
    @State private var showingEditProfile = false
    @State private var showingAbout = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                GlassCard {
                    VStack(spacing: 14) {
                        ProfileAvatar(imageBase64: profileImageBase64, size: 78)

                        Text(profileName)
                            .font(.title2.weight(.bold))

                        Text(profileBio)
                            .font(.subheadline)
                            .foregroundStyle(Color.minervaSubtext)

                        Text(profileEmail)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.minervaSubtext)

                        Button {
                            showingEditProfile = true
                        } label: {
                            Label("Edit Profile", systemImage: "pencil")
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.minervaOrange)
                    }
                    .frame(maxWidth: .infinity)
                }

                GlassCard {
                    Toggle(isOn: $usesDarkAppearance) {
                        SettingsRow(icon: "moon.stars.fill", title: "Dark glass mode", subtitle: "Switch between dark and light styling")
                    }
                    .toggleStyle(.switch)
                }

                GlassCard {
                    Button {
                        showingAbout = true
                    } label: {
                        SettingsRow(
                            icon: "info.circle.fill",
                            title: "About Minerva",
                            subtitle: "App purpose, sync, and project details"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            PinnedBrandHeader(title: "MINERVA", subtitle: "Profile and Settings")
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileSheet(
                name: $profileName,
                email: $profileEmail,
                bio: $profileBio,
                imageBase64: $profileImageBase64
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAbout) {
            AboutMinervaSheet(controller: controller)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct AboutMinervaSheet: View {
    let controller: ExpenseController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        BrandHeader(title: "MINERVA", subtitle: "About Minerva")

                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Purpose")
                                    .font(.headline.weight(.bold))
                                Text("Minerva helps users track expenses, monitor category budgets, and review spending across Home, History, Budget, Henry, and More.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.minervaSubtext)
                            }
                        }

                        GlassCard {
                            VStack(spacing: 0) {
                                AboutRow(
                                    icon: "internaldrive.fill",
                                    title: "Local SQLite Storage",
                                    detail: "Expenses and category budgets are saved in a local SQLite database with seeded sample data."
                                )
                                Divider().padding(.leading, 50)
                                AboutRow(
                                    icon: "network",
                                    title: "Python API Sync",
                                    detail: "The app downloads JSON expense data from a FastAPI backend and syncs it into local storage."
                                )
                                Divider().padding(.leading, 50)
                                AboutRow(
                                    icon: "square.stack.3d.up.fill",
                                    title: "MVC Structure",
                                    detail: "Models live in ExpenseModels.swift, the controller lives in ExpenseController.swift, and the views live in ContentView.swift."
                                )
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("Backend Data", systemImage: "network")
                                        .font(.headline.weight(.bold))
                                    Spacer()
                                    Button {
                                        Task { await controller.refreshFromAPI() }
                                    } label: {
                                        if controller.isLoadingAPI {
                                            ProgressView()
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.minervaGreen)
                                }

                                Text("Minerva syncs backend expense data from the Python API and uses it throughout the app.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.minervaSubtext)

                                if let errorMessage = controller.errorMessage, controller.remoteExpenses.isEmpty {
                                    InsightBanner(message: errorMessage)
                                }

                                if controller.remoteExpenses.isEmpty {
                                    EmptyStateView(title: "No API rows loaded", message: "Start the backend, then tap sync.")
                                } else {
                                    ForEach(controller.remoteExpenses.prefix(8)) { expense in
                                        RemoteExpenseRow(expense: expense)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 22)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.minervaSubtext)
                }
            }
        }
    }
}

private struct AboutRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Color.minervaGreen)
                .frame(width: 34, height: 34)
                .background(Color.minervaMint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.minervaSubtext)
            }

            Spacer()
        }
        .padding(.vertical, 12)
    }
}

private struct FinancialAlert: Identifiable {
    enum Tone {
        case success
        case warning
        case danger
        case info

        var color: Color {
            switch self {
            case .success: .minervaSuccess
            case .warning: .minervaWarning
            case .danger: .minervaDanger
            case .info: .minervaInfo
            }
        }
    }

    let id = UUID()
    let title: String
    let message: String
    let tone: Tone
    let symbol: String
}

private struct AlertsSheet: View {
    let alerts: [FinancialAlert]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        BrandHeader(title: "MINERVA", subtitle: "Current Alerts")

                        ForEach(alerts) { alert in
                            GlassCard {
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: alert.symbol)
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(alert.tone.color)
                                        .frame(width: 38, height: 38)
                                        .background(Color.minervaPanel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(alert.title)
                                            .font(.headline.weight(.bold))
                                        Text(alert.message)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.minervaSubtext)
                                    }

                                    Spacer()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.minervaOrange)
                }
            }
        }
    }
}

private struct ProfileAvatar: View {
    let imageBase64: String
    let size: CGFloat

    var body: some View {
        Group {
            if let data = Data(base64Encoded: imageBase64),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .foregroundStyle(Color.minervaGreen)
            }
        }
        .frame(width: size, height: size)
        .background(Color.minervaPanel, in: Circle())
        .clipShape(Circle())
    }
}

private struct EditProfileSheet: View {
    @Binding var name: String
    @Binding var email: String
    @Binding var bio: String
    @Binding var imageBase64: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var draftName: String
    @State private var draftEmail: String
    @State private var draftBio: String
    @State private var draftImageBase64: String

    init(name: Binding<String>, email: Binding<String>, bio: Binding<String>, imageBase64: Binding<String>) {
        _name = name
        _email = email
        _bio = bio
        _imageBase64 = imageBase64
        _draftName = State(initialValue: name.wrappedValue)
        _draftEmail = State(initialValue: email.wrappedValue)
        _draftBio = State(initialValue: bio.wrappedValue)
        _draftImageBase64 = State(initialValue: imageBase64.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        BrandHeader(title: "MINERVA", subtitle: "Edit Profile")

                        GlassCard {
                            VStack(alignment: .leading, spacing: 18) {
                                VStack(spacing: 12) {
                                    ProfileAvatar(imageBase64: draftImageBase64, size: 84)

                                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                        Label("Upload Image", systemImage: "photo")
                                            .font(.subheadline.weight(.bold))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color.minervaOrange)
                                }
                                .frame(maxWidth: .infinity)

                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Name")
                                    TextField("Full name", text: $draftName)
                                        .textFieldStyle(MinervaTextFieldStyle())
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Email")
                                    TextField("Email address", text: $draftEmail)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .textFieldStyle(MinervaTextFieldStyle())
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Bio")
                                    TextField("Profile description", text: $draftBio, axis: .vertical)
                                        .lineLimit(2...4)
                                        .textFieldStyle(MinervaTextFieldStyle())
                                }
                            }
                        }

                        Button {
                            saveProfile()
                        } label: {
                            Label("Save Profile", systemImage: "arrow.right")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.minervaOrange)
                        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.minervaSubtext)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task { await loadPhoto(newValue) }
            }
        }
    }

    private func saveProfile() {
        name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        email = draftEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        bio = draftBio.trimmingCharacters(in: .whitespacesAndNewlines)
        imageBase64 = draftImageBase64
        dismiss()
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        draftImageBase64 = data.base64EncodedString()
    }
}

private struct AddExpenseSheet: View {
    let controller: ExpenseController
    let workspace: HenryWorkspace
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategoryId = 1
    @State private var merchant = ""
    @State private var amount = ""
    @State private var note = ""
    @State private var expenseDate = Date()
    @State private var selectedPaymentMethod = "Visa •••• 4242"
    @State private var selectedReceipt: PhotosPickerItem?
    @State private var receiptData: Data?
    @State private var henryStatus = "Snap Receipt"

    private let paymentMethods = [
        "Visa •••• 4242",
        "Checking •••• 1038",
        "Cash",
        "Apple Cash"
    ]

    private var amountValue: Double? {
        Double(amount.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canSave: Bool {
        amountValue != nil &&
        (amountValue ?? 0) > 0 &&
        !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedCategory: Category? {
        controller.categories.first { $0.id == selectedCategoryId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        BrandHeader(title: "MINERVA", subtitle: "Add Expense")

                        GlassCard {
                            VStack(alignment: .leading, spacing: 18) {
                                VStack(spacing: 6) {
                                    Text("AMOUNT")
                                        .font(.caption.weight(.heavy))
                                        .tracking(1.4)
                                        .foregroundStyle(Color.minervaSubtext)
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text("$")
                                            .font(.title.weight(.bold))
                                            .foregroundStyle(Color.minervaSuccess)
                                        TextField("0.00", text: $amount)
                                            .font(.system(size: 44, weight: .bold, design: .rounded))
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.center)
                                    }

                                    Text(selectedCategory?.name ?? "Select a category")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.minervaSubtext)
                                }

                                if workspace.hasLiveSuggestions {
                                    HenryInlineSuggestionCard(
                                        workspace: workspace,
                                        useDraftAction: applyWorkspaceDraft
                                    )
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Category")

                                    LazyVGrid(
                                        columns: [
                                            GridItem(.flexible(), spacing: 10),
                                            GridItem(.flexible(), spacing: 10)
                                        ],
                                        spacing: 10
                                    ) {
                                        ForEach(controller.categories) { category in
                                            CategoryChip(
                                                title: category.name,
                                                isSelected: selectedCategoryId == category.id
                                            ) {
                                                selectedCategoryId = category.id
                                            }
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        FieldLabel("Date")
                                        DatePicker(
                                            "",
                                            selection: $expenseDate,
                                            displayedComponents: [.date]
                                        )
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(14)
                                        .background(Color.minervaPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }

                                    VStack(alignment: .leading, spacing: 10) {
                                        FieldLabel("Payment")
                                        Picker("Payment Method", selection: $selectedPaymentMethod) {
                                            ForEach(paymentMethods, id: \.self) { method in
                                                Text(method).tag(method)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(14)
                                        .background(Color.minervaPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Merchant")
                                    TextField("Where was this purchase?", text: $merchant)
                                        .textFieldStyle(MinervaTextFieldStyle())
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    FieldLabel("Note")
                                    TextField("Optional details for this expense", text: $note, axis: .vertical)
                                        .lineLimit(3...5)
                                        .textFieldStyle(MinervaTextFieldStyle())
                                }
                            }
                        }

                        ReceiptUploadCard(
                            selectedReceipt: $selectedReceipt,
                            receiptData: receiptData,
                            henryStatus: henryStatus
                        )

                        if let errorMessage = controller.errorMessage {
                            InsightBanner(message: errorMessage)
                        }

                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Save to Budget")
                                        .font(.headline.weight(.bold))
                                    Text(canSave ? "This expense will be added to \(selectedCategory?.name ?? "your budget")." : "Enter an amount and merchant to continue.")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.minervaSubtext)
                                }
                                Spacer()
                                Text(amountValue ?? 0, format: .currency(code: "USD"))
                                    .font(.title3.weight(.bold))
                            }
                        }

                        Button {
                            saveExpense()
                        } label: {
                            Label("Add Expense", systemImage: "arrow.right")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.minervaOrange)
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.55)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.minervaSubtext)
                }
            }
            .onAppear {
                selectedCategoryId = controller.categories.first?.id ?? 1
                workspace.refreshCategories(controller.categories)
                workspace.refreshBudgetSignals(controller.summaries)
                applyWorkspaceDraftIfNeeded()
            }
            .onChange(of: selectedReceipt) { _, newValue in
                Task { await loadReceipt(newValue) }
            }
            .onChange(of: merchant) { _, _ in syncWorkspaceDraft() }
            .onChange(of: amount) { _, _ in syncWorkspaceDraft() }
            .onChange(of: note) { _, _ in syncWorkspaceDraft() }
            .onChange(of: selectedCategoryId) { _, _ in syncWorkspaceDraft() }
            .onChange(of: expenseDate) { _, _ in syncWorkspaceDraft() }
        }
        .preferredColorScheme(.dark)
    }

    private func loadReceipt(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        henryStatus = "Henry is reading"

        do {
            receiptData = try await item.loadTransferable(type: Data.self)
            if merchant.isEmpty { merchant = "Receipt Import" }
            if amount.isEmpty { amount = "75.23" }
            if note.isEmpty { note = "Imported from receipt for Henry review" }
            if selectedCategoryId == 1, controller.categories.count > 1 {
                selectedCategoryId = controller.categories[1].id
            }
            syncWorkspaceDraft(receiptAttached: true)
            henryStatus = "Receipt ready for Henry"
        } catch {
            henryStatus = "Receipt could not be read"
        }
    }

    private func saveExpense() {
        guard let amountValue = Double(amount) else {
            controller.errorMessage = "Enter a valid amount."
            return
        }

        controller.addExpense(
            categoryId: selectedCategoryId,
            merchant: merchant,
            amount: amountValue,
            note: buildNote(),
            date: expenseDate
        )
        workspace.clearDraft()
        dismiss()
    }

    private func buildNote() -> String {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateText = expenseDate.formatted(date: .abbreviated, time: .omitted)
        let receiptTag = receiptData == nil ? "" : "Receipt attached. "
        let paymentTag = "Paid with \(selectedPaymentMethod) on \(dateText)."

        if trimmedNote.isEmpty {
            return "\(receiptTag)\(paymentTag)"
        }

        return "\(trimmedNote) \(receiptTag)\(paymentTag)"
    }

    private func syncWorkspaceDraft(receiptAttached: Bool? = nil) {
        workspace.refreshCategories(controller.categories)
        workspace.refreshBudgetSignals(controller.summaries)
        workspace.updateDraft(
            merchant: merchant,
            amountText: amount,
            note: note,
            categoryId: selectedCategoryId,
            date: expenseDate,
            paymentMethod: selectedPaymentMethod,
            receiptAttached: receiptAttached ?? (receiptData != nil)
        )
    }

    private func applyWorkspaceDraft() {
        guard let draft = workspace.draft else { return }
        merchant = draft.merchant
        amount = draft.amountText
        note = draft.note
        selectedCategoryId = draft.categoryId ?? selectedCategoryId
        expenseDate = draft.date
        selectedPaymentMethod = draft.paymentMethod
    }

    private func applyWorkspaceDraftIfNeeded() {
        guard workspace.hasLiveSuggestions else { return }
        applyWorkspaceDraft()
    }
}

private struct ReceiptUploadCard: View {
    @Binding var selectedReceipt: PhotosPickerItem?
    let receiptData: Data?
    let henryStatus: String

    var body: some View {
        PhotosPicker(selection: $selectedReceipt, matching: .images) {
            VStack(spacing: 12) {
                Image(systemName: receiptData == nil ? "camera.viewfinder" : "checkmark.seal.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(receiptData == nil ? Color.minervaSubtext : Color.minervaSuccess)
                    .frame(width: 48, height: 48)
                    .background(Color.minervaPanel, in: Circle())

                Text(henryStatus)
                    .font(.headline.weight(.bold))
                Text(receiptData == nil ? "Upload a receipt for Henry-assisted entry" : "Henry can review this receipt and fill the budget fields")
                    .font(.caption.weight(.semibold))
                    .tracking(0.7)
                    .foregroundStyle(Color.minervaSubtext)
                    .multilineTextAlignment(.center)

                if receiptData != nil {
                    Text("Receipt captured")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.minervaClay)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.minervaPeach, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .background(Color.minervaGlass, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.34), style: StrokeStyle(lineWidth: 1, dash: [7, 6]))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FieldLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.heavy))
            .tracking(1.2)
            .foregroundStyle(Color.minervaSubtext)
    }
}

private struct CategoryChip: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isSelected ? Color.minervaClay : Color.minervaMint300)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selectedTextColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                isSelected ? Color.minervaMint200 : Color.minervaPanel,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.minervaMint300 : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedTextColor: Color {
        guard isSelected else { return Color.minervaSubtext }
        return colorScheme == .dark ? .black : Color.minervaText
    }
}

private struct MinervaTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.headline.weight(.semibold))
            .padding(14)
            .background(Color.minervaPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}

private struct HenryInlineSuggestionCard: View {
    let workspace: HenryWorkspace
    let useDraftAction: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    HenryMark()
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Henry Suggestion")
                            .font(.headline.weight(.bold))
                        Text(workspace.primaryStatusLine)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.minervaSubtext)
                    }
                    Spacer()
                    Button("Apply", action: useDraftAction)
                        .font(.caption.weight(.bold))
                        .buttonStyle(.borderedProminent)
                        .tint(Color.minervaOrange)
                }

                if let suggestedCategory = workspace.suggestedCategory {
                    Text("Category: \(suggestedCategory.name)")
                        .font(.subheadline.weight(.semibold))
                }

                if let draft = workspace.draft, let amount = Double(draft.amountText) {
                    Text(amount, format: .currency(code: "USD"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.minervaSuccess)
                }
            }
        }
    }
}

@Observable
private final class HenryWorkspace {
    struct Draft {
        var merchant: String
        var amountText: String
        var note: String
        var categoryId: Int?
        var date: Date
        var paymentMethod: String
        var receiptAttached: Bool
    }

    enum Tone {
        case success
        case warning
        case danger
        case info

        var color: Color {
            switch self {
            case .success: .minervaSuccess
            case .warning: .minervaWarning
            case .danger: .minervaDanger
            case .info: .minervaInfo
            }
        }
    }

    private(set) var categories: [Category] = []
    private(set) var summaries: [BudgetSummary] = []
    var draft: Draft?

    var hasLiveSuggestions: Bool {
        draft?.receiptAttached == true || suggestedCategory != nil || budgetWarningLine != nil
    }

    var suggestedCategory: Category? {
        if let explicitId = draft?.categoryId, let category = categories.first(where: { $0.id == explicitId }) {
            return category
        }

        guard let merchant = draft?.merchant.lowercased(), !merchant.isEmpty else { return nil }
        let matchedName = merchantCategoryMap.first { merchant.contains($0.0) }?.1
        return categories.first(where: { normalize($0.name).contains(normalize(matchedName ?? "")) })
    }

    var categoryReason: String {
        guard let draft else { return "No pattern detected yet." }
        if draft.receiptAttached { return "receipt pattern + merchant match" }
        if !draft.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "merchant + note pattern" }
        return "merchant pattern"
    }

    var primaryStatusLine: String {
        if let draft, draft.receiptAttached {
            return "Receipt import is ready to review."
        }
        if suggestedCategory != nil {
            return "A category suggestion is ready."
        }
        if let budgetWarningLine {
            return budgetWarningLine
        }
        return "Henry is watching for receipt and budget patterns."
    }

    var receiptSummaryLine: String {
        guard let draft else { return "No receipt attached yet." }
        let merchantLine = draft.merchant.isEmpty ? "merchant pending" : draft.merchant
        let amountLine = draft.amountText.isEmpty ? "$0.00" : draft.amountText
        return "\(merchantLine) • $\(amountLine)"
    }

    var budgetWarningLine: String? {
        summaries
            .sorted { $0.percentUsed > $1.percentUsed }
            .first(where: { $0.percentUsed >= 0.8 })
            .map { summary in
                let state: String
                if summary.remaining < 0 {
                    state = "over budget"
                } else if summary.remaining == 0 {
                    state = "on target"
                } else {
                    state = "close to its limit"
                }
                return "\(summary.category.name) is \(state)."
            }
    }

    var recommendedPrompts: [String] {
        var prompts: [String] = []
        if draft?.receiptAttached == true {
            prompts.append("Apply the receipt draft, then verify the merchant and amount.")
        }
        if let suggestedCategory {
            prompts.append("Use \(suggestedCategory.name) as the default category for this draft.")
        }
        if let budgetWarningLine {
            prompts.append(budgetWarningLine)
        }
        if prompts.isEmpty {
            prompts.append("Snap a receipt or start a draft in Add Expense to get live suggestions.")
        }
        return prompts
    }

    func refreshCategories(_ categories: [Category]) {
        self.categories = categories
    }

    func refreshBudgetSignals(_ summaries: [BudgetSummary]) {
        self.summaries = summaries
    }

    func updateDraft(
        merchant: String,
        amountText: String,
        note: String,
        categoryId: Int?,
        date: Date,
        paymentMethod: String,
        receiptAttached: Bool
    ) {
        draft = Draft(
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            amountText: amountText.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryId: categoryId ?? inferCategoryId(from: merchant + " " + note),
            date: date,
            paymentMethod: paymentMethod,
            receiptAttached: receiptAttached
        )
    }

    func clearDraft() {
        draft = nil
    }

    private func inferCategoryId(from text: String) -> Int? {
        let lowered = text.lowercased()
        guard let categoryName = merchantCategoryMap.first(where: { lowered.contains($0.0) })?.1 else {
            return nil
        }
        return categories.first(where: { normalize($0.name).contains(normalize(categoryName)) })?.id
    }

    private func normalize(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "&", with: "and")
    }

    private let merchantCategoryMap: [(String, String)] = [
        ("costco", "Groceries"),
        ("smiths", "Groceries"),
        ("trader joe", "Groceries"),
        ("walmart", "Groceries"),
        ("target", "Groceries"),
        ("harmons", "Groceries"),
        ("whole foods", "Groceries"),
        ("zupas", "Dining"),
        ("aubergine", "Dining"),
        ("coffee", "Dining"),
        ("cafe", "Dining"),
        ("uber", "Transportation"),
        ("uta", "Transportation"),
        ("delta", "Transportation"),
        ("chevron", "Transportation"),
        ("gas", "Transportation"),
        ("rent", "Rent"),
        ("dominion", "Utilities"),
        ("utilities", "Utilities"),
        ("electric", "Utilities"),
        ("uvu", "School"),
        ("bookstore", "School"),
        ("tuition", "School"),
        ("credit union", "Savings"),
        ("savings", "Savings")
    ]
}

private struct HenryInsightCard: View {
    let title: String
    let subtitle: String
    let tone: HenryWorkspace.Tone
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline.weight(.bold))
                Spacer()
                Circle()
                    .fill(tone.color)
                    .frame(width: 10, height: 10)
            }

            Text(subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.minervaSubtext)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.bold))
                    .buttonStyle(.borderedProminent)
                    .tint(tone.color)
            }
        }
        .padding(16)
        .background(Color.minervaPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tone.color.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct HenryMark: View {
    var body: some View {
        Image("henry-icon")
            .resizable()
            .scaledToFit()
            .padding(4)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

private struct BudgetHeroCard: View {
    let controller: ExpenseController
    let alertAction: () -> Void

    var progress: Double {
        guard controller.totalLimit > 0 else { return 0 }
        return min(controller.totalSpent / controller.totalLimit, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Monthly Budget Remaining")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                    Text(controller.totalRemaining, format: .currency(code: "USD"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button(action: alertAction) {
                    Image(systemName: "bell.badge.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(10)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progress)
                    .tint(.white)
                    .background(.white.opacity(0.2), in: Capsule())

                HStack {
                    Text("Spent: \(controller.totalSpent, format: .currency(code: "USD"))")
                    Spacer()
                    Text("Goal: \(controller.totalLimit, format: .currency(code: "USD"))")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.82), Color.minervaForest.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.32), radius: 20, y: 12)
    }
}

private struct SpendingRingView: View {
    let summaries: [BudgetSummary]
    var palette: BudgetPalette = .earth

    private var total: Double {
        summaries.reduce(0) { $0 + $1.spent }
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerRadius = (min(size.width, size.height) / 2) - 2
            let ringThickness = min(size.width, size.height) * 0.16
            let innerRadius = outerRadius - ringThickness

            var track = Path()
            track.addArc(center: center, radius: outerRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            track.addArc(center: center, radius: innerRadius, startAngle: .degrees(360), endAngle: .degrees(0), clockwise: true)
            track.closeSubpath()
            context.fill(track, with: .color(Color.minervaChartTrack))

            var startAngle = Angle.degrees(-90)
            for summary in summaries {
                let share = total == 0 ? 0 : summary.spent / total
                let sweep = Angle.degrees(share * 360)
                guard sweep.degrees > 0.5 else { continue }

                let gap = min(Angle.degrees(4), sweep * 0.22)
                let segmentStart = startAngle + gap / 2
                let segmentEnd = startAngle + sweep - gap / 2
                guard segmentEnd > segmentStart else {
                    startAngle += sweep
                    continue
                }

                var path = Path()
                path.addArc(center: center, radius: outerRadius, startAngle: segmentStart, endAngle: segmentEnd, clockwise: false)
                path.addArc(center: center, radius: innerRadius, startAngle: segmentEnd, endAngle: segmentStart, clockwise: true)
                path.closeSubpath()
                context.fill(path, with: .color(color(for: summary.category.id, palette: palette)))
                startAngle += sweep
            }
        }
        .overlay {
            VStack(spacing: 2) {
                Text("\(summaries.count)")
                    .font(.title2.weight(.bold))
                Text("CATEGORIES")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.minervaSubtext)
            }
        }
    }
}

private struct SpendingBarChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let summaries: [BudgetSummary]
    var palette: BudgetPalette = .earth

    var body: some View {
        Canvas { context, size in
            let maxSpent = summaries.map(\.spent).max() ?? 1
            let spacing: CGFloat = 10
            let barWidth = max(10, (size.width - spacing * CGFloat(max(summaries.count - 1, 0))) / CGFloat(max(summaries.count, 1)))

            for index in summaries.indices {
                let summary = summaries[index]
                let x = CGFloat(index) * (barWidth + spacing)
                let trackRect = CGRect(x: x, y: 0, width: barWidth, height: size.height)
                let trackPath = Path(roundedRect: trackRect, cornerRadius: 7)
                context.fill(trackPath, with: .color(trackColor))
                context.stroke(trackPath, with: .color(trackBorderColor), style: StrokeStyle(lineWidth: 1))

                let height = size.height * CGFloat(summary.spent / maxSpent)
                let rect = CGRect(x: x, y: size.height - height, width: barWidth, height: height)
                let path = Path(roundedRect: rect, cornerRadius: 7)
                context.fill(path, with: .color(color(for: summary.category.id, palette: palette)))
                context.stroke(path, with: .color(barBorderColor), style: StrokeStyle(lineWidth: 1))
            }
        }
    }

    private var trackColor: Color {
        colorScheme == .dark
            ? Color.minervaChartTrack
            : Color.black.opacity(0.10)
    }

    private var trackBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.12)
    }

    private var barBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.10)
    }
}

private struct SpendingLineChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let expenses: [Expense]
    let budgetLimit: Double
    var palette: BudgetPalette = .earth

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly spending pace")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.minervaText)
                    Text(statusLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.minervaSubtext)
                }
                Spacer()
                Text(budgetLimit, format: .currency(code: "USD"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.minervaSubtext)
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(chartMaxValue, format: .currency(code: "USD"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.minervaSubtext)
                        .frame(height: 18, alignment: .top)
                    Spacer()
                    Text(chartMaxValue / 2, format: .currency(code: "USD"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.minervaSubtext)
                        .frame(height: 18, alignment: .center)
                    Spacer()
                    Text("$0")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.minervaSubtext)
                        .frame(height: 18, alignment: .bottom)
                }
                .frame(width: 52, height: 160, alignment: .leading)

                GeometryReader { geometry in
                    let horizontalInset: CGFloat = 16
                    let plotWidth = max(geometry.size.width - (horizontalInset * 2), 1)
                    let plotHeight = max(geometry.size.height - 24, 1)
                    let actualPoints = actualSeries.map { point in
                        CGPoint(
                            x: horizontalInset + xPosition(index: point.day - 1, count: totalPlotCount, width: plotWidth),
                            y: yPosition(for: point.value, plotHeight: plotHeight)
                        )
                    }
                    let idealPoints = idealSeries.map { point in
                        CGPoint(
                            x: horizontalInset + xPosition(index: point.day - 1, count: totalPlotCount, width: plotWidth),
                            y: yPosition(for: point.value, plotHeight: plotHeight)
                        )
                    }
                    let projectionPoints = projectionSeries.map { point in
                        CGPoint(
                            x: horizontalInset + xPosition(index: point.day - 1, count: totalPlotCount, width: plotWidth),
                            y: yPosition(for: point.value, plotHeight: plotHeight)
                        )
                    }

                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(chartBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(chartBorder, lineWidth: 1)
                            )

                        Canvas { context, size in
                            let guideValues: [CGFloat] = [0, 0.5, 1]
                            for value in guideValues {
                                let y = 8 + plotHeight - (plotHeight * value)
                                var guide = Path()
                                guide.move(to: CGPoint(x: horizontalInset, y: y))
                                guide.addLine(to: CGPoint(x: horizontalInset + plotWidth, y: y))
                                context.stroke(
                                    guide,
                                    with: .color(gridLineColor),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                                )
                            }

                            var goalLine = Path()
                            let goalY = yPosition(for: budgetLimit, plotHeight: plotHeight)
                            goalLine.move(to: CGPoint(x: horizontalInset, y: goalY))
                            goalLine.addLine(to: CGPoint(x: horizontalInset + plotWidth, y: goalY))
                            context.stroke(
                                goalLine,
                                with: .color(Color.minervaSubtext.opacity(0.7)),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                            )

                            if idealPoints.count > 1 {
                                var idealLine = Path()
                                idealLine.move(to: idealPoints[0])
                                for point in idealPoints.dropFirst() {
                                    idealLine.addLine(to: point)
                                }
                                context.stroke(
                                    idealLine,
                                    with: .color(Color.white.opacity(0.9)),
                                    style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                                )
                            }

                            guard actualPoints.count > 1 else { return }

                            var area = Path()
                            area.move(to: CGPoint(x: actualPoints[0].x, y: 8 + plotHeight))
                            for point in actualPoints {
                                area.addLine(to: point)
                            }
                            area.addLine(to: CGPoint(x: actualPoints.last?.x ?? horizontalInset, y: 8 + plotHeight))
                            area.closeSubpath()
                            context.fill(
                                area,
                                with: .linearGradient(
                                    Gradient(colors: [palette.colors[0].opacity(0.22), .clear]),
                                    startPoint: CGPoint(x: 0, y: 0),
                                    endPoint: CGPoint(x: 0, y: size.height)
                                )
                            )

                            var line = Path()
                            line.move(to: actualPoints[0])
                            for point in actualPoints.dropFirst() {
                                line.addLine(to: point)
                            }
                            context.stroke(
                                line,
                                with: .linearGradient(
                                    Gradient(colors: palette.colors.prefix(3).map { $0 }),
                                    startPoint: CGPoint(x: horizontalInset, y: 0),
                                    endPoint: CGPoint(x: horizontalInset + plotWidth, y: size.height)
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                            )

                            if projectionPoints.count > 1 {
                                var projectionLine = Path()
                                projectionLine.move(to: actualPoints.last ?? projectionPoints[0])
                                for point in projectionPoints {
                                    projectionLine.addLine(to: point)
                                }
                                context.stroke(
                                    projectionLine,
                                    with: .color(Color.minervaDanger.opacity(0.8)),
                                    style: StrokeStyle(lineWidth: 2.5, dash: [4, 4])
                                )
                            }

                            for (index, point) in actualPoints.enumerated() {
                                let markerRect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                                let marker = Path(ellipseIn: markerRect)
                                context.fill(marker, with: .color(index == actualPoints.count - 1 ? palette.colors[1] : palette.colors[0]))
                                context.stroke(marker, with: .color(markerBorderColor), style: StrokeStyle(lineWidth: 2))
                            }
                        }
                    }
                }
                .frame(height: 160)
            }

            HStack(alignment: .top, spacing: 8) {
                legendItem(color: palette.colors[0], title: "Actual")
                legendItem(color: Color.minervaMint400, title: "Ideal")
                legendItem(color: Color.minervaSubtext, title: "Budget")
                if projectedOverspend > 0 {
                    legendItem(color: Color.minervaDanger, title: "Projected")
                }
                Spacer()
            }

            HStack {
                Text(monthStartLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.minervaSubtext)
                Spacer()
                Text(midMonthLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.minervaSubtext)
                Spacer()
                Text(monthEndLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.minervaSubtext)
            }
        }
    }

    private var monthExpenses: [Expense] {
        let calendar = Calendar.current
        guard let latestDate = expenses.map(\.date).max(),
              let monthInterval = calendar.dateInterval(of: .month, for: latestDate)
        else {
            return []
        }
        return expenses
            .filter { monthInterval.contains($0.date) }
            .sorted { $0.date < $1.date }
    }

    private var monthInterval: DateInterval? {
        guard let latestDate = expenses.map(\.date).max() else { return nil }
        return Calendar.current.dateInterval(of: .month, for: latestDate)
    }

    private var daysInMonth: Int {
        guard let interval = monthInterval else { return 30 }
        return Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day ?? 30
    }

    private var actualSeries: [ChartPoint] {
        guard let interval = monthInterval else {
            return [ChartPoint(day: 1, value: 0), ChartPoint(day: 2, value: 0)]
        }

        let calendar = Calendar.current
        var runningTotal = 0.0
        var series: [ChartPoint] = []
        let lastDay = latestExpenseDay

        for day in 1...lastDay {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: interval.start) else { continue }
            let spentForDay = monthExpenses
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.amount }
            runningTotal += spentForDay
            series.append(ChartPoint(day: day, value: runningTotal))
        }

        return series
    }

    private var idealSeries: [ChartPoint] {
        guard daysInMonth > 1 else { return [ChartPoint(day: 1, value: 0)] }
        return (1...daysInMonth).map { day in
            let progress = Double(day - 1) / Double(daysInMonth - 1)
            return ChartPoint(day: day, value: budgetLimit * progress)
        }
    }

    private var projectionSeries: [ChartPoint] {
        guard let lastActual = actualSeries.last, daysInMonth > 0 else { return [] }
        let daysElapsed = max(lastActual.day, 1)
        let dailyAverage = lastActual.value / Double(daysElapsed)
        guard daysElapsed < daysInMonth else { return [] }

        return ((daysElapsed + 1)...daysInMonth).map { day in
            ChartPoint(day: day, value: dailyAverage * Double(day))
        }
    }

    private var chartMaxValue: Double {
        max(
            budgetLimit,
            actualSeries.map(\.value).max() ?? 0,
            projectionSeries.map(\.value).max() ?? 0,
            1
        ) * 1.08
    }

    private var projectedOverspend: Double {
        max((projectionSeries.last?.value ?? actualSeries.last?.value ?? 0) - budgetLimit, 0)
    }

    private var latestExpenseDay: Int {
        guard let latestDate = monthExpenses.map(\.date).max() else { return 1 }
        return Calendar.current.component(.day, from: latestDate)
    }

    private var totalPlotCount: Int {
        max(daysInMonth, 2)
    }

    private var statusLine: String {
        let currentActual = actualSeries.last?.value ?? 0
        let currentIdeal = idealSeries.last?.value ?? budgetLimit
        if currentActual <= currentIdeal {
            return "You are pacing under budget this month."
        }
        return "You are spending faster than your monthly plan."
    }

    private var monthStartLabel: String {
        label(forDay: 1)
    }

    private var midMonthLabel: String {
        label(forDay: max(daysInMonth / 2, 1))
    }

    private var monthEndLabel: String {
        label(forDay: daysInMonth)
    }

    private var chartBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }

    private var chartBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.black.opacity(0.10)
    }

    private var gridLineColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.black.opacity(0.14)
    }

    private var markerBorderColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.48)
            : Color.white.opacity(0.92)
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.minervaSubtext)
        }
    }

    private func label(forDay day: Int) -> String {
        guard let interval = monthInterval,
              let date = Calendar.current.date(byAdding: .day, value: max(day - 1, 0), to: interval.start)
        else {
            return "Day \(day)"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func yPosition(for value: Double, plotHeight: CGFloat) -> CGFloat {
        8 + plotHeight - (plotHeight * CGFloat(value / chartMaxValue))
    }

    private func xPosition(index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width / 2 }
        let inset: CGFloat = 16
        let usableWidth = width - (inset * 2)
        return inset + (usableWidth / CGFloat(count - 1)) * CGFloat(index)
    }
}

private struct ChartPoint {
    let day: Int
    let value: Double
}

private struct GlassTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: AppTab
    @Binding var showingAddExpense: Bool

    var body: some View {
        HStack(spacing: 4) {
            tabButton(.home)
            tabButton(.history)

            Button {
                showingAddExpense = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .heavy))
                    Text("Add")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Color.minervaOrange, in: Circle())
                .shadow(color: Color.minervaOrange.opacity(0.45), radius: 12, y: 6)
            }
            .buttonStyle(.plain)

            tabButton(.budget)
            tabButton(.insights)
        }
        .padding(8)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(height: 92)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.14), radius: 18, y: 10)

                Capsule()
                    .fill(Color.minervaTabGlass)

                Capsule()
                    .fill(.ultraThinMaterial)

                Capsule()
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.38), radius: 22, y: 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                if tab.usesAssetIcon {
                    Image(tab.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .scaleEffect(1.08)
                        .clipShape(Circle())
                } else {
                    Image(systemName: tab.icon)
                        .font(.system(size: 17, weight: .bold))
                }
                Text(tab.rawValue)
                    .font(.system(size: 8, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selectedTab == tab ? selectedForeground : Color.minervaSubtext)
            .padding(.vertical, 9)
            .background(
                selectedTab == tab ? selectedBackground : Color.clear,
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(selectedTab == tab ? selectedBorder : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedForeground: Color {
        colorScheme == .dark ? Color.minervaBrand : .white
    }

    private var selectedBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : .black
    }

    private var selectedBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.28) : Color.clear
    }
}

private struct BrandHeader: View {
    let title: String
    let subtitle: String
    var moreAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 43, weight: .light, design: .serif))
                .tracking(8)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(Color.minervaBrand)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Text(subtitle)
                    .font(.headline.weight(.bold))
                    .tracking(1.2)
                Spacer()
                if let moreAction {
                    Button(action: moreAction) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.minervaText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.minervaHeaderGlass, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.34), lineWidth: 1)
            )
        }
    }
}

private struct PinnedBrandHeader: View {
    let title: String
    let subtitle: String
    var moreAction: (() -> Void)? = nil

    var body: some View {
        BrandHeader(title: title, subtitle: subtitle, moreAction: moreAction)
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.minervaGlass.opacity(0.55))
                    .ignoresSafeArea(edges: .top)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.8)
            }
    }
}

private struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.minervaGlass, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.34), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
    }
}

private struct SectionTitle: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline.weight(.bold))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.minervaOrange)
            }
        }
    }
}

private struct CategoryAmountRow: View {
    let summary: BudgetSummary
    var palette: BudgetPalette = .earth

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(color(for: summary.category.id, palette: palette))
                .frame(width: 8, height: 8)
            Text(summary.category.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(Color.minervaText)
            Spacer()
            Text(summary.spent, format: .currency(code: "USD"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.minervaText)
        }
    }
}

private struct BudgetProgressRow: View {
    let summary: BudgetSummary
    var palette: BudgetPalette = .earth

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color(for: summary.category.id, palette: palette))
                        .frame(width: 10, height: 10)
                    Text(summary.category.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.minervaText)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 8) {
                    Text("\(summary.spent, format: .currency(code: "USD")) of \(summary.category.monthlyLimit, format: .currency(code: "USD"))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.minervaSubtext)
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                            .font(.caption.weight(.bold))
                        Text("Edit")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Color.minervaOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.minervaPanel, in: Capsule())
                }
            }

            HStack {
                Text(statusTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12), in: Capsule())
                Spacer()
                Text(remainingText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.minervaSubtext)
            }

            ProgressView(value: summary.percentUsed)
                .tint(summary.remaining >= 0 ? color(for: summary.category.id, palette: palette) : Color.minervaDanger)
        }
        .padding(.vertical, 6)
    }

    private var statusTitle: String {
        if summary.remaining < 0 { return "Over Budget" }
        if summary.remaining == 0 { return "On Target" }
        if summary.percentUsed >= 0.9 { return "Near Limit" }
        return "Under Budget"
    }

    private var statusColor: Color {
        if summary.remaining < 0 { return .minervaDanger }
        if summary.remaining == 0 { return .minervaInfo }
        if summary.percentUsed >= 0.9 { return .minervaWarning }
        return .minervaSuccess
    }

    private var remainingText: String {
        if summary.remaining > 0 {
            return "\(summary.remaining.formatted(.currency(code: "USD"))) left"
        }
        if summary.remaining == 0 {
            return "At budget limit"
        }
        return "\(abs(summary.remaining).formatted(.currency(code: "USD"))) over"
    }
}

private struct ExpenseRow: View {
    let expense: Expense
    let categoryName: String

    var body: some View {
        HStack(spacing: 12) {
            MerchantIcon(name: expense.merchant)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant)
                    .font(.subheadline.weight(.bold))
                Text(categoryName)
                    .font(.caption)
                    .foregroundStyle(Color.minervaSubtext)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amount, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.minervaDanger)
                Text(expense.date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(Color.minervaSubtext)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct RemoteExpenseRow: View {
    let expense: RemoteExpense

    var body: some View {
        HStack(spacing: 12) {
            MerchantIcon(name: expense.merchant)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant)
                    .font(.subheadline.weight(.bold))
                Text(expense.category)
                    .font(.caption)
                    .foregroundStyle(Color.minervaSubtext)
            }
            Spacer()
            Text(expense.amount, format: .currency(code: "USD"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.minervaClay)
        }
        .padding(.vertical, 6)
    }
}

private struct MerchantIcon: View {
    let name: String

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(Color.minervaGreen.gradient, in: Circle())
    }
}

private struct FilterChip: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Color.minervaSubtext)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? selectedBackground : Color.minervaPanel, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var selectedBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.24) : Color.black.opacity(0.82)
    }
}

private struct InsightBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.minervaGreen)
                .padding(10)
                .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(message)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(16)
        .background(Color.minervaGlass, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
        )
    }
}

private struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title)
                .foregroundStyle(Color.minervaSubtext)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.minervaSubtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Color.minervaGreen)
                .frame(width: 34, height: 34)
                .background(Color.minervaMint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.minervaSubtext)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.minervaSubtext)
        }
        .padding(.vertical, 12)
    }
}

extension AppTab: Identifiable {
    var id: String { rawValue }
}

#Preview {
    ContentView()
}
