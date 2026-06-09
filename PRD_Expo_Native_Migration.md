# PRD — Daddies Padel: Expo Native App + Flask JSON API

**Status:** Draft v1
**Tanggal:** 2026-06-09
**Pemilik:** Daddies Padel
**Jalur dipilih:** Jalur 2 — Expo (React Native) native + Flask sebagai backend JSON API

---

## 1. Ringkasan & Tujuan

Mengubah platform Daddies Padel yang sekarang **web server-rendered (Flask + Jinja HTML)** menjadi:

1. **Backend:** Flask yang **murni JSON API** (stateless, token-based auth).
2. **Frontend:** Aplikasi **native Expo (React Native)** untuk Android (APK/AAB) dan iOS, dibangun via **EAS Build**.

**Hasil akhir:** APK/AAB native yang berisi semua fitur membership, turnamen, keuangan, dan komunitas — bukan WebView, tapi layar native asli yang memanggil API.

### Kenapa Jalur 2
- Pengalaman native penuh (offline-capable sebagian, push notification, animasi mulus).
- Aman dari kebijakan Play Store "minimum functionality" (bukan webview shell).
- Satu sumber data (Flask API) bisa melayani app + web masa depan.

---

## 2. Kondisi Saat Ini (Baseline)

| Aspek | Kondisi sekarang |
|---|---|
| Backend | Flask + SQLAlchemy + SQLite, **render HTML (Jinja)** |
| Auth | Flask-Login **session cookie** (tidak cocok untuk native) |
| Model DB | 20 model (User, Tournament, Match, ChipsTransaction, dll) |
| Route | ~95 route (banyak HTML + duplikat wizard v1/v2/v3 + share-card) |
| Template | 68 file HTML |
| Endpoint JSON | Hanya sebagian kecil (input skor, search, share/generate) |
| Frontend native | Belum ada (Flutter lama ada tapi divergen — **di luar scope**) |

### Masalah keamanan baseline (WAJIB diperbaiki di Fase 0)
- `SECRET_KEY = 'dev-key-please-change'` hardcoded — [config.py](backend/app/config.py)
- `app.run(debug=True)` — [run.py](backend/run.py)
- Tidak ada cookie secure / CSRF / rate limiting
- Flask dev server + SQLite (bukan untuk produksi)
- `print("DEBUG: ...")` membocorkan data — [tournament_service.py](backend/app/services/tournament_service.py)

---

## 3. Scope

### In-scope
- Fase 0: Hardening keamanan + siapkan Flask untuk produksi.
- Fase 1: Lapisan **JSON API** + **token auth (JWT)** di atas model yang sudah ada.
- Fase 2: App Expo native (auth, membership, sesi, turnamen, leaderboard, profil, chips/KTA, shop, notifikasi).
- Fase 3: Build & rilis via EAS (APK internal → AAB Play Store).

### Out-of-scope (fase ini)
- Codebase Flutter lama (`lib/`, `americano_padel/`) — dibekukan, tidak disentuh.
- Migrasi database SQLite → Postgres (opsional, direkomendasikan saat skala naik).
- Fitur share-card render gambar server-side yang kompleks — Fase 2 pakai **native share** dulu; render gambar tetap via API kalau perlu.
- iOS App Store submission (disiapkan, tapi rilis Android dulu).

---

## 4. Arsitektur Target

```
┌─────────────────────────┐         HTTPS / JSON          ┌──────────────────────────┐
│   Expo App (React        │  ───────────────────────────► │   Flask JSON API          │
│   Native + TypeScript)   │   Authorization: Bearer JWT   │   (gunicorn + HTTPS)      │
│                          │ ◄───────────────────────────  │                          │
│  - expo-router           │                               │  - /api/v1/* (JSON)      │
│  - React Query (cache)   │                               │  - JWT auth              │
│  - SecureStore (token)   │                               │  - SQLAlchemy + DB       │
│  - native screens        │                               │  - card_renderer (img)   │
└─────────────────────────┘                               └──────────────────────────┘
                                                                      │
                                                            ┌─────────┴─────────┐
                                                            │  SQLite → Postgres │
                                                            └────────────────────┘
```

