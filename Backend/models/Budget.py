
from decimal import Decimal

class Budget:
    """
    This class models a budget record with category, amount, and date.
    """
    def __init__(self, id: int = 0, category: str = "", amount: Decimal = Decimal(0), monthly_limit: Decimal = Decimal(0)):
        self._id = id
        self._category = category
        self._amount = amount
        self._monthly_limit = monthly_limit

    @property
    def id(self) -> int:
        return self._id

    @id.setter
    def id(self, value: int):
        self._id = value

    @property
    def category(self) -> str:
        return self._category

    @category.setter
    def category(self, value: str):
        self._category = value

    @property
    def amount(self) -> Decimal:
        return self._amount

    @amount.setter
    def amount(self, value: Decimal):
        self._amount = value

    @property
    def monthly_limit(self) -> Decimal:
        return self._monthly_limit

    @monthly_limit.setter
    def monthly_limit(self, value: Decimal):
        self._monthly_limit = value

    def __str__(self) -> str:
        return f"{self._category}: ${self._amount:.2f} / ${self._monthly_limit:.2f}"

    def remaining(self) -> Decimal:
        """
        Calculates and displays the remaining budget for the category based on the monthly limit and current amount.
        """
        remaining = self._monthly_limit - self._amount
        return remaining

    def is_over_budget(self) -> bool:
        """
        Determines if the current amount exceeds the monthly limit for the budget category.
        """
        return self._amount > self._monthly_limit