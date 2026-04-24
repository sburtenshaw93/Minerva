# Minerva

A personal budgeting iOS app with a Python backend. Track expenses, manage category budgets, review spending history, and get financial tips from Henry, an AI budgeting assistant built into the app.

---

## Features

- **Home** — Budget overview, spending by category chart, recent transactions, and budget alerts
- **History** — Full transaction list with category filtering and inline editing
- **Budget** — Monthly category budgets with doughnut/bar charts, color palettes, and spending projections
- **Add Expense** — Manual expense entry with merchant, amount, category, date, payment method, note, and receipt upload
- **Henry** — AI assistant that reviews your synced expense data and offers budget tips and warnings
- **More** — Profile editor (name, email, bio, photo) and app settings

---

## Architecture

Minerva uses the **MVC pattern** across both the backend and frontend.

```
minerva/
├── Backend/                  # Python FastAPI backend
│   ├── main.py               # API routes and app startup
│   ├── database/
│   │   └── database.py       # SQLite setup, seeding, and CRUD
│   ├── controllers/
│   │   └── ExpenseController.py
│   ├── repositories/
│   │   └── ExpenseRepository.py
│   └── models/
│       ├── Expense.py
│       ├── Category.py
│       ├── Budget.py
│       └── SavingsGoal.py
└── swift/
    └── final-project/        # SwiftUI iOS app
        └── final-project/
            ├── final_projectApp.swift
            ├── ContentView.swift     # All SwiftUI screens
            ├── ExpenseController.swift
            ├── ExpenseDatabase.swift # Local SQLite via SQLite3
            ├── ExpenseAPIService.swift
            ├── ExpenseModels.swift
            └── MinervaStyle.swift    # Design system and color tokens
```

**Backend:** FastAPI + SQLite  
**Frontend:** SwiftUI with `@Observable`, local SQLite3 database  
**Data flow:** The iOS app stores data locally and syncs with the Python backend on launch. Remote expenses are matched to local categories, checked for duplicates, and merged into the local database.

---

## Getting Started

### Backend

Requires Python 3.10+.

```bash
cd Backend
pip install fastapi uvicorn
uvicorn main:app --reload
```

The API will be available at `http://127.0.0.1:8000`. The database is created and seeded automatically on first run.

**Endpoints:**
| Method | Path | Description |
|--------|------|-------------|
| GET | `/expenses` | List all expenses |
| GET | `/category` | List all categories |
| GET | `/budget` | List all budgets |
| GET | `/savings_goals` | List all savings goals |

### iOS App

Open `swift/final-project/final-project.xcodeproj` in Xcode, select a simulator or device, and press Run. The app connects to `http://127.0.0.1:8000` on launch to sync backend expenses.

> Make sure the backend is running before launching the app if you want API sync to work.

---

## Data Model

**Categories** — Groceries, Transportation, Rent, School, Savings, Dining, Utilities, Misc (each with a monthly spending limit)

**Expenses** — merchant, amount, date, note, category

**Budget Summaries** — calculated from category totals for the current month, not a separate budget table

**Savings Goals** — name, target amount, current amount (e.g. Emergency Fund, Vacation)

---

## Design

- Glassmorphism UI with translucent cards and blur materials
- Mountain silhouette background
- 4 color palettes for budget charts: Earth, Ocean, Dusk, Natural
- Full dark mode and light mode support
- Custom design token system in `MinervaStyle.swift`

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| iOS Frontend | Swift, SwiftUI, SQLite3 |
| Backend | Python, FastAPI |
| Database (backend) | SQLite |
| Database (iOS) | SQLite3 (local, document storage) |
| API | REST / JSON over HTTP |