**Prinsip:**
- API **stateless** — tidak ada session cookie; semua auth pakai **JWT** di header.
- Semua endpoint baru di-namespace `/api/v1/...` dan **selalu balikin JSON** (`{ ok, data, error }`).
- Route HTML lama dibiarkan dulu (untuk web), tidak dihapus — API jalan paralel.

---

## 5. Fase 0 — Hardening Keamanan (WAJIB, ~0.5 hari)

| # | Item | Detail |
|---|---|---|
| 0.1 | `SECRET_KEY` dari env | Hapus fallback hardcoded; generate kunci acak kuat; gagal start kalau kosong di prod |
| 0.2 | `debug=False` di prod | Pakai env `FLASK_ENV`; jalankan via **gunicorn**, bukan dev server |
| 0.3 | Cookie aman (web) | `SESSION_COOKIE_SECURE/HTTPONLY/SAMESITE` |
| 0.4 | Rate limiting | `flask-limiter` di endpoint auth (`/login`, `/register`) |
| 0.5 | Hapus `print()` debug | Ganti dengan logging proper |
| 0.6 | CORS | `flask-cors` dibatasi ke origin app (untuk dev/web), API mobile pakai token |
| 0.7 | Validasi input | Skema request (mis. `marshmallow`/`pydantic`) di endpoint write |

**Acceptance:** server jalan via gunicorn, HTTPS, tanpa secret hardcoded, endpoint auth ter-rate-limit.

---

## 6. Fase 1 — Flask → JSON API

### 6.1 Strategi Auth (paling kritis)
- Tambah **JWT** (`flask-jwt-extended`): `POST /api/v1/auth/login` → `{ access_token, refresh_token, user }`.
- App simpan token di **expo-secure-store** (terenkripsi), kirim `Authorization: Bearer <token>`.
- Decorator `require_member` / `require_tournament_owner` yang sudah ada tinggal dipadankan ke konteks JWT (`get_jwt_identity()`).
- Refresh token flow: `POST /api/v1/auth/refresh`.

### 6.2 Format respons standar
```json
{ "ok": true,  "data": { ... } }
{ "ok": false, "error": { "code": "FORBIDDEN", "message": "Upgrade membership untuk fitur ini" } }
```

### 6.3 Peta Endpoint API (target `/api/v1`)

Dikonsolidasi dari ~95 route lama (buang duplikat wizard v1/v2/v3, gabung share-card):

| Domain | Endpoint | Sumber route lama |
|---|---|---|
| **Auth** | `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/validate-referral` | auth.py |
| **Me / Profil** | `GET /me`, `PATCH /me`, `GET /me/streak`, `GET /me/chips`, `GET /me/card` | main.py profile/streak/chips |
| **Membership** | `GET /membership`, `POST /membership/upgrade`, `GET /kta` | main.py membership/kta |
| **Members** | `GET /members`, `GET /members/:id`, `POST /members/search` | main.py + matchmaking |
| **Sesi** | `GET /sessions`, `GET /sessions/:id`, `POST /sessions`, `PATCH /sessions/:id`, `POST /sessions/:id/join`, `POST /sessions/:id/payment`, `GET /sessions/history` | main.py + member.py + ops.py |
| **Turnamen** | `GET /tournaments`, `POST /tournaments`, `GET /tournaments/:id`, `DELETE /tournaments/:id`, `POST /tournaments/:id/score/:matchId`, `POST /tournaments/:id/next_round`, `POST /tournaments/:id/complete`, `GET/PATCH /tournaments/:id/settings`, `POST /tournaments/:id/swap`, `POST /tournaments/:id/generate_playoff`, `POST /tournaments/:id/playoff_score/:pid` | tournament.py |
| **Leaderboard** | `GET /leaderboard` | main.py |
| **Chips/Wallet** | `GET /chips`, `GET /chips/milestone/:threshold` | main.py |
| **Referral** | `GET /referral`, `POST /referral/use` | main.py + referral util |
| **Shop** | `GET /shop`, `POST /shop/buy/:itemId` | main.py shop |
| **Keuangan (Kas)** | `GET /kas`, `POST /kas`, `POST /kas/approve/:id`, `GET /finance/dashboard` | main.py kas + finance.py |
| **KOTH** | `GET /koth`, `POST /koth/:matchId/result` | main.py koth |
| **Notifikasi** | `GET /notifications`, `POST /notifications/read-all` | main.py |
| **Venue/Partner** | `GET /venues`, `GET /venues/:id`, `GET /partners` | main.py |
| **Poker Night** | `GET /poker-night`, `POST /poker-night/register/:eventId` | main.py |
| **Admin/Ops** | `GET /ops/dashboard`, `POST /ops/sessions`, `POST /admin/invite-elite`, `POST /admin/season`, `POST /admin/send-weekly-notifs` | ops.py + main.py admin |
| **Share (gambar)** | `POST /share/generate` → balikin URL gambar | share.py (tetap, untuk share-card) |

