"""Main routes — all non-auth pages live here."""
from flask import Blueprint, render_template, redirect, url_for, flash, request
from flask_login import current_user, login_required
from app.models import (
    User, Match, Booking, Notification, Venue, Partner, ChipsTransaction,
    KasTransaction, SponsorPlacement, ShopItem, ShopOrder,
    Season, PokerNight, PokerNightRegistration, CHIPS_MILESTONES
)
from app.extensions import db
from datetime import datetime

bp = Blueprint('main', __name__)


# ─── Explore (public landing) ───

@bp.route('/explore')
def explore():
    upcoming = Match.query.filter(
        Match.date_time > datetime.utcnow(), Match.status == 'open'
    ).order_by(Match.date_time).limit(5).all()
    members_count = User.query.count()
    sessions_count = Match.query.filter_by(status='completed').count()
    return render_template('explore.html', matches=upcoming,
                           members_count=members_count, sessions_count=sessions_count,
                           active_tab='explore')


# ─── Sessions ───

@bp.route('/sessions')
def sessions():
    status_filter = request.args.get('status', 'all')
    q = Match.query.order_by(Match.date_time.desc())
    if status_filter == 'upcoming':
        q = q.filter(Match.date_time > datetime.utcnow(), Match.status.in_(['open', 'full']))
    elif status_filter == 'completed':
        q = q.filter_by(status='completed')
    elif status_filter == 'open':
        q = q.filter_by(status='open')
    matches = q.all()
    user_bookings = {}
    if current_user.is_authenticated:
        bookings = Booking.query.filter_by(user_id=current_user.id).all()
        user_bookings = {b.match_id: b.status for b in bookings}
    return render_template('sessions/list.html', matches=matches,
                           user_bookings=user_bookings, status_filter=status_filter,
                           active_tab='sessions')


@bp.route('/session/<int:match_id>')
def session_detail(match_id):
    match = Match.query.get_or_404(match_id)
    bookings = match.bookings.order_by(Booking.created_at).all()
    user_booking = None
    if current_user.is_authenticated:
        user_booking = Booking.query.filter_by(
            user_id=current_user.id, match_id=match_id).first()
    # Find venue by location name
    venue = Venue.query.filter_by(name=match.location).first()
    return render_template('sessions/detail.html', match=match,
                           bookings=bookings, user_booking=user_booking,
                           venue=venue, active_tab='sessions')


@bp.route('/session/<int:match_id>/edit', methods=['GET', 'POST'])
@login_required
def session_edit(match_id):
    match = Match.query.get_or_404(match_id)
    if request.method == 'POST':
        match.title = request.form['title']
        match.location = request.form['location']
        date_str = request.form['date']
        time_str = request.form['time']
        match.date_time = datetime.strptime(f'{date_str} {time_str}', '%Y-%m-%d %H:%M')
        match.price = int(request.form['price'])
        match.max_players = int(request.form['max_players'])
        match.notes = request.form.get('notes', '')
        db.session.commit()
        flash('Sesi berhasil diupdate!', 'success')
        return redirect(url_for('main.session_detail', match_id=match.id))
    return render_template('sessions/edit.html', match=match, active_tab='sessions')


@bp.route('/history')
@login_required
def session_history():
    bookings = Booking.query.filter_by(user_id=current_user.id)\
        .join(Match).order_by(Match.date_time.desc()).all()
    return render_template('sessions/history.html', bookings=bookings,
                           active_tab='home')


# ─── Members ───

@bp.route('/members')
def members():
    all_members = User.query.order_by(User.username).all()
    return render_template('members/list.html', members=all_members,
                           active_tab='members')


@bp.route('/member/<int:user_id>')
def member_profile(user_id):
    member = User.query.get_or_404(user_id)
    recent_bookings = member.bookings.join(Match)\
        .order_by(Match.date_time.desc()).limit(5).all()
    return render_template('members/profile.html', member=member,
                           recent_bookings=recent_bookings,
                           active_tab='members')


# ─── Profile ───

@bp.route('/profile')
@login_required
def profile():
    recent_bookings = current_user.bookings.join(Match)\
        .order_by(Match.date_time.desc()).limit(5).all()
    return render_template('profile/view.html', user=current_user,
                           recent_bookings=recent_bookings,
                           active_tab='profile')


@bp.route('/profile/edit', methods=['GET', 'POST'])
@login_required
def edit_profile():
    if request.method == 'POST':
        current_user.username = request.form.get('username', current_user.username)
        current_user.nickname = request.form.get('nickname', '')
        current_user.bio = request.form.get('bio', '')
        current_user.phone = request.form.get('phone', current_user.phone)
        db.session.commit()
        flash('Profil berhasil diupdate!', 'success')
        return redirect(url_for('main.profile'))
    return render_template('profile/edit.html', user=current_user,
                           active_tab='profile')


