"""Seed demo data for local development."""
from app import create_app
from app.extensions import db
from app.models import (
    User, Match, Booking, Venue, Partner, Notification, ChipsTransaction,
    KasTransaction, SponsorPlacement, ShopItem, Season, PokerNight, PokerNightRegistration,
    Tournament, TournamentParticipant, TournamentRound, TournamentMatch
)
from datetime import datetime, timedelta
import json

app = create_app()

with app.app_context():
    # Drop and recreate
    db.drop_all()
    db.create_all()

    # ── Users ──
    users = []
    user_data = [
        ('Reza Rahardian', 'reza@daddiespadel.com', '08119990001', 'admin', 'gold', 250),
        ('Hendy Kurniawan', 'hendy@daddiespadel.com', '08119990002', 'admin', 'silver', 180),
        ('Bima Arya', 'bima@daddiespadel.com', '08119990003', 'admin', 'silver', 150),
        ('Fajar Nugroho', 'fajar@daddiespadel.com', '08119990004', 'treasurer', 'bronze', 90),
        ('Arif Wicaksono', 'arif@daddiespadel.com', '08129990005', 'member', 'bronze', 60),
        ('Dimas Pratama', 'dimas@daddiespadel.com', '08129990006', 'member', 'silver', 120),
        ('Randi Saputra', 'randi@daddiespadel.com', '08129990007', 'member', 'bronze', 45),
        ('Tommy Wijaya', 'tommy@daddiespadel.com', '08129990008', 'member', 'bronze', 30),
    ]
    for name, email, phone, role, tier, chips in user_data:
        u = User(
            username=name, email=email, phone=phone, role=role,
            kta_tier=tier, chips_balance=chips,
            kta_number=f'DPC-{len(users)+1:04d}',
            referral_code=f'DPC{len(users)+1:04d}',
            created_at=datetime.now() - timedelta(days=90 + len(users) * 15),
        )
        u.set_password('daddies')
        db.session.add(u)
        users.append(u)

    db.session.commit()

    # ── Venues ──
    venues = [
        Venue(name='Daddies Court', address='Jl. Kertajaya Indah No.12, Surabaya',
              courts=2, phone='031-5912345', hours='06:00 - 22:00',
              latitude=-7.2756, longitude=112.7842, price_per_hour=150000,
              notes='Home court Daddies. Parkir luas, ada kantin.'),
        Venue(name='GBK Padel Arena', address='Jl. Raya Darmo Permai III, Surabaya',
              courts=4, phone='031-7345678', hours='07:00 - 21:00',
              latitude=-7.2920, longitude=112.7132, price_per_hour=175000,
              notes='4 court indoor, AC, cafe area.'),
        Venue(name='The Padel Club', address='Jl. Mayjend Sungkono No.89, Surabaya',
              courts=3, phone='031-5678901', hours='06:00 - 23:00',
              latitude=-7.2890, longitude=112.7245, price_per_hour=200000,
              notes='Premium venue. Locker room, shower, pro shop.'),
    ]
    for v in venues:
        db.session.add(v)

    # ── Partners ──
    partners = [
        Partner(name='Head Padel', category='equipment',
                description='Official racket partner — diskon 15% untuk anggota'),
        Partner(name='Nike Court', category='apparel',
                description='Apparel sponsor — jersey exclusive Daddies'),
        Partner(name='Kopi Kenangan', category='f&b',
                description='Minuman gratis setelah sesi main'),
        Partner(name='Flex Wellness', category='wellness',
                description='Recovery & sports massage — diskon 20%'),
    ]
    for p in partners:
        db.session.add(p)

    # ── Matches ──
    now = datetime.now()
    matches = [
        Match(title='Tuesday Night Grind', date_time=now + timedelta(days=2),
              location='Daddies Court', max_players=4, price=75000, status='open',
              created_by=users[0].id),
        Match(title='Weekend Warriors', date_time=now + timedelta(days=5),
              location='GBK Padel Arena', max_players=8, price=100000, status='open',
              created_by=users[0].id),
        Match(title='Friday Sunset Session', date_time=now + timedelta(days=3),
              location='Daddies Court', max_players=4, price=75000, status='open',
              created_by=users[1].id),
        Match(title='Morning Drill', date_time=now - timedelta(days=3),
              location='Daddies Court', max_players=4, price=75000, status='completed',
              created_by=users[0].id),
        Match(title='Rabu Sore Special', date_time=now - timedelta(days=7),
              location='The Padel Club', max_players=4, price=85000, status='completed',
              created_by=users[1].id),
    ]
    for m in matches:
        db.session.add(m)

    # ── Bookings ──
    booking_data = [
        (users[0], matches[0], 'confirmed'),
        (users[1], matches[0], 'confirmed'),
        (users[4], matches[0], 'approved'),
        (users[5], matches[0], 'waitlist'),
        (users[2], matches[1], 'confirmed'),
        (users[3], matches[1], 'paid'),
        (users[6], matches[1], 'waitlist'),
        (users[7], matches[1], 'waitlist'),
        (users[0], matches[2], 'confirmed'),
        (users[5], matches[2], 'approved'),
        (users[0], matches[3], 'confirmed'),
        (users[1], matches[3], 'confirmed'),
        (users[4], matches[3], 'confirmed'),
        (users[5], matches[3], 'confirmed'),
        (users[6], matches[3], 'confirmed'),
        (users[7], matches[3], 'confirmed'),
        (users[2], matches[4], 'confirmed'),
        (users[3], matches[4], 'confirmed'),
        (users[6], matches[4], 'confirmed'),
        (users[7], matches[4], 'confirmed'),
    ]
    for user, match, status in booking_data:
        db.session.add(Booking(user_id=user.id, match_id=match.id, status=status))

    # ── Notifications ──
    notifs = [
        Notification(user_id=users[0].id, title='Sesi Baru Dibuat',
                     body='Weekend Warriors — Sabtu, GBK Padel Arena', icon='event'),
        Notification(user_id=users[0].id, title='Pembayaran Diterima',
                     body='Morning Drill — status confirmed', icon='payments', is_read=True),
        Notification(user_id=users[4].id, title='Kamu Di-approve!',
                     body='Tuesday Night Grind — upload bukti bayar', icon='check_circle'),
    ]
    for n in notifs:
        db.session.add(n)

    db.session.commit()

    # ══════════════════════════════════════════════════
    # TOURNAMENT — Americano with 8 players, 3 rounds, real scores
    # ══════════════════════════════════════════════════

    tournament = Tournament(
        name='Americano Tuesday Night',
        date=now + timedelta(days=2),
        format='americano',
        venue='Daddies Court',
        num_courts=2,
        scoring_mode='points',
        points_per_game=21,
        win_points=3,
        draw_points=1,
        loss_points=0,
        current_round=3,
        status='playing',
        sort_by_wins=True,
        created_by=users[0].id
    )
    db.session.add(tournament)
    db.session.flush()

    # Add 8 participants
    participants = []
    for i in range(8):
        user = users[i]
        p = TournamentParticipant(
            tournament_id=tournament.id,
            user_id=user.id,
            name=user.username,
            seed=i + 1
        )
        db.session.add(p)
        participants.append(p)
    db.session.flush()

    # Round 1: 2 matches (Court 1 + Court 2)
    r1 = TournamentRound(tournament_id=tournament.id, round_number=1)
    db.session.add(r1)
    db.session.flush()

    m1 = TournamentMatch(
        tournament_id=tournament.id, round_id=r1.id, court=1,
        team1_p1_id=participants[0].id, team1_p2_id=participants[7].id,  # Reza & Tommy
        team2_p1_id=participants[3].id, team2_p2_id=participants[4].id,  # Fajar & Arif
        sets_json=json.dumps([[15, 9]]),
        status='completed'
    )
    db.session.add(m1)

    m2 = TournamentMatch(
        tournament_id=tournament.id, round_id=r1.id, court=2,
        team1_p1_id=participants[1].id, team1_p2_id=participants[6].id,  # Hendy & Randi
        team2_p1_id=participants[2].id, team2_p2_id=participants[5].id,  # Bima & Dimas
        sets_json=json.dumps([[17, 14]]),
        status='completed'
    )
    db.session.add(m2)

    # Round 2
    r2 = TournamentRound(tournament_id=tournament.id, round_number=2)
    db.session.add(r2)
    db.session.flush()

    m3 = TournamentMatch(
        tournament_id=tournament.id, round_id=r2.id, court=1,
        team1_p1_id=participants[0].id, team1_p2_id=participants[5].id,  # Reza & Dimas
        team2_p1_id=participants[1].id, team2_p2_id=participants[4].id,  # Hendy & Arif
        sets_json=json.dumps([[12, 7]]),
        status='completed'
    )
    db.session.add(m3)

    m4 = TournamentMatch(
        tournament_id=tournament.id, round_id=r2.id, court=2,
        team1_p1_id=participants[2].id, team1_p2_id=participants[7].id,  # Bima & Tommy
        team2_p1_id=participants[3].id, team2_p2_id=participants[6].id,  # Fajar & Randi
        sets_json=json.dumps([[17, 13]]),
        status='completed'
    )
    db.session.add(m4)

    # Round 3 — 1 match completed, 1 pending
    r3 = TournamentRound(tournament_id=tournament.id, round_number=3)
    db.session.add(r3)
    db.session.flush()

    m5 = TournamentMatch(
        tournament_id=tournament.id, round_id=r3.id, court=1,
        team1_p1_id=participants[0].id, team1_p2_id=participants[3].id,  # Reza & Fajar
        team2_p1_id=participants[2].id, team2_p2_id=participants[6].id,  # Bima & Randi
        sets_json=json.dumps([[17, 14]]),
        status='completed'
    )
    db.session.add(m5)

    m6 = TournamentMatch(
        tournament_id=tournament.id, round_id=r3.id, court=2,
        team1_p1_id=participants[1].id, team1_p2_id=participants[5].id,  # Hendy & Dimas
        team2_p1_id=participants[4].id, team2_p2_id=participants[7].id,  # Arif & Tommy
        status='pending'  # Not yet played
    )
    db.session.add(m6)

    # Also add a completed tournament
    t2 = Tournament(
        name='Mexicano Weekend Cup',
        date=now - timedelta(days=7),
        format='mexicano',
        venue='GBK Padel Arena',
        num_courts=2,
        status='completed',
        created_by=users[1].id
    )
    db.session.add(t2)
    db.session.flush()

    # Add 4 participants to completed tournament
    for i in range(4):
        p = TournamentParticipant(
            tournament_id=t2.id, user_id=users[i].id,
            name=users[i].username, seed=i+1
        )
        db.session.add(p)

    db.session.commit()

    # ── Daddies Chips (seed some history) ──
    chip_data = [
        (users[0], 8000, 'tournament_win', '#1 di Weekend Cup', 8000),
        (users[0], 500, 'tournament_participation', 'Partisipasi: Weekend Cup', 8500),
        (users[1], 7000, 'tournament_win', '#2 di Weekend Cup', 7000),
        (users[1], 500, 'tournament_participation', 'Partisipasi: Weekend Cup', 7500),
        (users[2], 6000, 'tournament_win', '#3 di Weekend Cup', 6000),
        (users[2], 500, 'tournament_participation', 'Partisipasi: Weekend Cup', 6500),
        (users[3], 500, 'tournament_participation', 'Partisipasi: Weekend Cup', 500),
        (users[4], 5000, 'tournament_win', '#4 di Friday Grind', 5000),
        (users[4], 500, 'tournament_participation', 'Partisipasi: Friday Grind', 5500),
        (users[5], 4000, 'tournament_win', '#2 di Friday Grind', 4000),
        (users[5], 500, 'tournament_participation', 'Partisipasi: Friday Grind', 4500),
        (users[6], 500, 'tournament_participation', 'Partisipasi: Friday Grind', 500),
        (users[7], 500, 'tournament_participation', 'Partisipasi: Friday Grind', 500),
    ]
    for user, amount, tx_type, desc, balance in chip_data:
        user.chips_balance = balance
        db.session.add(ChipsTransaction(
            user_id=user.id, amount=amount, balance_after=balance,
            type=tx_type, description=desc, season='2026-03'
        ))
    db.session.commit()

    # ── Set membership tiers ──
    users[0].membership = 'elite'   # Reza - admin, 8500 chips, elite
    users[0].kta_tier = 'gold'
    users[1].membership = 'member'  # Hendy
    users[2].membership = 'member'  # Bima
    users[3].membership = 'member'  # Fajar
    users[4].membership = 'pre_member'  # Arif
    users[5].membership = 'pre_member'  # Dimas
    users[6].membership = 'guest'   # Randi
    users[7].membership = 'guest'   # Tommy
    for u in users[:4]:
        u.membership_paid = True
    db.session.commit()

    # ── Kas Transactions ──
    kas_data = [
        ('income', 'membership_fee', 800000, 'Iuran member Maret 2026 (8 orang)', users[3].id),
        ('expense', 'sewa_lapangan', 300000, 'Sewa Daddies Court - Selasa 18 Mar', users[0].id),
        ('expense', 'sewa_lapangan', 300000, 'Sewa Daddies Court - Selasa 25 Mar', users[0].id),
        ('income', 'sponsor', 500000, 'Sponsor Head Padel - Maret', users[0].id),
        ('expense', 'f_and_b', 150000, 'Minum post-game 18 Mar', users[3].id),
        ('expense', 'equipment', 200000, 'Bola padel 2 tube', users[1].id),
    ]
    for tx_type, cat, amt, desc, creator in kas_data:
        tx = KasTransaction(type=tx_type, category=cat, amount=amt,
                           description=desc, created_by=creator, status='approved',
                           approved_by=users[0].id if creator != users[0].id else users[3].id,
                           approved_at=now)
        db.session.add(tx)

    # One pending for demo
    db.session.add(KasTransaction(
        type='expense', category='lain_lain', amount=75000,
        description='Cetak banner turnamen', created_by=users[1].id, status='pending'
    ))
    db.session.commit()

    # ── Sponsor Placements ──
    sp_data = [
        (partners[0].id, 'banner_home', 1250, 45),    # Head Padel
        (partners[1].id, 'banner_session', 890, 32),   # Nike Court
        (partners[2].id, 'tournament_sponsor', 650, 18), # Kopi Kenangan
    ]
    for pid, placement, impr, clicks in sp_data:
        db.session.add(SponsorPlacement(
            partner_id=pid, placement=placement,
            start_date=now - timedelta(days=30), end_date=now + timedelta(days=60),
            impressions=impr, clicks=clicks, is_active=True
        ))
    db.session.commit()

    # ── Shop Items ──
    shop_items = [
        # Merchandise
        ('Kaos Daddies Classic', 'Jersey hitam-hijau official Daddies dengan bordir fox mascot', 5000, 'merchandise', 10, False),
        ('Handuk Daddies', 'Handuk olahraga premium bordir logo fox. 100% cotton', 3000, 'merchandise', -1, False),
        ('Topi Daddies Trucker', 'Trucker cap hijau-putih dengan patch fox', 2500, 'merchandise', 15, False),
        ('Celana Padel Daddies', 'Celana pendek dry-fit hitam dengan stripe hijau', 4000, 'merchandise', 8, False),
        ('Grip Overgrip Pack', 'Pack 3 overgrip Head padel warna hijau Daddies', 1500, 'merchandise', 20, False),
        # Voucher
        ('Voucher Kopi Kenangan', 'Free 1 minuman setelah main. Valid di semua outlet', 1500, 'voucher', 20, False),
        ('Diskon Court 50%', 'Potongan 50% sewa court untuk 1 sesi', 4000, 'voucher', 5, False),
        ('Free Entry 1 Sesi', 'Gratis biaya 1 sesi main (senilai IDR 100rb)', 6000, 'voucher', 3, False),
        ('Voucher Flex Wellness', 'Diskon 30% sports massage recovery', 2000, 'voucher', 10, False),
        # Collectible
        ('Sticker Pack Fox Vol.1', 'Set 5 sticker fox mascot — Januari 2026', 500, 'collectible', -1, False),
        ('Sticker Pack Fox Vol.2', 'Set 5 sticker fox mascot — Februari 2026', 500, 'collectible', -1, False),
        ('Sticker Pack Fox Vol.3', 'Set 5 sticker fox mascot — Maret 2026', 500, 'collectible', -1, False),
        ('Pin Fox Enamel', 'Pin enamel fox mascot untuk tas/topi', 1000, 'collectible', 30, False),
        ('Keychain Daddies', 'Gantungan kunci akrilik logo fox', 800, 'collectible', 50, False),
        # Exclusive (Elite only)
        ('Kaos Champion Maret', 'Limited edition — hanya untuk juara bulan ini. Tidak dijual', 8000, 'exclusive', 1, True),
        ('Wristband Elite Gold', 'Gelang silikon gold eksklusif member Elite', 2000, 'exclusive', 5, True),
        ('Poker Chips Set', 'Set poker chips fisik branded Daddies. Collectible premium', 15000, 'exclusive', 3, True),
        ('Racket Bag Daddies', 'Tas raket padel premium dengan bordir nama', 12000, 'exclusive', 2, True),
    ]
    for name, desc, price, cat, stock, champ in shop_items:
        db.session.add(ShopItem(
            name=name, description=desc, price_chips=price,
            category=cat, stock=stock, champion_only=champ,
            season='2026-03', is_active=True
        ))
    db.session.commit()

    # ── Season ──
    season = Season(
        name='Season 1 — Q1 2026',
        start_date=now - timedelta(days=60),
        end_date=now + timedelta(days=30),
        status='active'
    )
    db.session.add(season)
    db.session.flush()

    # ── Poker Night ──
    pn = PokerNight(
        season_id=season.id,
        name='Poker Night Grand Final S1',
        date=now + timedelta(days=30),
        buy_in_chips=20000,
        max_participants=16,
        status='registration'
    )
    db.session.add(pn)
    db.session.flush()

    # Register 3 users
    for u in [users[0], users[1], users[2]]:
        db.session.add(PokerNightRegistration(
            poker_night_id=pn.id, user_id=u.id, chips_paid=20000
        ))
    db.session.commit()

    print('✓ Seeded: 8 users, 5 matches, 18 bookings')
    print('  + 3 venues, 4 partners, 3 notifications')
    print('  + 2 tournaments (1 playing w/ 3 rounds + scores, 1 completed)')
    print('  + Daddies Chips: 13 transactions')
    print('  + Kas: 7 transactions (6 approved, 1 pending)')
    print('  + Sponsor: 3 placements')
    print('  + Shop: 6 items')
    print('  + Season: 1 active + Poker Night (3/16 registered)')
    print('  + Membership: 1 elite, 3 member, 2 pre-member, 2 guest')
    print()
    print('Login credentials (all passwords: "daddies"):')
    for u in users:
        print(f'  {u.email:35s} → {u.role} | {u.membership_label} | {u.chips_balance:,} chips')
    print()
    print(f'Tournament: {tournament.name} (ID: {tournament.id})')
    print(f'Poker Night: {pn.name} (3/16 slots, buy-in 20K chips)')