> Catatan: route `share/*-card`, `*/whatsapp`, `*/download` yang server-render gambar **tidak jadi layar** — di app pakai **native share sheet**; render gambar tetap via `POST /share/generate`.

### 6.4 Serializer
- Tambah `to_dict()` / schema (marshmallow) per model agar konsisten JSON.
- 20 model → prioritaskan: `User`, `Tournament*`, `Match`, `ChipsTransaction`, `ShopItem/Order`, `Notification`.

**Acceptance Fase 1:** semua endpoint di tabel 6.3 balikin JSON valid + ter-proteksi JWT, lulus test (pakai `backend/tests/` yang sudah ada + tambahan API test).

---

## 7. Fase 2 — App Expo (React Native)

### 7.1 Stack
- **Expo SDK (terbaru)** + **expo-router** (file-based routing)
- **TypeScript**
- **React Query** (data fetching + cache + offline)
- **expo-secure-store** (token), **axios** (HTTP client + interceptor JWT/refresh)
- **expo-notifications** (push), **expo-image**, **react-native-reanimated**

### 7.2 Inventaris Layar (28 layar dari 68 template, sudah dikurangi duplikat)

| Grup | Layar |
|---|---|
| **Auth/Onboarding** | Splash, Login, Register, Validate-referral |
| **Home/Nav** | Tab bar: Beranda, Sesi, Anggota, Profil |
| **Membership** | Membership (status/progress/tier), KTA Digital |
| **Sesi** | List sesi, Detail sesi, Buat sesi, Edit sesi, Upload bukti bayar, Riwayat |
| **Turnamen** | List turnamen, Wizard buat (4 langkah jadi 1 flow), Detail/live + input skor, Settings, Playoff bracket |
| **Komunitas** | Leaderboard, Daftar anggota, Profil publik anggota |
| **Reward/Ekonomi** | Chips history, Shop, Referral |
| **Keuangan** | Kas dashboard, Tambah transaksi (treasurer), Finance dashboard (admin) |
| **Lainnya** | Notifikasi, Settings, Venues, Partners, Streak, KOTH, Poker Night |
| **Admin** | Ops dashboard, Invite Elite, Season |

> Wizard turnamen v1/v2/v3 (6+6 template) → **satu** flow native multi-step. Share-card HTML → **native share sheet**.

### 7.3 Navigasi
- Bottom tab (4): Beranda / Sesi / Anggota / Profil
- Stack di tiap tab untuk detail
- Guard berbasis role & membership (mirror `require_member` di sisi app + ditegakkan server)

**Acceptance Fase 2:** user bisa login, lihat membership, join sesi, main turnamen + input skor, lihat leaderboard, beli di shop — semua via API, di device nyata.

---

## 8. Fase 3 — Build & Rilis (EAS)

