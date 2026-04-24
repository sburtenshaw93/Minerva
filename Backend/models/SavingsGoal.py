
from decimal import Decimal

class SavingsGoal:
    """
    This class models a savings goal with a name, target amount, and current amount.
    """
    def __init__(self, id: int = 0, name: str = "", target_amount: Decimal = Decimal(0), current_amount: Decimal = Decimal(0)):
        self._id = id
        self._name = name
        self._target_amount = target_amount
        self._current_amount = current_amount

    @property
    def id(self) -> int:
        return self._id

    @id.setter
    def id(self, value: int):
        self._id = value

    @property
    def name(self) -> str:
        return self._name

    @name.setter
    def name(self, value: str):
        self._name = value

    @property
    def target_amount(self) -> Decimal:
        return self._target_amount

    @target_amount.setter
    def target_amount(self, value: Decimal):
        self._target_amount = value

    @property
    def current_amount(self) -> Decimal:
        return self._current_amount

    @current_amount.setter
    def current_amount(self, value: Decimal):
        self._current_amount = value

    def progress(self) -> Decimal:
        """
        Returns the progress toward the goal as a decimal between 0 and 1.
        """
        if self._target_amount == 0:
            return Decimal(0)
        return self._current_amount / self._target_amount

    def add_amount(self, amount: Decimal):
        """
        Adds an amount toward the savings goal.
        """
        self._current_amount += amount

    def __str__(self) -> str:
        """
        Returns a string summary of the savings goal.
        """
        return f"{self._name}: ${self._current_amount:.2f} / ${self._target_amount:.2f}"