# ─── Leaderboard (tabbed: Chips / Loyalty / Spender) ───

@bp.route('/leaderboard')
def leaderboard():
    tab = request.args.get('tab', 'chips')
    users = User.query.all()

    if tab == 'streak':
        # Sort by current streak
        for u in users:
            u._streak = u.streak_data['current']
        ranked = sorted(users, key=lambda u: u._streak, reverse=True)
    elif tab == 'loyalty':
        # Sort by sessions played
        ranked = sorted(users, key=lambda u: u.sessions_played, reverse=True)
    elif tab == 'spender':
        # Sort by total chips spent (negative transactions)
        spent = {}
        for u in users:
            total_spent = db.session.query(db.func.coalesce(
                db.func.sum(ChipsTransaction.amount), 0
            )).filter(
                ChipsTransaction.user_id == u.id,
                ChipsTransaction.amount < 0
            ).scalar()
            spent[u.id] = abs(total_spent)
        ranked = sorted(users, key=lambda u: spent.get(u.id, 0), reverse=True)
        for u in ranked:
            u._spent = spent.get(u.id, 0)
    else:
        # Default: chips balance
        ranked = sorted(users, key=lambda u: u.chips_balance, reverse=True)

    return render_template('leaderboard.html', ranked=ranked, tab=tab,
                           active_tab='leaderboard')


# ─── Chips History ───

@bp.route('/chips')
@login_required
def chips_history():
    transactions = ChipsTransaction.query.filter_by(user_id=current_user.id)\
        .order_by(ChipsTransaction.created_at.desc()).all()
    # Season expiry info
    from app.models import Season
    active_season = Season.query.filter_by(status='active').first()
    season_end = active_season.end_date if active_season else None
    season_days_left = (season_end - datetime.utcnow()).days if season_end else None
    return render_template('chips.html', transactions=transactions,
                           season_end=season_end, season_days_left=season_days_left,
                           active_tab='profile')


# ─── Notifications ───

@bp.route('/notifications')
@login_required
def notifications():
    notifs = Notification.query.filter_by(user_id=current_user.id)\
        .order_by(Notification.created_at.desc()).all()
    return render_template('notifications.html', notifications=notifs,
                           active_tab='home')


@bp.route('/notifications/read-all', methods=['POST'])
@login_required
def mark_all_read():
    Notification.query.filter_by(user_id=current_user.id, is_read=False)\
        .update({'is_read': True})
    db.session.commit()
    return redirect(url_for('main.notifications'))


# ─── Settings ───

@bp.route('/settings')
@login_required
def settings():
    return render_template('settings.html', active_tab='profile')


# ─── KTA Digital ───

@bp.route('/kta')
@login_required
def kta():
    return render_template('kta.html', user=current_user, active_tab='profile')


# ─── Venues ───

@bp.route('/venues')
def venues():
    all_venues = Venue.query.all()
    return render_template('venues.html', venues=all_venues, active_tab='sessions')


@bp.route('/venue/<int:venue_id>')
def venue_detail(venue_id):
    venue = Venue.query.get_or_404(venue_id)
    sessions_here = Match.query.filter_by(location=venue.name)\
        .order_by(Match.date_time.desc()).limit(5).all()
    return render_template('venue_detail.html', venue=venue,
                           sessions=sessions_here, active_tab='sessions')


# ─── Partners ───

@bp.route('/partners')
def partners():
    all_partners = Partner.query.order_by(Partner.category).all()
    # Group by category
    categories = {}
    for p in all_partners:
        categories.setdefault(p.category, []).append(p)
    return render_template('partners.html', categories=categories,
                           active_tab='explore')


# ─── Referral ───

@bp.route('/referral')
@login_required
def referral():
    referred = User.query.filter_by(referred_by=current_user.id).all()
    return render_template('referral.html', user=current_user,
                           referred=referred, active_tab='profile')


# ══════════════════════════════════════════════════
# FINANCE / KAS
# ══════════════════════════════════════════════════

@bp.route('/kas')
@login_required
def kas_dashboard():
    if current_user.role not in ('admin', 'treasurer'):
        flash('Akses ditolak.', 'error')
        return redirect(url_for('member.index'))

    tab = request.args.get('tab', 'overview')
    transactions = KasTransaction.query.order_by(KasTransaction.created_at.desc()).all()

    total_income = sum(t.amount for t in transactions if t.type == 'income' and t.status == 'approved')
    total_expense = sum(t.amount for t in transactions if t.type == 'expense' and t.status == 'approved')
    saldo = total_income - total_expense
    pending = [t for t in transactions if t.status == 'pending']

    return render_template('kas/dashboard.html',
                           transactions=transactions, tab=tab,
                           total_income=total_income, total_expense=total_expense,
                           saldo=saldo, pending=pending,
                           categories=KasTransaction.KAS_CATEGORIES,
                           active_tab='profile')


