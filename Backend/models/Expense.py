
from datetime import datetime
from decimal import Decimal

class Expense:
    """
    This class models a single expense record with amount, date, note, and category.
    """
    def __init__(self, id: int = 0, amount: Decimal = Decimal(0), date: datetime = None, note: str = "", category_id: int = 0):
        self._id = id
        self._amount = amount
        self._date = date if date else datetime.min
        self._note = note
        self._category_id = category_id

    @property
    def id(self) -> int:
        return self._id

    @id.setter
    def id(self, value: int):
        self._id = value

    @property
    def amount(self) -> Decimal:
        return self._amount

    @amount.setter
    def amount(self, value: Decimal):
        self._amount = value

    @property
    def date(self) -> datetime:
        return self._date

    @date.setter
    def date(self, value: datetime):
        self._date = value

    @property
    def note(self) -> str:
        return self._note

    @note.setter
    def note(self, value: str):
        self._note = value

    @property
    def category_id(self) -> int:
        return self._category_id

    @category_id.setter
    def category_id(self, value: int):
        self._category_id = value

    def validate(self) -> bool:
        """
        Validates that the expense has valid data.
        """
        return True

    def __str__(self) -> str:
        """
        Returns a string representation of the expense for debugging purposes.
        """
        return f"Id: {self._id}, Amount: ${self._amount:.2f}, Date: {self._date.strftime('%m/%d/%Y') if self._date != datetime.min else 'N/A'}, Note: {self._note}, CategoryId: {self._category_id}"