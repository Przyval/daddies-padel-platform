from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_login import LoginManager
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_jwt_extended import JWTManager
from flask_cors import CORS

db = SQLAlchemy()
migrate = Migrate()
login_manager = LoginManager()
login_manager.login_view = 'auth.login'
login_manager.login_message_category = 'info'

# JWT for the native app (Fase 1+), CORS for cross-origin API calls.
jwt = JWTManager()
cors = CORS()

# Rate limiter — generous global default, strict on auth (see routes/auth.py).
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=['600 per hour'],
)