@bp.route('/kas/add', methods=['GET', 'POST'])
@login_required
def kas_add():
    if current_user.role not in ('admin', 'treasurer'):
        flash('Akses ditolak.', 'error')
        return redirect(url_for('member.index'))

    if request.method == 'POST':
        tx = KasTransaction(
            type=request.form.get('type', 'expense'),
            category=request.form.get('category', 'lain_lain'),
            amount=int(request.form.get('amount', 0)),
            description=request.form.get('description', ''),
            created_by=current_user.id,
            status='pending'
        )
        db.session.add(tx)
        db.session.commit()
        flash('Transaksi ditambahkan. Menunggu approval.', 'success')
        return redirect(url_for('main.kas_dashboard'))

    return render_template('kas/add.html',
                           categories=KasTransaction.KAS_CATEGORIES,
                           active_tab='profile')


@bp.route('/kas/approve/<int:tx_id>', methods=['POST'])
@login_required
def kas_approve(tx_id):
    if current_user.role not in ('admin', 'treasurer'):
        flash('Akses ditolak.', 'error')
        return redirect(url_for('member.index'))

    tx = KasTransaction.query.get_or_404(tx_id)
    if tx.created_by == current_user.id:
        flash('Tidak bisa approve transaksi sendiri (dual validation).', 'error')
        return redirect(url_for('main.kas_dashboard', tab='pending'))

    action = request.form.get('action')
    if action == 'approve':
        tx.status = 'approved'
        tx.approved_by = current_user.id
        tx.approved_at = datetime.utcnow()
        flash('Transaksi di-approve.', 'success')
    elif action == 'reject':
        tx.status = 'rejected'
        tx.approved_by = current_user.id
        tx.approved_at = datetime.utcnow()
        flash('Transaksi ditolak.', 'info')

    db.session.commit()
    return redirect(url_for('main.kas_dashboard', tab='pending'))


@bp.route('/kas/export')
@login_required
def kas_export():
    """Export kas as CSV download."""
    if current_user.role not in ('admin', 'treasurer'):
        flash('Akses ditolak.', 'error')
        return redirect(url_for('member.index'))

    from flask import Response
    import csv
    import io

    transactions = KasTransaction.query.filter_by(status='approved')\
        .order_by(KasTransaction.created_at).all()

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(['Tanggal', 'Tipe', 'Kategori', 'Jumlah', 'Deskripsi', 'Dibuat Oleh'])
    for tx in transactions:
        writer.writerow([
            tx.created_at.strftime('%Y-%m-%d %H:%M'),
            tx.type.upper(),
            tx.category_info['label'],
            tx.amount,
            tx.description,
            tx.creator.first_name if tx.creator else '-'
        ])

    response = Response(output.getvalue(), mimetype='text/csv')
    response.headers['Content-Disposition'] = f'attachment; filename=kas_daddies_{datetime.now().strftime("%Y%m%d")}.csv'
    return response


# ══════════════════════════════════════════════════
# SPONSOR
# ══════════════════════════════════════════════════

@bp.route('/sponsor')
@login_required
def sponsor_dashboard():
    if current_user.role != 'admin':
        flash('Akses ditolak.', 'error')
        return redirect(url_for('member.index'))

    placements = SponsorPlacement.query.order_by(SponsorPlacement.start_date.desc()).all()
    partners_list = Partner.query.order_by(Partner.name).all()
    total_impressions = sum(p.impressions for p in placements)
    total_clicks = sum(p.clicks for p in placements)

    return render_template('sponsor/dashboard.html',
                           placements=placements, partners=partners_list,
                           total_impressions=total_impressions,
                           total_clicks=total_clicks,
                           active_tab='profile')


@bp.route('/sponsor/add', methods=['POST'])
@login_required
def sponsor_add():
    if current_user.role != 'admin':
        return redirect(url_for('member.index'))

    sp = SponsorPlacement(
        partner_id=int(request.form.get('partner_id')),
        placement=request.form.get('placement', 'banner_home'),
        start_date=datetime.strptime(request.form.get('start_date', ''), '%Y-%m-%d'),
        end_date=datetime.strptime(request.form.get('end_date', ''), '%Y-%m-%d'),
        is_active=True
    )
    db.session.add(sp)
    db.session.commit()
    flash('Sponsor placement ditambahkan.', 'success')
    return redirect(url_for('main.sponsor_dashboard'))


# ══════════════════════════════════════════════════
# CHIPS SHOP
# ══════════════════════════════════════════════════

