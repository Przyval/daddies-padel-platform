# TODOS — Daddies Padel Platform

## High Priority

### Auth guards on tournament mutating routes
**What:** Add `@login_required` + tournament ownership check to all POST routes: `/score/`, `/settings/`, `/complete/`, `/delete/`, `/rename/`, `/playoff_score/`, `/next_round/`, `/generate_playoff/`.
**Why:** Currently anyone who knows the URL can change scores, rename players, or delete tournaments. Score tampering is possible.
**Context:** Flask-Login is already installed. `current_user` is available. Need `created_by` check on Tournament model (field exists). Some routes (create) should remain public for demo access.
**Depends on:** Nothing. Can be done independently.

### Race condition in MORE ROUNDS (double-click)
**What:** `next_round()` reads `tournament.total_rounds + 1` via count query. Double-tap creates duplicate round number.
**Why:** Common on slow mobile. Two concurrent requests both create round N+1.
**Fix:** Add unique constraint on `(tournament_id, round_number)` + handle IntegrityError. Or debounce the MORE ROUNDS button client-side (simpler).
**Context:** tournament.py line 907. `TournamentRound` model needs `UniqueConstraint('tournament_id', 'round_number')`.
**Depends on:** DB migration (or reseed).

## Medium Priority

### CSRF protection
**What:** Initialize Flask-WTF CSRFProtect. Add CSRF tokens to all forms and fetch() calls.
**Why:** Any page on the internet can submit a form to `/tournament/1/complete` if the user has a session cookie.
**Context:** Flask-WTF is likely already in requirements. Need `CSRFProtect(app)` in `__init__.py` and `{{ csrf_token() }}` in forms.

### Streak claim name-squatting
**What:** `confirm_streak_claim` matches player name and binds `user_id` without verification.
**Why:** Any logged-in user can claim any unclaimed participant name, inflating their streak/chips/tier.
**Context:** tournament.py `confirm_streak_claim` route. Need invite-link or QR-code verification.

## Low Priority

### Tailwind CSS CDN in production
**What:** Replace `cdn.tailwindcss.com` with compiled CSS.
**Why:** ~300KB uncompressed on every page load. CDN version not recommended for production.

### Hardcoded padeldaddies.site domain
**What:** Replace hardcoded URLs with `url_for(..., _external=True)`.
**Why:** Share links break on localhost, staging, or different domains.
**Context:** tournament.py lines 1267-1268, 1373.
