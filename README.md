# Daddies Padel Platform (Prototype v1)

## Overview
A streamlined operational platform for the Daddies Padel Community. This app replaces manual Google Sheets and WhatsApp coordination with a mobile-first web interface.

## Key Features
- **Member:** "Sat-set" booking, automated waitlist, payment proof upload.
- **Mimin (Admin):** One-click session creation, manage players (Approve/Reject), verify payments.
- **Bendahara (Treasury):** Real-time cash flow monitoring, expected vs actual revenue.

## Tech Stack
- **Backend:** Python (Flask)
- **Database:** SQLite (Default) / PostgreSQL (Ready)
- **Frontend:** Jinja2 Templates + TailwindCSS (via CDN)
- **Auth:** Flask-Login

## Setup & Run

1.  **Install Dependencies:**
    ```bash
    pip install -r requirements.txt
    ```

2.  **Run the Application:**
    ```bash
    python run.py
    ```

3.  **Access:**
    Open `http://127.0.0.1:5000` in your browser.

## User Roles (How to switch)
By default, new registrations are 'member'. 
To make yourself an admin, you need to edit the database or usage a CLI tool (not included in v1 but can be added).
*For prototype testing, you can modify the database directly or use a shell:*
```bash
flask shell
>>> u = User.query.filter_by(email='your@email.com').first()
>>> u.role = 'admin' # or 'treasurer'
>>> db.session.commit()
```

## Structure
- `app/routes/`: Logic for Auth, Ops, Member, Finance.
- `app/models.py`: Database schema.
- `app/templates/`: UI screens.