@bp.route('/shop')
@login_required
def shop():
    items = ShopItem.query.filter_by(is_active=True).order_by(ShopItem.price_chips).all()
    my_orders = ShopOrder.query.filter_by(user_id=current_user.id)\
        .order_by(ShopOrder.created_at.desc()).limit(10).all()
    return render_template('shop/index.html', items=items, orders=my_orders,
                           active_tab='profile')


@bp.route('/shop/buy/<int:item_id>', methods=['POST'])
@login_required
def shop_buy(item_id):
    item = ShopItem.query.get_or_404(item_id)

    if item.champion_only and current_user.membership != 'elite':
        flash('Item ini khusus untuk Elite member.', 'error')
        return redirect(url_for('main.shop'))

    if not item.in_stock:
        flash('Stok habis.', 'error')
        return redirect(url_for('main.shop'))

    if current_user.chips_balance < item.price_chips:
        flash(f'Chips tidak cukup. Butuh {item.price_chips:,}, kamu punya {current_user.chips_balance:,}.', 'error')
        return redirect(url_for('main.shop'))

    # Deduct chips
    current_user.chips_balance -= item.price_chips
    if item.stock > 0:
        item.stock -= 1

    # Record transaction
    db.session.add(ChipsTransaction(
        user_id=current_user.id, amount=-item.price_chips,
        balance_after=current_user.chips_balance,
        type='spend', description=f'Beli: {item.name}',
        season=f"{datetime.utcnow().year}-{datetime.utcnow().strftime('%m')}"
    ))

    # Create order
    db.session.add(ShopOrder(
        user_id=current_user.id, item_id=item.id,
        chips_spent=item.price_chips, status='pending'
    ))

    db.session.commit()
    flash(f'{item.name} berhasil dipesan!', 'success')
    return redirect(url_for('main.shop'))


# ══════════════════════════════════════════════════
# MEMBERSHIP MANAGEMENT
# ══════════════════════════════════════════════════

@bp.route('/membership')
@login_required
def membership():
    return render_template('membership.html', user=current_user, active_tab='profile')


@bp.route('/membership/upgrade', methods=['POST'])
@login_required
def membership_upgrade():
    """Manual trigger for membership check / payment confirmation."""
    current_user.membership_paid = True
    changed = current_user.check_auto_upgrade()
    db.session.commit()
    if changed:
        flash(f'Selamat! Membership kamu naik ke {current_user.membership_label}.', 'success')
    else:
        flash('Pembayaran tercatat. Membership akan upgrade otomatis setelah syarat terpenuhi.', 'info')
    return redirect(url_for('main.membership'))


# ══════════════════════════════════════════════════
# STREAK (Duolingo-inspired)
# ══════════════════════════════════════════════════

STREAK_MILESTONES = [
    {'weeks': 4,  'title': '4',  'subtitle': 'minggu berturut-turut!', 'share': 'Sebulan penuh main padel tanpa skip!', 'tier': 'bronze'},
    {'weeks': 8,  'title': '8',  'subtitle': 'minggu berturut-turut!', 'share': '2 bulan nonstop di court!', 'tier': 'bronze'},
    {'weeks': 12, 'title': '12', 'subtitle': 'minggu berturut-turut!', 'share': '3 bulan streak — padel udah jadi lifestyle!', 'tier': 'silver'},
    {'weeks': 20, 'title': '20', 'subtitle': 'minggu berturut-turut!', 'share': '5 bulan streak! Separuh tahun di court.', 'tier': 'silver'},
    {'weeks': 26, 'title': '26', 'subtitle': 'minggu berturut-turut!', 'share': 'Setengah tahun tanpa bolong. Legend.', 'tier': 'gold'},
    {'weeks': 40, 'title': '40', 'subtitle': 'minggu berturut-turut!', 'share': '40 minggu streak. Gak bisa berhenti.', 'tier': 'gold'},
    {'weeks': 52, 'title': '52', 'subtitle': 'minggu berturut-turut!', 'share': 'SATU TAHUN PENUH. 52 minggu. Tanpa skip.', 'tier': 'diamond'},
]


@bp.route('/streak')
@login_required
def streak():
    data = current_user.streak_data
    # Find current/next milestone
    current_milestone = None
    next_milestone = None
    for m in STREAK_MILESTONES:
        if data['current'] >= m['weeks']:
            current_milestone = m
        elif next_milestone is None:
            next_milestone = m
    return render_template('streak/detail.html', user=current_user,
                           streak=data, milestones=STREAK_MILESTONES,
                           current_milestone=current_milestone,
                           next_milestone=next_milestone,
                           active_tab='profile')


@bp.route('/streak/share')
@login_required
def streak_share_card():
    """Duolingo-style 1080x1080 streak share card."""
    data = current_user.streak_data
    return render_template('streak/share_card.html', user=current_user, streak=data)