| # | Item |
|---|---|
| 3.1 | Setup `eas.json` (profile: development, preview, production) |
| 3.2 | `eas build -p android --profile preview` → **APK** untuk tes internal |
| 3.3 | Push notification (FCM) setup |
| 3.4 | `eas build -p android --profile production` → **AAB** Play Store |
| 3.5 | (Opsional) `eas build -p ios` untuk TestFlight |
| 3.6 | EAS Update (OTA) untuk patch JS tanpa rilis ulang |

**Catatan keamanan rilis:** API harus sudah di-hosting (VPS/cloud) dengan **HTTPS** sebelum APK dibagikan — WebView/native sama-sama butuh ini.

---

## 9. Persyaratan Keamanan (ringkas, "aman"-checklist)

- [ ] JWT dengan expiry pendek + refresh token
- [ ] Token disimpan di `expo-secure-store` (bukan AsyncStorage)
- [ ] HTTPS wajib (cleartext diblokir Android)
- [ ] `SECRET_KEY` & JWT secret dari env, acak kuat
- [ ] Rate limiting di auth
- [ ] Validasi & sanitasi input semua endpoint write
- [ ] Otorisasi ditegakkan di **server** (jangan percaya client)
- [ ] `debug=False`, gunicorn, log proper
- [ ] CORS dibatasi
- [ ] Backup DB rutin

---

## 10. Milestone & Estimasi (indikatif)

| Fase | Output | Estimasi |
|---|---|---|
| Fase 0 | Hardening keamanan | 0.5 hari |
| Fase 1 | JSON API + JWT + serializer + test | 4–6 hari |
| Fase 2 | App Expo (28 layar) | 2–4 minggu |
| Fase 3 | EAS build + rilis | 1–2 hari |

> Estimasi tergantung kedalaman tiap layar; turnamen (input skor, bracket, wizard) paling berat.

---

## 11. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| API & HTML divergen (dua jalur) | Namespace `/api/v1`, share service layer, jangan duplikasi logika |
| Auth migration (cookie → JWT) rumit | Kerjakan & test paling awal di Fase 1 |
| Logika turnamen kompleks (playoff, mixicano, mexicano) belum lengkap di service | Audit `tournament_service.py` dulu; format selain americano belum diimplementasi |
| SQLite bottleneck saat banyak user | Siapkan jalur migrasi ke Postgres |
| Scope layar membengkak | Rilis MVP: auth + membership + sesi + turnamen + leaderboard dulu; sisanya fase lanjut |

---

## 12. MVP vs Full (saran urutan rilis)

**MVP (rilis pertama):** Auth, Membership/KTA, Sesi (list/detail/join/bayar), Turnamen (buat/skor/leaderboard), Profil.

**Rilis lanjut:** **Chips/Wallet**, **Shop**, Kas/Finance, KOTH, Poker Night, Sponsor, Admin tools, Share-card, Venue/Partner.

> **Chips & Shop sengaja DITUNDA (post-MVP).** Selain mengurangi scope, ini menghindari aturan **In-App Purchase Apple (potong 30%)** untuk fitur digital → review App Store rilis pertama jadi mulus. IAP baru diurus saat Chips/Shop dirilis.

---

## 13. Keputusan Terkunci (locked)

| # | Keputusan | Pilihan | Catatan |
|---|---|---|---|
| 1 | **Hosting** | **VPS sendiri** | Kontrol penuh. Stack: nginx (reverse proxy) + gunicorn (systemd) + Postgres lokal + Let's Encrypt (HTTPS gratis). Wajib **domain** untuk SSL |
| 2 | **Database** | **Postgres (managed)** | SQLite TIDAK dipakai di hosting — filesystem container ephemeral (data hilang saat redeploy). Migrasi `DATABASE_URL` + alembic |
| 3 | **Platform** | **iOS + Android (dual sejak awal)** | Satu codebase Expo. Submit Android dulu, iOS menyusul ~1–2 minggu (akun Apple + review) |
| 4 | **Format turnamen** | **Lengkapi di Fase 1, MVP rilis Americano** | Mexicano & Mixicano belum ada logikanya; fix bug americano juga |
| 5 | **Chips & Shop** | **DITUNDA (post-MVP)** | Hindari IAP Apple 30% di rilis pertama |

