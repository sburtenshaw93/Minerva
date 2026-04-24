from fastapi import FastAPI
from database.database import (
    initialize_db, seed_data,
    get_all_expenses, get_all_categories,
    get_all_budgets, get_all_savings_goals
)

app = FastAPI()

@app.on_event("startup")
def startup():
    initialize_db()
    seed_data()
    
@app.get("/expenses")
def get_expenses():
    rows = get_all_expenses()
    return [{"id": r[0], "amount": r[1], "date": r[2], "note": r[3], "category_id": r[4]} for r in rows]

@app.get("/category")
def get_categories():
    rows = get_all_categories()
    return [{"id": r[0], "name": r[1], "icon_name": r[2]} for r in rows]

@app.get("/budget")
def get_budgets():
    rows = get_all_budgets()
    return [{"id": r[0], "amount": r[1], "monthly_limit": r[2], "category": r[3]} for r in rows]

@app.get("/savings_goals")
def get_savings_goals():
    rows = get_all_savings_goals()
    return [{"id": r[0], "name": r[1], "target_amount": r[2], "current_amount": r[3]} for r in rows]