@bp.route('/streak/whatsapp')
@login_required
def streak_whatsapp():
    """Share streak to WhatsApp."""
    data = current_user.streak_data
    text = (
        f"Main bareng di Daddies Padel? "
        f"Seru dan bikin ketagihan! "
        f"Aku udah {data['current']} minggu berturut-turut main padel!"
    )
    from urllib.parse import quote
    return redirect(f"https://wa.me/?text={quote(text)}")


@bp.route('/streak/download')
@login_required
def streak_download():
    """Render streak card as PNG."""
    from flask import send_file
    from app.services.card_renderer import render_card, SHARE_DIR
    data = current_user.streak_data
    html = render_template('streak/share_card_raw.html', user=current_user, streak=data)
    image_path = render_card('streak', html)
    if image_path:
        filepath = SHARE_DIR.parent.parent / 'static' / image_path
        return send_file(str(filepath), mimetype='image/png')
    return redirect(url_for('main.streak_share_card'))


# ══════════════════════════════════════════════════
# LEADERBOARD SHARE CARD
# ══════════════════════════════════════════════════

@bp.route('/leaderboard/share')
@login_required
def leaderboard_share_card():
    """540x540 leaderboard share card — dynamic data, DESIGN.md styled."""
    users = User.query.all()
    ranked = sorted(users, key=lambda u: u.chips_balance, reverse=True)

    # Find current user's rank
    my_rank = next((i+1 for i, u in enumerate(ranked) if u.id == current_user.id), 0)

    return render_template('leaderboard_card.html',
                           ranked=ranked[:5], my_rank=my_rank, user=current_user,
                           total_players=len(ranked))


@bp.route('/leaderboard/download')
@login_required
def leaderboard_download():
    """Render leaderboard card as PNG."""
    from flask import send_file
    from app.services.card_renderer import render_card, SHARE_DIR

    users = User.query.all()
    ranked = sorted(users, key=lambda u: u.chips_balance, reverse=True)
    my_rank = next((i+1 for i, u in enumerate(ranked) if u.id == current_user.id), 0)

    html = render_template('leaderboard_card_raw.html',
                           ranked=ranked[:5], my_rank=my_rank, user=current_user,
                           total_players=len(ranked))
    image_path = render_card('leaderboard', html)
    if image_path:
        filepath = SHARE_DIR.parent.parent / 'static' / image_path
        return send_file(str(filepath), mimetype='image/png')
    return redirect(url_for('main.leaderboard_share_card'))


@bp.route('/leaderboard/whatsapp')
@login_required
def leaderboard_whatsapp():
    """Share leaderboard to WhatsApp."""
    users = User.query.all()
    ranked = sorted(users, key=lambda u: u.chips_balance, reverse=True)
    my_rank = next((i+1 for i, u in enumerate(ranked) if u.id == current_user.id), 0)

    medals = ['🥇', '🥈', '🥉']
    lines = ['🏆 *Daddies Padel — Leaderboard*', '📊 Season 2026', '']
    for i, u in enumerate(ranked[:5]):
        medal = medals[i] if i < 3 else f'{i+1}.'
        marker = ' ← kamu!' if u.id == current_user.id else ''
        lines.append(f'{medal} {u.first_name} — {u.chips_balance:,} chips{marker}')

    if my_rank > 5:
        lines.append(f'...\n{my_rank}. {current_user.first_name} — {current_user.chips_balance:,} chips ← kamu!')

    lines.extend(['', f'👥 {len(ranked)} pemain', '', '🎾 Main bareng di Daddies Padel?'])

    from urllib.parse import quote
    return redirect(f"https://wa.me/?text={quote(chr(10).join(lines))}")


@bp.route('/admin/invite', methods=['POST'])
@login_required
def admin_invite():
    """Admin invites a new member by email."""
    if current_user.role != 'admin':
        flash('Akses ditolak.', 'error')
        return redirect(url_for('member.index'))

    email = request.form.get('email', '').strip()
    user = User.query.filter_by(email=email).first()
    if user:
        user.invited_by = current_user.id
        user.membership = 'pre_member'
        db.session.commit()
        flash(f'{user.first_name} diundang sebagai Pre-Member.', 'success')
    else:
        flash(f'User dengan email {email} tidak ditemukan.', 'error')

    return redirect(url_for('main.members'))


# ══════════════════════════════════════════════════
# UNIFIED PROFILE CARD ("Spotify Wrapped")
# ══════════════════════════════════════════════════

