from app import create_app, db

app = create_app()
with app.app_context():
    print("Registered Tables:", db.metadata.tables.keys())
