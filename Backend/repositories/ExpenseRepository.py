
from datetime import datetime
from typing import List
from models.Expense import Expense
from models.Category import Category
from models.Budget import Budget
from models.SavingsGoal import SavingsGoal

class ExpenseRepository:
    """
    This class manages all data for the Minerva app including expenses, categories, budgets, and savings goals.
    """
    def __init__(self):
        self._expenses: List[Expense] = []
        self._categories: List[Category] = []
        self._budgets: List[Budget] = []
        self._savings_goals: List[SavingsGoal] = []

    @property
    def expenses(self) -> List[Expense]:
        return self._expenses

    @expenses.setter
    def expenses(self, value: List[Expense]):
        self._expenses = value

    @property
    def categories(self) -> List[Category]:
        return self._categories

    @categories.setter
    def categories(self, value: List[Category]):
        self._categories = value

    @property
    def budgets(self) -> List[Budget]:
        return self._budgets

    @budgets.setter
    def budgets(self, value: List[Budget]):
        self._budgets = value

    @property
    def savings_goals(self) -> List[SavingsGoal]:
        return self._savings_goals

    @savings_goals.setter
    def savings_goals(self, value: List[SavingsGoal]):
        self._savings_goals = value

    def validate_expense(self, expense: Expense) -> bool:
        """
        Validates that the expense has valid data.
        """
        return expense is not None and expense.amount > 0 and expense.date != datetime.min

    def add_expense(self, expense: Expense):
        """
        Adds a new expense to the repository if it is valid.
        """
        if self.validate_expense(expense):
            self._expenses.append(expense)

    def get_all_expenses(self) -> List[Expense]:
        """
        Returns all expenses in the repository.
        """
        return self._expenses

    def add_category(self, category: Category):
        """
        Adds a new category to the repository.
        """
        self._categories.append(category)

    def get_all_categories(self) -> List[Category]:
        """
        Returns all categories in the repository.
        """
        return self._categories

    def add_budget(self, budget: Budget):
        """
        Adds a new budget to the repository.
        """
        self._budgets.append(budget)

    def get_all_budgets(self) -> List[Budget]:
        """
        Returns all budgets in the repository.
        """
        return self._budgets

    def add_savings_goal(self, savings_goal: SavingsGoal):
        """
        Adds a new savings goal to the repository.
        """
        self._savings_goals.append(savings_goal)

    def get_all_savings_goals(self) -> List[SavingsGoal]:
        """
        Returns all savings goals in the repository.
        """
        return self._savings_goals

    def save(self):
        """
        Saves the repository data to a file or database (not implemented).
        """
        pass

    def load(self):
        """
        Loads the repository data from a file or database (not implemented).
        """
        pass

    def __str__(self) -> str:
        """
        Returns a summary of the repository contents.
        """
        return f"Expenses: {len(self._expenses)}, Categories: {len(self._categories)}, Budgets: {len(self._budgets)}, Goals: {len(self._savings_goals)}"