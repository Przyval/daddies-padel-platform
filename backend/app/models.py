from .extensions import db, login_manager
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
import json


class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(64), index=True, unique=True)
    email = db.Column(db.String(120), index=True, unique=True)
    phone = db.Column(db.String(20), index=True, unique=True)
    password_hash = db.Column(db.String(128))
    role = db.Column(db.String(20), default='member')  # 'admin', 'treasurer', 'member'
    membership = db.Column(db.String(20), default='guest')  # 'guest', 'pre_member', 'member', 'elite'
    nickname = db.Column(db.String(32), default='')
    bio = db.Column(db.String(200), default='')
    avatar_url = db.Column(db.String(300), default='')
    kta_number = db.Column(db.String(20), default='')
    kta_tier = db.Column(db.String(20), default='bronze')  # bronze, silver, gold, platinum
    chips_balance = db.Column(db.Integer, default=0)
    referral_code = db.Column(db.String(10), default='')
    referred_by = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    invited_by = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    membership_paid = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    bookings = db.relationship('Booking', backref='player', lazy='dynamic')
    notifications = db.relationship('Notification', backref='user', lazy='dynamic')
    chips_transactions = db.relationship('ChipsTransaction', backref='user', lazy='dynamic')

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    @property
    def display_name(self):
        return self.nickname or self.username

    @property
    def initials(self):
        parts = (self.username or '??').split()
        if len(parts) >= 2:
            return (parts[0][0] + parts[1][0]).upper()
        return (self.username[:2] if self.username else '??').upper()

    @property
    def first_name(self):
        return (self.username or '').split()[0] if self.username else ''

    @property
    def sessions_played(self):
        return self.bookings.filter(Booking.status.in_(['confirmed', 'paid'])).count()

    @property
    def tournaments_played(self):
        from app.models import TournamentParticipant
        return TournamentParticipant.query.filter_by(user_id=self.id).count()

    @property
    def total_games(self):
        return self.sessions_played + self.tournaments_played

    @property
    def total_points(self):
        return self.chips_balance

    @property
    def streak_data(self):
        """Calculate attendance streak in WEEKS (not days).
        A week counts if member participated in at least 1 session/tournament that week.
        """
        from datetime import timedelta

        # Collect all activity dates
        dates = []
        for b in self.bookings.filter(Booking.status.in_(['confirmed', 'paid'])).all():
            if b.match and b.match.date_time:
                dates.append(b.match.date_time.date())

        # Also count tournament participations
        for tp in TournamentParticipant.query.filter_by(user_id=self.id).all():
            if tp.tournament and tp.tournament.date:
                dates.append(tp.tournament.date.date())

        if not dates:
            return {'current': 0, 'longest': 0, 'total_weeks': 0, 'at_risk': False, 'tier': 'none'}

        # Group by ISO week (year, week_number)
        active_weeks = set()
        for d in dates:
            iso = d.isocalendar()
            active_weeks.add((iso[0], iso[1]))  # (year, week)

        # Count consecutive weeks backwards from current
        now = datetime.utcnow().date()
        current_iso = now.isocalendar()
        year, week = current_iso[0], current_iso[1]
        streak = 0

        while (year, week) in active_weeks:
            streak += 1
            # Go to previous week
            d = datetime.strptime(f'{year} {week} 1', '%G %V %u').date()
            prev = d - timedelta(days=7)
            prev_iso = prev.isocalendar()
            year, week = prev_iso[0], prev_iso[1]

        # Check if at risk (current week has no activity yet)
        current_week = (current_iso[0], current_iso[1])
        at_risk = current_week not in active_weeks and streak > 0

        # If current week is missing, the streak was from last week
        if current_week not in active_weeks:
            # Recount from last week
            last_week = (datetime.utcnow().date() - timedelta(days=7)).isocalendar()
            year, week = last_week[0], last_week[1]
            streak = 0
            while (year, week) in active_weeks:
                streak += 1
                d = datetime.strptime(f'{year} {week} 1', '%G %V %u').date()
                prev = d - timedelta(days=7)
                prev_iso = prev.isocalendar()
                year, week = prev_iso[0], prev_iso[1]

        # Longest streak (scan all weeks)
        sorted_weeks = sorted(active_weeks)
        longest = 0
        if sorted_weeks:
            run = 1
            for i in range(1, len(sorted_weeks)):
                prev_d = datetime.strptime(f'{sorted_weeks[i-1][0]} {sorted_weeks[i-1][1]} 1', '%G %V %u').date()
                curr_d = datetime.strptime(f'{sorted_weeks[i][0]} {sorted_weeks[i][1]} 1', '%G %V %u').date()
                if (curr_d - prev_d).days <= 8:  # consecutive week
                    run += 1
                else:
                    longest = max(longest, run)
                    run = 1
            longest = max(longest, run)

        # Tier
        if streak >= 52: tier = 'diamond'
        elif streak >= 26: tier = 'gold'
        elif streak >= 12: tier = 'silver'
        elif streak >= 4: tier = 'bronze'
        else: tier = 'none'

        return {
            'current': streak,
            'longest': longest,
            'total_weeks': len(active_weeks),
            'at_risk': at_risk,
            'tier': tier,
        }

    @property
    def membership_label(self):
        labels = {'guest': 'Guest', 'pre_member': 'Pre-Member', 'member': 'Member', 'elite': 'Elite'}
        return labels.get(self.membership, 'Guest')

    @property
    def membership_color(self):
        colors = {'guest': 'on-surface-variant', 'pre_member': 'info', 'member': 'success', 'elite': 'warning'}
        return colors.get(self.membership, 'on-surface-variant')

    @property
    def can_unlock_kta(self):
        """KTA unlocks after 5 games played."""
        return self.total_games >= 5 and self.membership in ('guest', 'pre_member')

    def check_auto_upgrade(self):
        """Auto-upgrade membership based on activity.
        guest → pre_member: after first booking
        pre_member → member: after 5 games + payment
        member sub-tiers: Bronze(4wk)/Silver(12wk)/Gold(26wk) streak
        Elite: INVITE ONLY — never auto-upgrade
        """
        changed = False
        if self.membership == 'guest' and self.sessions_played > 0:
            self.membership = 'pre_member'
            changed = True
        if self.membership == 'pre_member' and self.total_games >= 5 and self.membership_paid:
            self.membership = 'member'
            if not self.kta_number:
                self.kta_number = f'DPC-{self.id:04d}'
            changed = True
        # Member sub-tiers based on streak weeks
        if self.membership == 'member':
            streak = self.streak_data
            weeks = streak.get('total_weeks', 0)
            old_tier = self.kta_tier
            if weeks >= 26:
                self.kta_tier = 'gold'
            elif weeks >= 12:
                self.kta_tier = 'silver'
            elif weeks >= 4:
                self.kta_tier = 'bronze'
            if self.kta_tier != old_tier:
                changed = True
        # Elite is INVITE ONLY — no auto-upgrade from member
        return changed

    @property
    def member_sub_tier(self):
        """Return Bronze/Silver/Gold label for members."""
        if self.membership != 'member':
            return None
        weeks = self.streak_data.get('total_weeks', 0)
        if weeks >= 26:
            return 'Gold'
        elif weeks >= 12:
            return 'Silver'
        elif weeks >= 4:
            return 'Bronze'
        return None

    @property
    def member_tier_label(self):
        """Full tier display: 'Member Gold' or 'Daddies Elite' or 'Guest'."""
        if self.membership == 'elite':
            return 'Daddies Elite'
        if self.membership == 'member':
            sub = self.member_sub_tier
            return f'Member {sub}' if sub else 'Member'
        return self.membership_label

    def __repr__(self):
        return f'<User {self.username}>'


