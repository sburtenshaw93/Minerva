import sqlite3

from models.Expense import Expense
from models.Budget import Budget
from models.Category import Category
from models.SavingsGoal import SavingsGoal
from datetime import datetime

def initialize_db():
    conn = sqlite3.connect("minerva.db")
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT,
            category_id INTEGER
        )
    """)
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS category (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            icon_name TEXT        
        )
    """)
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS budget (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            monthly_limit REAL NOT NULL,
            category TEXT
        )
    """)
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS savings_goal (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            target_amount REAL NOT NULL,
            current_amount REAL NOT NULL         
        )
    """)
    
    conn.commit()
    conn.close()

def add_expense(expense):
    conn = sqlite3.connect("minerva.db")
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO expenses (amount, date, note, category_id)
        VALUES (?, ?, ?, ?)
    """, (expense.amount, expense.date.strftime("%Y-%m-%d"), expense.note, expense.category_id))
    conn.commit()
    conn.close()

def get_all_expenses():
    conn = sqlite3.connect("minerva.db")
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM expenses")
    rows = cursor.fetchall()
    conn.close()
    return rows

def add_category(category):
    conn = sqlite3.connect("minerva.db")
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO category (name, icon_name)
        VALUES (?, ?)
    """, (category.name, category.icon_name))
    conn.commit()
    conn.close()

def get_all_categories():
    conn = sqlite3.connect("minerva.db")
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM category")
    rows = cursor.fetchall()
    conn.close()
    return rows

def add_budget(budget):
    conn = sqlite3.connect("minerva.db")
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO budget (amount, monthly_limit, category)
        VALUES (?, ?, ?)
    """, (budget.amount, budget.monthly_limit, budget.category))
    conn.commit()
    conn.close()

def get_all_budgets():
    conn = sqlite3.connect("minerva.db")
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM budget")
    rows = cursor.fetchall()
    conn.close()
    return rows

def add_savings_goal(goal):
    conn = sqlite3.connect("minerva.db")
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO savings_goal (name, target_amount, current_amount)
        VALUES (?, ?, ?)
    """, (goal.name, goal.target_amount, goal.current_amount))
    conn.commit()
    conn.close()

def get_all_savings_goals():
    conn = sqlite3.connect("minerva.db")
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM savings_goal")
    rows = cursor.fetchall()
    conn.close()
    return rows

def seed_data():
    conn = sqlite3.connect("minerva.db")
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM category")
    count = cursor.fetchone()[0]
    conn.close() 
    
    if count > 0:
        return 
    
    add_category(Category(name="Groceries", icon_name="cart.fill"))
    add_category(Category(name="Transportation", icon_name="car.fill"))
    add_category(Category(name="Rent", icon_name="house.fill"))
    add_category(Category(name="School", icon_name="book.fill"))
    add_category(Category(name="Savings", icon_name="banknote.fill"))
    add_category(Category(name="Dining", icon_name="fork.knife"))
    add_category(Category(name="Utilities", icon_name="bolt.fill"))
    add_category(Category(name="Misc", icon_name="tray.fill"))

    add_budget(Budget(category="Groceries", amount=252.65, monthly_limit=420.00))
    add_budget(Budget(category="Transportation", amount=82.60, monthly_limit=180.00))
    add_budget(Budget(category="Rent", amount=1250.00, monthly_limit=1250.00))
    add_budget(Budget(category="School", amount=42.99, monthly_limit=150.00))
    add_budget(Budget(category="Savings", amount=150.00, monthly_limit=300.00))
    add_budget(Budget(category="Dining", amount=185.47, monthly_limit=160.00))
    add_budget(Budget(category="Utilities", amount=116.18, monthly_limit=300.00))
    add_budget(Budget(category="Misc", amount=73.20, monthly_limit=200.00))

    add_expense(Expense(amount=86.42, date=datetime(2026, 4, 2), note="Smiths Marketplace", category_id=1))
    add_expense(Expense(amount=54.27, date=datetime(2026, 4, 15), note="Trader Joes", category_id=1))
    add_expense(Expense(amount=112.36, date=datetime(2026, 4, 21), note="Costco", category_id=1))
    add_expense(Expense(amount=38.50, date=datetime(2026, 4, 3), note="UTA FrontRunner pass", category_id=2))
    add_expense(Expense(amount=44.10, date=datetime(2026, 4, 17), note="Chevron", category_id=2))
    add_expense(Expense(amount=1250.00, date=datetime(2026, 4, 6), note="Northview Apartments", category_id=3))
    add_expense(Expense(amount=42.99, date=datetime(2026, 4, 10), note="UVU Bookstore", category_id=4))
    add_expense(Expense(amount=150.00, date=datetime(2026, 4, 12), note="America First Credit Union", category_id=5))
    add_expense(Expense(amount=17.64, date=datetime(2026, 4, 7), note="Aubergine Kitchen", category_id=6))
    add_expense(Expense(amount=13.83, date=datetime(2026, 4, 19), note="Cafe Zupas", category_id=6))
    add_expense(Expense(amount=154.00, date=datetime(2026, 4, 8), note="Concert tickets", category_id=6))
    add_expense(Expense(amount=116.18, date=datetime(2026, 4, 5), note="Orem City Utilities", category_id=7))
    add_expense(Expense(amount=73.20, date=datetime(2026, 4, 20), note="Saucony running shoes", category_id=8))
    add_expense(Expense(amount=28.45, date=datetime(2026, 4, 22), note="Walgreens prescription", category_id=8))

    add_savings_goal(SavingsGoal(name="Emergency Fund", target_amount=3600.00, current_amount=350.00))
    add_savings_goal(SavingsGoal(name="Vacation", target_amount=7200.00, current_amount=425.00))
