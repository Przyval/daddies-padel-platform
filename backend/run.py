from app import create_app, db
from app.models import User, Match, Booking

app = create_app()

@app.shell_context_processor
def make_shell_context():
    return {'db': db, 'User': User, 'Match': Match, 'Booking': Booking}

if __name__ == '__main__':
    # Debug is driven by config (FLASK_DEBUG=1 in dev only, never in production).
    # For production use a real WSGI server: `gunicorn wsgi:app`.
    app.run(debug=app.config['DEBUG'])
