
class Category:
    """
    This class models a category with an ID, name, and icon name for use in the budgeting app.
    """
    def __init__(self, id: int = 0, name: str = "", icon_name: str = ""):
        self._id = id
        self._name = name
        self._icon_name = icon_name

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
    def icon_name(self) -> str:
        return self._icon_name

    @icon_name.setter
    def icon_name(self, value: str):
        self._icon_name = value

    def __str__(self) -> str:
        """
        Returns a string representation of the category, which is its name.
        """
        return self._name