## 14. Khusus iOS (dual-platform)

| Item | Detail | Biaya |
|---|---|---|
| Apple Developer Program | Wajib untuk TestFlight & App Store | **$99/tahun** |
| TestFlight | Distribusi tes internal iOS | Gratis (butuh akun di atas) |
| Review App Store | Lebih ketat (~1–3 hari, bisa ditolak) | Waktu |
| APNs (push iOS) | Terpisah dari FCM Android | Konfigurasi |
| Mac | **Tidak wajib** — EAS build iOS di cloud | — |

### Risiko IAP Apple (ditunda bersama Chips)
- Apple mewajibkan IAP (potong 30% / 15% small business) untuk **barang/fitur digital**.
- **Chips, numbered editions, unlock membership digital** berpotensi kena aturan ini.
- **Bebas IAP:** layanan/barang fisik nyata (booking sesi padel, merch fisik).
- **Mitigasi:** Chips & Shop tidak masuk MVP → tidak ada blocker IAP saat rilis pertama. Saat dirilis nanti: pakai `expo-in-app-purchases` / RevenueCat, atau posisikan sebagai layanan klub fisik.

---

## 14b. Deployment VPS (pengganti Railway)

**Arsitektur:**
```
Internet ──HTTPS──► nginx (443, reverse proxy + SSL)
                      └──proxy──► gunicorn (127.0.0.1:8000, systemd service)
                                    └──► Flask app (wsgi:app)
                                            └──► PostgreSQL (localhost:5432)
```

**Checklist setup (sekali):**
1. VPS Ubuntu 22/24 LTS, user non-root + `ufw` (buka 22, 80, 443 saja)
2. Install: `python3-venv`, `nginx`, `postgresql`, `certbot`
3. PostgreSQL: buat DB + user; `DATABASE_URL=postgresql://user:pass@localhost:5432/daddies`
4. Clone repo, venv, `pip install -r requirements.txt`
5. Env var via systemd `EnvironmentFile=/etc/daddies/env` (SECRET_KEY, JWT_SECRET_KEY, DATABASE_URL, FLASK_ENV=production)
6. `flask db upgrade` (migrasi schema)
7. systemd service: `gunicorn wsgi:app --workers 3 --bind 127.0.0.1:8000`
8. nginx: reverse proxy ke `127.0.0.1:8000`, server_name = domain
9. `certbot --nginx -d api.daddiespadel.com` → HTTPS gratis + auto-renew
10. (Opsional) Redis untuk rate-limit storage multi-worker

**File yang perlu dibuat di repo (deploy/):**
- `deploy/daddies.service` (systemd unit)
- `deploy/nginx.conf` (reverse proxy + SSL)
- `deploy/gunicorn.conf.py` (workers, timeout, logging)
- `deploy/DEPLOY.md` (langkah lengkap)
- `deploy/deploy.sh` (pull + migrate + restart untuk update berikutnya)

**Keamanan VPS (lanjutan checklist §9):**
- Postgres **hanya** listen localhost (jangan expose publik)
- gunicorn jalan sebagai user non-root
- `ufw` aktif, SSH key-only (matikan password login)
- Backup DB rutin (`pg_dump` cron)

---

## 15. Langkah Berikutnya

Setelah PRD disetujui, urutan eksekusi terkunci:

```
Fase 0  Hardening keamanan + pindah Postgres   (~0.5 hari)
Fase 1  JSON API + JWT auth + fix/lengkapi turnamen   (4–6 hari)
Deploy  Railway + HTTPS   (~1 jam)
Fase 2  Expo app MVP (tanpa Chips/Shop)   (2–4 minggu)
Fase 3  EAS build → APK (Android) → AAB + TestFlight (iOS)   (1–2 hari)
```

Langkah pertama yang direkomendasikan: **Fase 0 (hardening + Postgres) + Fase 1 endpoint Auth (JWT)** — pondasi semua fase berikutnya.