@login_manager.user_loader
def load_user(id):
    return db.session.get(User, int(id))


class Match(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100))
    date_time = db.Column(db.DateTime, index=True)
    location = db.Column(db.String(100), default='Daddies Court')
    max_players = db.Column(db.Integer, default=4)
    price = db.Column(db.Integer, default=0)
    status = db.Column(db.String(20), default='open')
    notes = db.Column(db.Text, default='')
    created_by = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    bookings = db.relationship('Booking', backref='match', lazy='dynamic')

    creator = db.relationship('User', foreign_keys=[created_by])

    @property
    def confirmed_count(self):
        return self.bookings.filter(Booking.status.in_(['paid', 'confirmed'])).count()

    @property
    def waitlist_count(self):
        return self.bookings.filter_by(status='waitlist').count()

    @property
    def approved_count(self):
        return self.bookings.filter_by(status='approved').count()

    @property
    def all_players(self):
        return [b.player for b in self.bookings.filter(
            Booking.status.in_(['waitlist', 'approved', 'paid', 'confirmed'])
        ).all()]

    def __repr__(self):
        return f'<Match {self.title} {self.date_time}>'


class Booking(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    match_id = db.Column(db.Integer, db.ForeignKey('match.id'))
    status = db.Column(db.String(20), default='waitlist')
    payment_proof = db.Column(db.String(200))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f'<Booking {self.user_id} -> {self.match_id} ({self.status})>'


class Notification(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    title = db.Column(db.String(100))
    body = db.Column(db.String(300))
    icon = db.Column(db.String(50), default='notifications')
    is_read = db.Column(db.Boolean, default=False)
    link = db.Column(db.String(200), default='')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f'<Notification {self.title}>'


class Venue(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100))
    address = db.Column(db.String(200))
    courts = db.Column(db.Integer, default=1)
    phone = db.Column(db.String(20), default='')
    hours = db.Column(db.String(50), default='06:00 - 22:00')
    image_url = db.Column(db.String(300), default='')
    maps_url = db.Column(db.String(300), default='')
    latitude = db.Column(db.Float, nullable=True)
    longitude = db.Column(db.Float, nullable=True)
    price_per_hour = db.Column(db.Integer, default=0)
    notes = db.Column(db.String(300), default='')

    @property
    def maps_navigate_url(self):
        if self.latitude and self.longitude:
            return f'https://www.google.com/maps/dir/?api=1&destination={self.latitude},{self.longitude}'
        return self.maps_url or '#'

    @property
    def osm_embed_url(self):
        if self.latitude and self.longitude:
            lat, lng = self.latitude, self.longitude
            return (f'https://www.openstreetmap.org/export/embed.html'
                    f'?bbox={lng-0.005},{lat-0.003},{lng+0.005},{lat+0.003}'
                    f'&layer=mapnik&marker={lat},{lng}')
        return None

    def __repr__(self):
        return f'<Venue {self.name}>'


class Partner(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100))
    category = db.Column(db.String(50))
    description = db.Column(db.String(300))
    logo_url = db.Column(db.String(300), default='')
    website = db.Column(db.String(200), default='')

    def __repr__(self):
        return f'<Partner {self.name}>'