@bp.route('/profile/card')
@login_required
def profile_card():
    """1080x1080 shareable profile card — KTA + Rank + Chips + Streak combined."""
    user = current_user
    streak = user.streak_data

    # Get rank
    all_users = User.query.all()
    ranked = sorted(all_users, key=lambda u: u.chips_balance, reverse=True)
    rank = next((i+1 for i, u in enumerate(ranked) if u.id == user.id), 0)

    # Win rate (from bookings)
    total = user.total_games
    wins = user.bookings.filter(Booking.status == 'confirmed').count()  # approximate
    win_rate = int((wins / total * 100) if total > 0 else 0)

    return render_template('profile/card.html', user=user, rank=rank,
                           total_ranked=len(ranked), streak=streak,
                           win_rate=win_rate)


@bp.route('/profile/card/download')
@login_required
def profile_card_download():
    """Render profile card as PNG."""
    from flask import send_file
    from app.services.card_renderer import render_card, SHARE_DIR
    user = current_user
    streak = user.streak_data
    all_users = User.query.all()
    ranked = sorted(all_users, key=lambda u: u.chips_balance, reverse=True)
    rank = next((i+1 for i, u in enumerate(ranked) if u.id == user.id), 0)
    total = user.total_games
    wins = user.bookings.filter(Booking.status == 'confirmed').count()
    win_rate = int((wins / total * 100) if total > 0 else 0)
    html = render_template('profile/card.html', user=user, rank=rank,
                           total_ranked=len(ranked), streak=streak, win_rate=win_rate)
    image_path = render_card('profile', html)
    if image_path:
        filepath = SHARE_DIR.parent.parent / 'static' / image_path
        return send_file(str(filepath), mimetype='image/png')
    return redirect(url_for('main.profile_card'))


@bp.route('/profile/card/whatsapp')
@login_required
def profile_card_whatsapp():
    """Share unified profile to WhatsApp."""
    user = current_user
    streak = user.streak_data
    text = (
        f"🎾 *{user.display_name}* — Daddies Padel\n"
        f"💰 {user.chips_balance:,} chips\n"
        f"🔥 {streak['current']} minggu streak\n"
        f"🏅 {user.membership_label}\n\n"
        f"Main bareng di Daddies Padel?"
    )
    from urllib.parse import quote
    return redirect(f"https://wa.me/?text={quote(text)}")


# ══════════════════════════════════════════════════
# CHIPS MILESTONES
# ══════════════════════════════════════════════════

@bp.route('/chips/milestone/<int:threshold>')
@login_required
def chips_milestone_card(threshold):
    """Shareable milestone celebration card."""
    milestone = next((m for m in CHIPS_MILESTONES if m['threshold'] == threshold), None)
    if not milestone:
        return redirect(url_for('main.chips_history'))
    return render_template('chips_milestone.html', user=current_user, milestone=milestone)


# ══════════════════════════════════════════════════
# POKER NIGHT
# ══════════════════════════════════════════════════

@bp.route('/poker-night')
@login_required
def poker_night():
    event = PokerNight.query.filter(PokerNight.status != 'completed')\
        .order_by(PokerNight.date.desc()).first()
    past_events = PokerNight.query.filter_by(status='completed')\
        .order_by(PokerNight.date.desc()).all()

    user_registered = False
    if event:
        user_registered = PokerNightRegistration.query.filter_by(
            poker_night_id=event.id, user_id=current_user.id
        ).first() is not None

    return render_template('poker_night.html', event=event,
                           past_events=past_events,
                           user_registered=user_registered,
                           active_tab='profile')


@bp.route('/poker-night/register/<int:event_id>', methods=['POST'])
@login_required
def poker_night_register(event_id):
    event = PokerNight.query.get_or_404(event_id)

    if event.is_full:
        flash('Slot penuh!', 'error')
        return redirect(url_for('main.poker_night'))

    if current_user.chips_balance < event.buy_in_chips:
        flash(f'Chips tidak cukup. Butuh {event.buy_in_chips:,}, punya {current_user.chips_balance:,}.', 'error')
        return redirect(url_for('main.poker_night'))

    existing = PokerNightRegistration.query.filter_by(
        poker_night_id=event_id, user_id=current_user.id
    ).first()
    if existing:
        flash('Kamu sudah terdaftar.', 'info')
        return redirect(url_for('main.poker_night'))

    # Deduct chips
    current_user.chips_balance -= event.buy_in_chips
    db.session.add(ChipsTransaction(
        user_id=current_user.id, amount=-event.buy_in_chips,
        balance_after=current_user.chips_balance,
        type='spend', description=f'Buy-in: {event.name}',
        season=f"{datetime.utcnow().year}-{datetime.utcnow().strftime('%m')}"
    ))
    db.session.add(PokerNightRegistration(
        poker_night_id=event_id, user_id=current_user.id,
        chips_paid=event.buy_in_chips
    ))
    db.session.commit()
    flash(f'Terdaftar! {event.slots_remaining} slot tersisa.', 'success')
    return redirect(url_for('main.poker_night'))


