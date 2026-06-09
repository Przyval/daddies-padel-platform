import os
import secrets


def _normalize_db_url(url):
    """Railway/Heroku hand out 'postgres://' but SQLAlchemy needs 'postgresql://'."""
    if url and url.startswith('postgres://'):
        return url.replace('postgres://', 'postgresql://', 1)
    return url


class Config:
    # In production SECRET_KEY/JWT_SECRET_KEY MUST come from the environment.
    # The random fallback keeps dev working but is regenerated each boot
    # (so it is useless to an attacker and forces real keys in prod).
    SECRET_KEY = os.environ.get('SECRET_KEY') or secrets.token_hex(32)
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY') or SECRET_KEY

    SQLALCHEMY_DATABASE_URI = _normalize_db_url(
        os.environ.get('DATABASE_URL')
    ) or 'sqlite:///daddies.db'
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Environment flag — 'production' enables strict checks below.
    ENV = os.environ.get('FLASK_ENV', 'development')
    IS_PRODUCTION = ENV == 'production'
    DEBUG = os.environ.get('FLASK_DEBUG', '0') == '1' and not IS_PRODUCTION

    # Session/cookie hardening. SECURE only in prod (dev runs on http://).
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'
    SESSION_COOKIE_SECURE = IS_PRODUCTION

    # JWT (Fase 1) — short-lived access token + refresh.
    JWT_ACCESS_TOKEN_EXPIRES = 60 * 60             # 1 hour
    JWT_REFRESH_TOKEN_EXPIRES = 60 * 60 * 24 * 30  # 30 days

    # CORS allowlist (comma-separated origins). Native apps send no Origin so
    # they are unaffected; this only gates browsers. Unset → '*' in dev,
    # locked down (no cross-origin) in production.
    CORS_ORIGINS = os.environ.get('CORS_ORIGINS')

    @staticmethod
    def validate():
        """Fail fast in production if real secrets / DB are missing."""
        if Config.IS_PRODUCTION:
            problems = []
            if not os.environ.get('SECRET_KEY'):
                problems.append('SECRET_KEY')
            if not os.environ.get('DATABASE_URL'):
                problems.append('DATABASE_URL')
            if problems:
                raise RuntimeError(
                    'Missing required production env vars: ' + ', '.join(problems)
                )
