"""Gunicorn config for the Daddies Padel API.
Run via systemd: gunicorn -c deploy/gunicorn.conf.py wsgi:app
"""
import multiprocessing

# Bind to localhost only — nginx is the public-facing server (handles TLS).
bind = "127.0.0.1:8000"

# A common starting point. Tune to your VPS: (2 x cores) + 1.
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
timeout = 60
graceful_timeout = 30
keepalive = 5

# Recycle workers periodically to bound memory leaks.
max_requests = 1000
max_requests_jitter = 100

# Logs (systemd also captures stdout/stderr to journald).
accesslog = "/var/log/daddies/access.log"
errorlog = "/var/log/daddies/error.log"
loglevel = "info"
