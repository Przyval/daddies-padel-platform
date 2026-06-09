# Deploy Daddies Padel API ke VPS (Ubuntu 22/24 LTS)

Stack: **nginx** (TLS) → **gunicorn** (systemd) → **Flask** → **PostgreSQL** (lokal).
Domain contoh: `api.daddiespadel.com` (ganti dengan domain kamu di semua langkah).

> Prasyarat: VPS Ubuntu, akses root/sudo, dan **A record** domain sudah diarahkan ke IP VPS.

---

## 1. Hardening dasar server

```bash
# Login sebagai root, buat user deploy non-root
adduser deploy
usermod -aG sudo deploy

# Firewall: hanya SSH + HTTP + HTTPS
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw enable

# (disarankan) SSH key-only, matikan login password di /etc/ssh/sshd_config:
#   PasswordAuthentication no
# lalu: systemctl restart ssh
```

## 2. Install paket

```bash
sudo apt update
sudo apt install -y python3-venv python3-pip nginx postgresql certbot python3-certbot-nginx git
```

## 3. PostgreSQL (lokal, listen localhost saja)

```bash
sudo -u postgres psql <<'SQL'
CREATE DATABASE daddies;
CREATE USER daddies WITH PASSWORD 'GANTI_PASSWORD_KUAT';
GRANT ALL PRIVILEGES ON DATABASE daddies TO daddies;
ALTER DATABASE daddies OWNER TO daddies;
SQL
```
Postgres default sudah listen `localhost` saja — jangan ubah ke `0.0.0.0` (biar tidak terekspos publik).

## 4. Ambil kode + virtualenv

```bash
sudo mkdir -p /opt/daddies && sudo chown deploy:deploy /opt/daddies
cd /opt/daddies
git clone <URL_REPO_KAMU> app
python3 -m venv /opt/daddies/venv
/opt/daddies/venv/bin/pip install -r app/backend/requirements.txt
sudo mkdir -p /var/log/daddies && sudo chown deploy:deploy /var/log/daddies
```

## 5. Environment variables

```bash
sudo mkdir -p /etc/daddies
sudo cp /opt/daddies/app/deploy/env.example /etc/daddies/env
# Generate 2 secret berbeda:
python3 -c "import secrets; print(secrets.token_hex(32))"   # untuk SECRET_KEY
python3 -c "import secrets; print(secrets.token_hex(32))"   # untuk JWT_SECRET_KEY
sudo nano /etc/daddies/env        # isi SECRET_KEY, JWT_SECRET_KEY, DATABASE_URL (password DB)
sudo chmod 600 /etc/daddies/env
```

## 6. Migrasi database

```bash
cd /opt/daddies/app/backend
set -a; source /etc/daddies/env; set +a
/opt/daddies/venv/bin/flask db upgrade
/opt/daddies/venv/bin/python seed.py    # (opsional) isi data awal
```

## 7. systemd service (gunicorn)

```bash
sudo cp /opt/daddies/app/deploy/daddies.service /etc/systemd/system/daddies.service
sudo systemctl daemon-reload
sudo systemctl enable --now daddies
sudo systemctl status daddies        # harus active (running)
curl -s http://127.0.0.1:8000/api/v1/health   # {"ok":true,...}
```

## 8. nginx + HTTPS

```bash
sudo cp /opt/daddies/app/deploy/nginx.conf /etc/nginx/sites-available/daddies
# edit server_name = domain kamu
sudo nano /etc/nginx/sites-available/daddies
sudo ln -s /etc/nginx/sites-available/daddies /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# Terbitkan sertifikat TLS (gratis, auto-renew):
sudo certbot --nginx -d api.daddiespadel.com
```

## 9. Verifikasi

```bash
curl -s https://api.daddiespadel.com/api/v1/health      # {"ok":true}
curl -s -X POST https://api.daddiespadel.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"hendy@daddiespadel.com","password":"daddies"}'
```

---

## Update berikutnya (setelah ada perubahan kode)

```bash
cd /opt/daddies/app && ./deploy/deploy.sh
```

## Backup database (cron harian)

```bash
# crontab -e (sebagai user deploy)
0 2 * * * pg_dump -U daddies daddies | gzip > /opt/daddies/backups/daddies-$(date +\%F).sql.gz
```

## Catatan
- **Rate limit multi-worker:** dengan banyak gunicorn worker, limiter in-memory tidak akurat. Pasang Redis lalu set `RATELIMIT_STORAGE_URI=redis://localhost:6379` di `/etc/daddies/env`.
- **Log:** `sudo journalctl -u daddies -f` atau `/var/log/daddies/`.
- **Aplikasi web lama (HTML)** tetap jalan di domain ini juga; API ada di `/api/v1/*`.