# ══════════════════════════════════════════════════
# DADDIES CHIPS — Virtual Currency
# ══════════════════════════════════════════════════

class ChipsTransaction(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    amount = db.Column(db.Integer, default=0)  # positive = earn, negative = spend
    balance_after = db.Column(db.Integer, default=0)
    type = db.Column(db.String(30))  # 'tournament_win', 'reward', 'spend', 'bonus', 'admin', 'expired'
    description = db.Column(db.String(200))
    tournament_id = db.Column(db.Integer, db.ForeignKey('tournament.id'), nullable=True)
    season = db.Column(db.String(20), default='')  # e.g. '2026'
    expires_at = db.Column(db.DateTime, nullable=True)  # Season end = chips expire
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    tournament = db.relationship('Tournament', backref='chips_transactions')

    @property
    def is_expired(self):
        return self.expires_at and datetime.utcnow() > self.expires_at

    @property
    def days_until_expiry(self):
        if not self.expires_at:
            return None
        return max(0, (self.expires_at - datetime.utcnow()).days)

    def __repr__(self):
        return f'<Chips {self.user_id} {self.amount:+d}>'


# ── Chips Milestones ──

CHIPS_MILESTONES = [
    {'threshold': 10000,  'title': 'First 10K',     'emoji': '🎯', 'share': 'Pertama kali 10.000 Daddies Chips!'},
    {'threshold': 25000,  'title': 'Quarter Master', 'emoji': '💪', 'share': '25.000 chips — makin dekat jadi legend!'},
    {'threshold': 50000,  'title': 'Half Century',   'emoji': '🔥', 'share': '50.000 chips earned. Half century.'},
    {'threshold': 100000, 'title': 'Chips Legend',    'emoji': '👑', 'share': '100.000 CHIPS. Legend status.'},
]


def check_chips_milestone(user, old_balance, new_balance):
    """Check if user crossed a chips milestone. Returns milestone dict or None."""
    for m in CHIPS_MILESTONES:
        if old_balance < m['threshold'] <= new_balance:
            return m
    return None


# ── Season ──

class Season(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100))  # "Season 1 — Q1 2026"
    start_date = db.Column(db.DateTime)
    end_date = db.Column(db.DateTime)
    status = db.Column(db.String(20), default='active')  # 'upcoming', 'active', 'completed'
    champion_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    champion = db.relationship('User', foreign_keys=[champion_id])

    @property
    def is_active(self):
        now = datetime.utcnow()
        return self.start_date <= now <= self.end_date and self.status == 'active'


