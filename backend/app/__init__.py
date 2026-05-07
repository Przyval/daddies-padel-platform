from flask import Flask
from .config import Config
from .extensions import db, migrate, login_manager


def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    # Initialize Flask extensions
    db.init_app(app)
    migrate.init_app(app, db)
    login_manager.init_app(app)

    # Import models to ensure they are registered with SQLAlchemy
    from . import models

    # Register Blueprints
    from .routes import auth, ops, member, finance, main, tournament, matchmaking, share
    app.register_blueprint(auth.bp, url_prefix='/auth')
    app.register_blueprint(ops.bp, url_prefix='/ops')
    app.register_blueprint(member.bp)  # Main routes at root
    app.register_blueprint(finance.bp, url_prefix='/finance')
    app.register_blueprint(matchmaking.bp, url_prefix='/api/matches')
    app.register_blueprint(main.bp)  # All new pages
    app.register_blueprint(tournament.bp, url_prefix='/tournament')
    app.register_blueprint(share.bp)  # Unified share API

    # Top-level /r/{id} → redirect to tournament live results
    from flask import redirect, url_for
    @app.route('/r/<int:tournament_id>')
    def live_redirect(tournament_id):
        return redirect(url_for('tournament.live_results', tournament_id=tournament_id))

    # Create tables for dev
    with app.app_context():
        db.create_all()

    return app