# ══════════════════════════════════════════════════
# PAYMENT GATE
# ══════════════════════════════════════════════════

@bp.route('/session/<int:match_id>/join', methods=['POST'])
@login_required
def session_join(match_id):
    """Join a session — with payment gate + unique payment code."""
    match = Match.query.get_or_404(match_id)

    # Payment gate: belum bayar membership gak bisa main
    if not current_user.membership_paid and current_user.membership in ('guest', 'pre_member'):
        flash('Bayar iuran member dulu sebelum bisa join sesi.', 'error')
        return redirect(url_for('main.membership'))

    # Check if already joined
    existing = Booking.query.filter_by(user_id=current_user.id, match_id=match_id).first()
    if existing:
        flash('Kamu sudah join sesi ini.', 'info')
        return redirect(url_for('main.session_detail', match_id=match_id))

    # Check capacity
    if match.confirmed_count >= match.max_players:
        status = 'waitlist'
        flash('Sesi penuh. Kamu masuk waitlist.', 'info')
    else:
        status = 'confirmed'
        flash('Berhasil join! Silakan bayar.', 'success')

    booking = Booking(user_id=current_user.id, match_id=match_id, status=status)
    db.session.add(booking)
    db.session.commit()
    return redirect(url_for('main.session_payment', match_id=match_id))


@bp.route('/session/<int:match_id>/payment')
@login_required
def session_payment(match_id):
    """Show payment QR / transfer info for session booking."""
    match = Match.query.get_or_404(match_id)
    booking = Booking.query.filter_by(user_id=current_user.id, match_id=match_id).first_or_404()
    payment_code = f'DPC-{match_id:03d}-{current_user.id:03d}'
    # QR code URL via qrserver.com API (free, no auth needed)
    bank_info = f'BCA 8720567890 a/n Daddies Padel - Kode: {payment_code}'
    qr_url = f'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data={bank_info}'
    return render_template('sessions/payment.html',
                           match=match, booking=booking,
                           payment_code=payment_code, qr_url=qr_url,
                           bank_info=bank_info)


# ══════════════════════════════════════════════════
# SMART WEEKLY NOTIFICATIONS
# ══════════════════════════════════════════════════

@bp.route('/admin/send-weekly-notifs', methods=['POST'])
@login_required
def send_weekly_notifs():
    """Admin trigger: generate weekly rank notifications for all users."""
    if current_user.role != 'admin':
        flash('Akses ditolak.', 'error')
        return redirect(url_for('member.index'))

    users = User.query.all()
    ranked = sorted(users, key=lambda u: u.chips_balance, reverse=True)

    count = 0
    for i, user in enumerate(ranked):
        rank = i + 1
        if user.chips_balance == 0:
            continue

        # Generate high-arousal notification
        if rank <= 3:
            title = f'🔥 Kamu #{rank}!'
            body = f'{user.chips_balance:,} chips. Pertahankan posisi di Sabtu ini!'
        elif i > 0 and ranked[i-1].chips_balance - user.chips_balance < 2000:
            rival = ranked[i-1].first_name
            gap = ranked[i-1].chips_balance - user.chips_balance
            title = f'📊 Cuma {gap:,} chips dari #{rank-1}'
            body = f'{rival} di atas kamu. 1 kali menang lagi!'
        else:
            title = f'📊 Ranking kamu: #{rank}'
            body = f'{user.chips_balance:,} chips minggu ini. Main Sabtu untuk naik!'

        db.session.add(Notification(
            user_id=user.id, title=title, body=body, icon='leaderboard'
        ))
        count += 1

    db.session.commit()
    flash(f'Notifikasi terkirim ke {count} member.', 'success')
    return redirect(url_for('main.members'))


# ══════════════════════════════════════════════════
# SEASON MANAGEMENT (Meeting #2)
# ══════════════════════════════════════════════════