# ── Poker Night ──

class PokerNight(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    season_id = db.Column(db.Integer, db.ForeignKey('season.id'), nullable=True)
    name = db.Column(db.String(100), default='Poker Night Grand Final')
    date = db.Column(db.DateTime)
    buy_in_chips = db.Column(db.Integer, default=20000)
    max_participants = db.Column(db.Integer, default=16)
    status = db.Column(db.String(20), default='announced')  # announced, registration, live, completed
    champion_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    season = db.relationship('Season', backref='poker_nights')
    champion = db.relationship('User', foreign_keys=[champion_id])
    registrations = db.relationship('PokerNightRegistration', backref='poker_night', lazy='dynamic')

    @property
    def slots_taken(self):
        return self.registrations.count()

    @property
    def slots_remaining(self):
        return self.max_participants - self.slots_taken

    @property
    def is_full(self):
        return self.slots_taken >= self.max_participants


class PokerNightRegistration(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    poker_night_id = db.Column(db.Integer, db.ForeignKey('poker_night.id'))
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    chips_paid = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref='poker_registrations')


def master_tournament_cascade(tournament):
    """MASTER INTEGRATION FLOW — fires after tournament completion.

    Single input by mimin → everything else is automatic:
    1. Calculate rankings (done by caller)
    2. Award chips per player (top half × 1000 + 500 participation)
    3. Check chips milestones (10K/25K/50K/100K)
    4. Check tier upgrades (pre_member → member → elite)
    5. Update streak data (implicit — streak_data is calculated live)
    6. Generate notifications
    7. Award streak bonus chips (#1 streak = +500/week)

    Returns list of events that occurred (for flash messages / notifications).
    """
    from app.routes.tournament import calculate_leaderboard
    leaderboard = calculate_leaderboard(tournament)
    n = len(leaderboard)
    if n == 0:
        return []

    now = datetime.utcnow()
    season_str = f"{now.year}-{now.strftime('%m')}"
    half = (n + 1) // 2
    events = []

    for rank, entry in enumerate(leaderboard):
        p = entry['participant']
        if not p.user_id:
            continue

        user = db.session.get(User, p.user_id)
        if not user:
            continue

        old_balance = user.chips_balance

        # ── Step 2: Award chips (TOP HALF ONLY per Meeting #2) ──
        # Top half gets: (n - rank) × 1000 chips
        # Bottom half gets: nothing (0 chips)
        # Example: 12 players → #1=12K, #2=11K, ... #6=7K, #7-12=0
        if rank < half:
            rank_amount = (n - rank) * 1000
            user.chips_balance += rank_amount
            db.session.add(ChipsTransaction(
                user_id=user.id, amount=rank_amount,
                balance_after=user.chips_balance,
                type='tournament_win',
                description=f'#{rank+1} di {tournament.name} ({rank_amount:,} chips)',
                tournament_id=tournament.id, season=season_str
            ))

        # ── Step 3: Check chips milestone ──
        milestone = check_chips_milestone(user, old_balance, user.chips_balance)
        if milestone:
            events.append({
                'type': 'chips_milestone',
                'user': user.first_name,
                'milestone': milestone['title'],
                'emoji': milestone['emoji'],
            })
            # Add notification
            db.session.add(Notification(
                user_id=user.id,
                title=f"{milestone['emoji']} {milestone['title']}!",
                body=milestone['share'],
                icon='toll',
            ))

        # ── Step 4: Check tier upgrade ──
        old_membership = user.membership
        if user.check_auto_upgrade():
            events.append({
                'type': 'tier_upgrade',
                'user': user.first_name,
                'old_tier': old_membership,
                'new_tier': user.membership,
            })
            db.session.add(Notification(
                user_id=user.id,
                title=f'Level Up! {user.membership_label}',
                body=f'Selamat! Kamu naik ke {user.membership_label}.',
                icon='verified',
            ))

    # ── Step 7: Streak bonus chips (top 3 streak holders) ──
    all_users = User.query.all()
    streak_ranked = sorted(all_users, key=lambda u: u.streak_data['current'], reverse=True)
    streak_bonuses = [(500, '#1 Streak Bonus'), (300, '#2 Streak Bonus'), (200, '#3 Streak Bonus')]
    for i, (bonus, desc) in enumerate(streak_bonuses):
        if i < len(streak_ranked) and streak_ranked[i].streak_data['current'] >= 4:
            u = streak_ranked[i]
            u.chips_balance += bonus
            db.session.add(ChipsTransaction(
                user_id=u.id, amount=bonus,
                balance_after=u.chips_balance,
                type='bonus',
                description=desc,
                tournament_id=tournament.id, season=season_str
            ))

    # ── Step 8: Monthly champion auto-lock shop item ──
    if n > 0:
        champion = leaderboard[0]['participant']
        if champion.user_id:
            champ_user = db.session.get(User, champion.user_id)
            month_name = now.strftime('%B %Y')
            # Check if champion-only item exists for this month
            existing = ShopItem.query.filter_by(
                name=f'Champion Shirt {month_name}', champion_only=True
            ).first()
            if not existing:
                db.session.add(ShopItem(
                    name=f'Champion Shirt {month_name}',
                    description=f'Exclusive untuk juara {tournament.name}. Hanya {champ_user.display_name if champ_user else champion.name} yang bisa klaim!',
                    price_chips=0, category='exclusive', stock=1,
                    champion_only=True, season=season_str,
                ))
            events.append({
                'type': 'champion',
                'user': champ_user.display_name if champ_user else champion.name,
                'tournament': tournament.name,
            })

    # ── Step 9: Generate post-game QR code for streak claim ──
    # QR link: /tournament/{id}/claim-streak
    events.append({
        'type': 'streak_qr',
        'url': f'/tournament/{tournament.id}/claim-streak',
        'tournament': tournament.name,
    })

    db.session.flush()
    return events


# ══════════════════════════════════════════════════
# FINANCE / KAS — Replace Excel
# ══════════════════════════════════════════════════

class KasTransaction(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    type = db.Column(db.String(10))  # 'income' or 'expense'
    category = db.Column(db.String(50))  # 'sewa_lapangan', 'membership_fee', 'sponsor', 'lain_lain'
    amount = db.Column(db.Integer, default=0)
    description = db.Column(db.String(300))
    receipt_url = db.Column(db.String(300), default='')
    status = db.Column(db.String(20), default='pending')  # 'pending', 'approved', 'rejected'
    created_by = db.Column(db.Integer, db.ForeignKey('user.id'))
    approved_by = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    approved_at = db.Column(db.DateTime, nullable=True)
    match_id = db.Column(db.Integer, db.ForeignKey('match.id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    creator = db.relationship('User', foreign_keys=[created_by], backref='kas_created')
    approver = db.relationship('User', foreign_keys=[approved_by])
    match = db.relationship('Match', backref='kas_transactions')

    KAS_CATEGORIES = {
        'sewa_lapangan': {'label': 'Sewa Lapangan', 'icon': 'sports_tennis', 'color': 'primary'},
        'membership_fee': {'label': 'Iuran Member', 'icon': 'card_membership', 'color': 'success'},
        'sponsor': {'label': 'Sponsor', 'icon': 'handshake', 'color': 'info'},
        'equipment': {'label': 'Peralatan', 'icon': 'sports', 'color': 'warning'},
        'f_and_b': {'label': 'Makan & Minum', 'icon': 'restaurant', 'color': 'tertiary'},
        'lain_lain': {'label': 'Lain-lain', 'icon': 'receipt_long', 'color': 'on-surface-variant'},
    }

    @property
    def category_info(self):
        return self.KAS_CATEGORIES.get(self.category, self.KAS_CATEGORIES['lain_lain'])


# ══════════════════════════════════════════════════
# SPONSOR & PARTNERSHIP
# ══════════════════════════════════════════════════

class SponsorPlacement(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    partner_id = db.Column(db.Integer, db.ForeignKey('partner.id'))
    placement = db.Column(db.String(50))  # 'banner_home', 'banner_session', 'tournament_sponsor'
    start_date = db.Column(db.DateTime)
    end_date = db.Column(db.DateTime)
    impressions = db.Column(db.Integer, default=0)
    clicks = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)

    partner = db.relationship('Partner', backref='placements')

    @property
    def ctr(self):
        return (self.clicks / self.impressions * 100) if self.impressions > 0 else 0


# ══════════════════════════════════════════════════
# CHIPS SHOP & REWARDS
# ══════════════════════════════════════════════════

class ShopItem(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100))
    description = db.Column(db.String(300))
    price_chips = db.Column(db.Integer, default=0)
    category = db.Column(db.String(30))  # 'merchandise', 'voucher', 'exclusive', 'collectible'
    image_url = db.Column(db.String(300), default='')
    stock = db.Column(db.Integer, default=-1)  # -1 = unlimited
    is_active = db.Column(db.Boolean, default=True)
    champion_only = db.Column(db.Boolean, default=False)
    season = db.Column(db.String(20), default='')  # e.g. '2026-03' for March collectible
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    @property
    def in_stock(self):
        return self.stock == -1 or self.stock > 0

    @property
    def category_label(self):
        labels = {'merchandise': 'Merch', 'voucher': 'Voucher', 'exclusive': 'Exclusive', 'collectible': 'Collectible'}
        return labels.get(self.category, self.category)


class ShopOrder(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    item_id = db.Column(db.Integer, db.ForeignKey('shop_item.id'))
    chips_spent = db.Column(db.Integer, default=0)
    status = db.Column(db.String(20), default='pending')  # 'pending', 'fulfilled', 'canceled'
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref='shop_orders')
    item = db.relationship('ShopItem', backref='orders')


# ══════════════════════════════════════════════════
# TOURNAMENT SYSTEM — Americano Padel Clone
# ══════════════════════════════════════════════════

TOURNAMENT_FORMATS = {
    'americano':      {'label': 'Americano',       'icon': 'sports_tennis', 'color': 'success', 'desc': 'Round-robin klasik — tiap pemain partner dgn semua'},
    'mix_americano':  {'label': 'Mix Americano',   'icon': 'people',        'color': 'error',   'desc': 'Pasangan Pria + Wanita'},
    'team_americano': {'label': 'Team Americano',  'icon': 'groups',        'color': 'success', 'desc': 'Tim tetap round-robin'},
    'mexicano':       {'label': 'Mexicano',        'icon': 'emoji_events',  'color': 'warning', 'desc': 'Pemenang lawan pemenang — dinamis'},
    'team_mexicano':  {'label': 'Team Mexicano',   'icon': 'group_work',    'color': 'warning', 'desc': 'Mexicano berbasis tim'},
    'super_mexicano': {'label': 'Super Mexicano',  'icon': 'bolt',          'color': 'warning', 'desc': 'Lebih court, lebih seru'},
    'mixicano':       {'label': 'Mixicano',        'icon': 'swap_horiz',    'color': 'error',   'desc': 'Re-pairing berbasis gender'},
    'beatbox':        {'label': 'Beat the Box',    'icon': 'grid_view',     'color': 'info',    'desc': 'Grup lalu skill-matched courts'},
    'groups':         {'label': 'Groups',          'icon': 'view_module',   'color': 'info',    'desc': 'Babak grup lalu playoff'},
    'groups_team':    {'label': 'Groups Team',     'icon': 'view_column',   'color': 'info',    'desc': 'Grup berbasis tim'},
    'doubles':        {'label': 'Doubles',         'icon': 'all_inclusive', 'color': 'success', 'desc': 'Format doubles unlimited'},
    'club_team':      {'label': 'Club Team',       'icon': 'business',      'color': 'error',   'desc': 'Format tim antar klub'},
    'club_americano': {'label': 'Club Americano',  'icon': 'storefront',    'color': 'error',   'desc': 'Americano antar klub'},
    'club_mexicano':  {'label': 'Club Mexicano',   'icon': 'store',         'color': 'error',   'desc': 'Mexicano antar klub'},
}


class Tournament(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100))
    date = db.Column(db.DateTime, index=True, default=datetime.utcnow)
    status = db.Column(db.String(20), default='draft')  # draft, open, playing, completed
    format = db.Column(db.String(30), default='americano')
    venue = db.Column(db.String(100), default='Daddies Court')
    num_courts = db.Column(db.Integer, default=2)
    scoring_mode = db.Column(db.String(10), default='points')  # 'points' (Americano standard) or 'sets'
    points_per_game = db.Column(db.Integer, default=21)  # for points mode
    win_points = db.Column(db.Integer, default=3)
    draw_points = db.Column(db.Integer, default=1)
    loss_points = db.Column(db.Integer, default=0)
    minutes_to_play = db.Column(db.Integer, default=0)  # 0 = no timer
    court_bonus_round = db.Column(db.Integer, default=0)
    sort_by_wins = db.Column(db.Boolean, default=True)
    h2h_tiebreaker = db.Column(db.Boolean, default=False)
    current_round = db.Column(db.Integer, default=0)
    created_by = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    participants = db.relationship('TournamentParticipant', backref='tournament', lazy='dynamic')
    rounds = db.relationship('TournamentRound', backref='tournament', lazy='dynamic',
                             order_by='TournamentRound.round_number')

    creator = db.relationship('User', foreign_keys=[created_by])

    @property
    def format_info(self):
        return TOURNAMENT_FORMATS.get(self.format, TOURNAMENT_FORMATS['americano'])

    @property
    def format_label(self):
        return self.format_info['label']

    @property
    def format_icon(self):
        return self.format_info['icon']

    @property
    def format_color(self):
        return self.format_info['color']

    @property
    def all_matches(self):
        matches = []
        for r in self.rounds:
            matches.extend(r.matches.all())
        return matches

    @property
    def total_rounds(self):
        return self.rounds.count()

    @property
    def completed_matches(self):
        return sum(1 for m in self.all_matches if m.status == 'completed')

    def __repr__(self):
        return f'<Tournament {self.name}>'


class TournamentParticipant(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    tournament_id = db.Column(db.Integer, db.ForeignKey('tournament.id'))
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    name = db.Column(db.String(64))
    gender = db.Column(db.String(10), default='')  # 'M', 'F', or ''
    seed = db.Column(db.Integer, default=0)
    sitting_out_permanent = db.Column(db.Boolean, default=False)  # "pulang" — permanent sit-out

    user = db.relationship('User', backref='tournament_participations')

    @property
    def initials(self):
        parts = (self.name or '??').split()
        if len(parts) >= 2:
            return (parts[0][0] + parts[1][0]).upper()
        return (self.name[:2] if self.name else '??').upper()

    @property
    def first_name(self):
        return (self.name or '').split()[0]

    def __repr__(self):
        return f'<Participant {self.name}>'


class TournamentRound(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    tournament_id = db.Column(db.Integer, db.ForeignKey('tournament.id'))
    round_number = db.Column(db.Integer)
    matches = db.relationship('TournamentMatch', backref='round', lazy='dynamic')

    @property
    def total_matches(self):
        return self.matches.count()

    @property
    def completed_count(self):
        return self.matches.filter_by(status='completed').count()

    @property
    def pending_count(self):
        return self.matches.filter_by(status='pending').count()

    @property
    def is_complete(self):
        return self.pending_count == 0 and self.total_matches > 0

    def __repr__(self):
        return f'<Round {self.round_number}>'


class TournamentMatch(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    tournament_id = db.Column(db.Integer, db.ForeignKey('tournament.id'))
    round_id = db.Column(db.Integer, db.ForeignKey('tournament_round.id'))
    court = db.Column(db.Integer, default=1)  # court number
    status = db.Column(db.String(20), default='pending')  # pending, completed, canceled

    # Teams: 2 players per team
    team1_p1_id = db.Column(db.Integer, db.ForeignKey('tournament_participant.id'))
    team1_p2_id = db.Column(db.Integer, db.ForeignKey('tournament_participant.id'))
    team2_p1_id = db.Column(db.Integer, db.ForeignKey('tournament_participant.id'))
    team2_p2_id = db.Column(db.Integer, db.ForeignKey('tournament_participant.id'))

    # Set scores stored as JSON: [[6,4],[7,5],[3,2]]
    sets_json = db.Column(db.Text, default='[]')

    team1_p1 = db.relationship('TournamentParticipant', foreign_keys=[team1_p1_id])
    team1_p2 = db.relationship('TournamentParticipant', foreign_keys=[team1_p2_id])
    team2_p1 = db.relationship('TournamentParticipant', foreign_keys=[team2_p1_id])
    team2_p2 = db.relationship('TournamentParticipant', foreign_keys=[team2_p2_id])

    @property
    def sets(self):
        try:
            return json.loads(self.sets_json or '[]')
        except (json.JSONDecodeError, TypeError):
            return []

    @sets.setter
    def sets(self, value):
        self.sets_json = json.dumps(value)

    @property
    def score_team1(self):
        """Total games won by team 1 across all sets."""
        return sum(s[0] for s in self.sets if len(s) == 2)

    @property
    def score_team2(self):
        """Total games won by team 2 across all sets."""
        return sum(s[1] for s in self.sets if len(s) == 2)

    @property
    def sets_won_team1(self):
        return sum(1 for s in self.sets if len(s) == 2 and s[0] > s[1])

    @property
    def sets_won_team2(self):
        return sum(1 for s in self.sets if len(s) == 2 and s[1] > s[0])

    @property
    def winner(self):
        """'team1', 'team2', 'draw', or None if not completed."""
        if self.status != 'completed':
            return None
        s1, s2 = self.sets_won_team1, self.sets_won_team2
        if s1 > s2:
            return 'team1'
        elif s2 > s1:
            return 'team2'
        # Tiebreak by total games
        g1, g2 = self.score_team1, self.score_team2
        if g1 > g2:
            return 'team1'
        elif g2 > g1:
            return 'team2'
        return 'draw'

    @property
    def score_display(self):
        """e.g. '6-4, 7-5'"""
        return ', '.join(f'{s[0]}-{s[1]}' for s in self.sets if len(s) == 2)

    @property
    def all_players(self):
        return [self.team1_p1, self.team1_p2, self.team2_p1, self.team2_p2]

    def __repr__(self):
        return f'<TMatch R{self.round.round_number if self.round else "?"} C{self.court}>'


# ── Playoff ──

class TournamentPlayoff(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    tournament_id = db.Column(db.Integer, db.ForeignKey('tournament.id'))
    bracket_round = db.Column(db.Integer, default=1)  # 1=semi, 2=final
    match_index = db.Column(db.Integer, default=0)

    team1_p1_id = db.Column(db.Integer, db.ForeignKey('tournament_participant.id'), nullable=True)
    team1_p2_id = db.Column(db.Integer, db.ForeignKey('tournament_participant.id'), nullable=True)
    team2_p1_id = db.Column(db.Integer, db.ForeignKey('tournament_participant.id'), nullable=True)
    team2_p2_id = db.Column(db.Integer, db.ForeignKey('tournament_participant.id'), nullable=True)

    sets_json = db.Column(db.Text, default='[]')
    status = db.Column(db.String(20), default='pending')

    team1_p1 = db.relationship('TournamentParticipant', foreign_keys=[team1_p1_id])
    team1_p2 = db.relationship('TournamentParticipant', foreign_keys=[team1_p2_id])
    team2_p1 = db.relationship('TournamentParticipant', foreign_keys=[team2_p1_id])
    team2_p2 = db.relationship('TournamentParticipant', foreign_keys=[team2_p2_id])

    tournament = db.relationship('Tournament', backref=db.backref('playoffs', lazy='dynamic'))

    @property
    def sets(self):
        try:
            return json.loads(self.sets_json or '[]')
        except (json.JSONDecodeError, TypeError):
            return []

    @property
    def score_team1(self):
        return sum(s[0] for s in self.sets if len(s) == 2)

    @property
    def score_team2(self):
        return sum(s[1] for s in self.sets if len(s) == 2)

    @property
    def score_display(self):
        return ', '.join(f'{s[0]}-{s[1]}' for s in self.sets if len(s) == 2)

    @property
    def winner(self):
        if self.status != 'completed':
            return None
        s1 = sum(1 for s in self.sets if len(s) == 2 and s[0] > s[1])
        s2 = sum(1 for s in self.sets if len(s) == 2 and s[1] > s[0])
        if s1 > s2:
            return 'team1'
        elif s2 > s1:
            return 'team2'
        g1 = sum(s[0] for s in self.sets if len(s) == 2)
        g2 = sum(s[1] for s in self.sets if len(s) == 2)
        return 'team1' if g1 >= g2 else 'team2'
