from app import create_app, db
from app.models import User, Match, Booking

app = create_app()

@app.shell_context_processor
def make_shell_context():
    return {'db': db, 'User': User, 'Match': Match, 'Booking': Booking}

if __name__ == '__main__':
    app.run(debug=True)