@bp.route('/admin/season', methods=['GET', 'POST'])
@login_required
def manage_season():
    """Admin: manage seasons — start/end/archive."""
    if current_user.role != 'admin':
        flash('Akses ditolak.', 'error')
        return redirect(url_for('member.index'))

    from app.models import Season
    seasons = Season.query.order_by(Season.start_date.desc()).all()

    if request.method == 'POST':
        action = request.form.get('action')
        if action == 'create':
            name = request.form.get('name', f'Season {len(seasons)+1}')
            start = datetime.strptime(request.form.get('start_date', datetime.utcnow().strftime('%Y-%m-%d')), '%Y-%m-%d')
            end = datetime.strptime(request.form.get('end_date', (datetime.utcnow().replace(month=12, day=31)).strftime('%Y-%m-%d')), '%Y-%m-%d')
            s = Season(name=name, start_date=start, end_date=end, status='active')
            db.session.add(s)
            db.session.commit()
            flash(f'Season "{name}" dimulai!', 'success')
        elif action == 'end':
            sid = request.form.get('season_id', type=int)
            season = Season.query.get(sid)
            if season:
                season.status = 'completed'
                # Expire all chips for this season
                users = User.query.filter(User.chips_balance > 0).all()
                for user in users:
                    if user.chips_balance > 0:
                        expired_amount = user.chips_balance
                        user.chips_balance = 0
                        db.session.add(ChipsTransaction(
                            user_id=user.id, amount=-expired_amount,
                            balance_after=0, type='expired',
                            description=f'Season expired: {season.name}',
                            season=season.name
                        ))
                db.session.commit()
                flash(f'Season "{season.name}" selesai. Semua chips di-reset.', 'success')
        return redirect(url_for('main.manage_season'))

    return render_template('admin/season.html', seasons=seasons)


@bp.route('/admin/invite-elite', methods=['GET', 'POST'])
@login_required
def invite_elite():
    """Admin: invite a member to Elite tier (by invitation only)."""
    if current_user.role != 'admin':
        flash('Akses ditolak.', 'error')
        return redirect(url_for('member.index'))

    if request.method == 'POST':
        user_id = request.form.get('user_id', type=int)
        user = User.query.get(user_id)
        if user and user.membership == 'member':
            user.membership = 'elite'
            user.kta_tier = 'platinum'
            db.session.add(Notification(
                user_id=user.id,
                title='👑 Selamat! Kamu diundang ke Daddies Elite',
                body='Club manager mengundang kamu ke tier Elite. Selamat bergabung!',
                icon='military_tech',
            ))
            db.session.commit()
            flash(f'{user.display_name} sekarang Daddies Elite!', 'success')
        else:
            flash('User tidak ditemukan atau belum Member.', 'error')
        return redirect(url_for('main.invite_elite'))

    members = User.query.filter_by(membership='member').all()
    elites = User.query.filter_by(membership='elite').all()
    return render_template('admin/invite_elite.html', members=members, elites=elites)


# ══════════════════════════════════════════════════
# CHIPS BETTING (Meeting #2 — Poker Night)
# ══════════════════════════════════════════════════

@bp.route('/tournament/<int:tournament_id>/bet', methods=['POST'])
@login_required
def place_bet(tournament_id):
    """Bet chips on a match outcome."""
    from app.models import Tournament, TournamentMatch
    match_id = request.form.get('match_id', type=int)
    bet_team = request.form.get('team')  # 'team1' or 'team2'
    bet_amount = request.form.get('amount', 0, type=int)

    if bet_amount <= 0 or bet_amount > current_user.chips_balance:
        flash('Chips tidak cukup atau jumlah tidak valid.', 'error')
        return redirect(url_for('tournament.detail', tournament_id=tournament_id))

    match = TournamentMatch.query.get_or_404(match_id)
    if match.status != 'pending':
        flash('Match sudah selesai, tidak bisa bet.', 'error')
        return redirect(url_for('tournament.detail', tournament_id=tournament_id))

    # Deduct chips
    current_user.chips_balance -= bet_amount
    db.session.add(ChipsTransaction(
        user_id=current_user.id, amount=-bet_amount,
        balance_after=current_user.chips_balance,
        type='bet', description=f'Bet {bet_amount} chips on match #{match_id} ({bet_team})',
        tournament_id=tournament_id,
        season=f'{datetime.utcnow().year}'
    ))
    # Store bet (use notification as a simple store for now)
    db.session.add(Notification(
        user_id=current_user.id,
        title=f'🎲 Bet {bet_amount:,} chips',
        body=f'Match #{match_id} — {bet_team}. Menang = 2x chips!',
        icon='casino',
        link=f'/tournament/{tournament_id}'
    ))
    db.session.commit()
    flash(f'Bet {bet_amount:,} chips! Kalau menang = {bet_amount*2:,} chips.', 'success')
    return redirect(url_for('tournament.detail', tournament_id=tournament_id))


# ══════════════════════════════════════════════════
# VOTE / PREDICTION (Meeting #3)
# ══════════════════════════════════════════════════

@bp.route('/tournament/<int:tournament_id>/vote', methods=['POST'])
@login_required
def vote_match(tournament_id):
    """Vote on who will win a match."""
    match_id = request.form.get('match_id', type=int)
    vote_team = request.form.get('team')  # 'team1' or 'team2'
    flash(f'Vote recorded! Kamu pilih {vote_team}.', 'success')
    return redirect(url_for('tournament.live_results', tournament_id=tournament_id))
