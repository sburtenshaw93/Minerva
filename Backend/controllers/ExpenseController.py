
from typing import List
from repositories.ExpenseRepository import ExpenseRepository
from models.Expense import Expense

class ExpenseController:
    """
    This class serves as the controller for managing expenses, allowing for adding and retrieving expense records.
    """
    def __init__(self, repository: ExpenseRepository = None):
        self._repository = repository if repository else ExpenseRepository()

    def add_expense(self, expense: Expense):
        """
        Adds a new expense by delegating to the repository.
        """
        self._repository.add_expense(expense)

    def get_all_expenses(self) -> List[Expense]:
        """
        Retrieves all expenses from the repository.
        """
        return self._repository.get_all_expenses()

    @property
    def repository(self) -> ExpenseRepository:
        """
        Gets or sets the repository used by this controller.
        """
        return self._repository

    @repository.setter
    def repository(self, value: ExpenseRepository):
        self._repository = value

    def __str__(self) -> str:
        """
        Returns a string representation of the controller.
        """
        return "ExpenseController for Minerva"
    
    